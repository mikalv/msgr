defmodule AuthProvider.UserHelper do
  alias AuthProvider.Account.{AuthMethod, User, UserDevice}
  alias AuthProvider.Repo
  alias AuthProvider.DeviceHelper
  require Logger

  def find_or_register_user_by_email(email, device_id) do
    case Repo.get_by(User, email: email) do
      nil -> register_user(email, :email, device_id)
      user -> {:ok, user}
    end
  end

  def find_or_register_user_by_msisdn(msisdn, device_id) do
    case Repo.get_by(User, msisdn: msisdn) do
      nil -> register_user(msisdn, :msisdn, device_id)
      user -> {:ok, user}
    end
  end


  def find_or_register_user_by_email(email) do
    case Repo.get_by(User, email: email) do
      nil -> register_user_without_device(%{email: email})
      user -> {:ok, user}
    end
  end

  def find_or_register_user_by_msisdn(msisdn) do
    case Repo.get_by(User, msisdn: msisdn) do
      nil -> register_user_without_device(%{msisdn: msisdn})
      user -> {:ok, user}
    end
  end

  defp register_user_without_device(attrs) do
    {:ok, usr} =
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert

    Logger.info "User created: #{inspect usr}"
    {:ok, usr}
  end

  def find_user_by_msisdn(msisdn), do: Repo.get_by(User, msisdn: msisdn)

  def register_user(email, :email, device_id) do
    attrs = %{
      id: UUID.uuid4(),
      email: email,
    }
    register_user(attrs, device_id)
  end

  def register_user(msisdn, :msisdn, device_id) do
    attrs = %{
      id: UUID.uuid4(),
      msisdn: msisdn,
    }
    register_user(attrs, device_id)
  end

  defp register_user(attrs, device_id) do
    {:ok, usr} =
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert

    Logger.info "usr: #{inspect usr}"

    device = DeviceHelper.find_by_device_id(device_id)
    Logger.info "UserId is #{inspect usr.id} and DeviceId is #{inspect device_id}"

    {:ok, ud} = %UserDevice{}
    |> UserDevice.changeset(%{ user_id: usr.id, device_id: device.id })
    |> Repo.insert

    Logger.info "Created a user #{inspect usr} and connected it with device #{inspect ud}"
    {:ok, usr}
  end

  @spec create_login_code_for_user(%User{}) :: :ok
  def create_login_code_for_user(user) do
    q = AuthProvider.Account.AuthMethod.get_current_auth_code_if_any_q(user.id)
    struct = case Repo.one(q) do
      nil ->
        %AuthMethod{}

      val ->
        val
    end

    {:ok, code} = struct
    |> AuthMethod.changeset(%{
      auth_type: "one_time_code",
      user_id: user.id,
      value: generate_one_time_code()
    })
    |> Repo.insert_or_update
    Logger.info "Created one time code for #{user.msisdn} - #{inspect code}"
    if (not is_nil(user.msisdn)) and String.match?(user.msisdn, ~r/^\+/) do
      resp = send_msisdn_auth_code(user.msisdn, "Your login code is #{code.value}")
      Logger.info "Sent SMS, response: #{inspect resp}"
    end
    :ok
  end

  @spec validate_login_code_for_user(integer(), %User{}) :: {:ok, :valid_code} | {:error, :invalid_code}
  def validate_login_code_for_user(code, %User{} = user) do
    auth_code = Repo.get_by(AuthMethod, [user_id: user.id, auth_type: "one_time_code", is_disabled: false])
    if is_nil(auth_code) do
      {:error, :invalid_code}
    else
      if String.to_integer(auth_code.value) == String.to_integer(code) do
        auth_code
          |> Ecto.Changeset.change(is_disabled: true)
          |> Repo.update

        {:ok, :valid_code}
      else
        {:error, :invalid_code}
      end
    end
  end

  def send_msisdn_auth_code("+" <> msisdn, message) do
    if (System.get_env("BULK_SMS_ENABLE", "false") == "true") do
      username = System.get_env("BULK_SMS_USERNAME")
      password = System.get_env("BULK_SMS_PASSWORD")
      unless is_nil(password) and is_nil(username) do
        query = "username=#{username}&password=#{password}&msisdn=#{msisdn}&sender=Msgr&message=#{message}"
        url = "https://bulksms.vsms.net/eapi/submission/send_sms/2/2.0?#{query}"
        HTTPoison.get(URI.encode(url))
      else
        Logger.error "BULK_SMS_USERNAME and BULK_SMS_PASSWORD not set - Won't send sms!"
      end
    end
  end

  def send_email_auth_code(email, message) do
    Logger.info "Sending email to #{email} with message: #{message}"
  end

  @spec generate_one_time_code() :: binary()
  def generate_one_time_code(), do: :io_lib.format("~6..0B", [:rand.uniform(10_000_00) - 1]) |> List.to_string
end
