defmodule Messngr.Auth.Notifier do
  @moduledoc """
  Delivers authentication challenges over the supported channels. Email delivery
  uses Swoosh while phone challenges go through a pluggable adapter so production
  can swap in an SMS provider without touching the calling code.
  """

  import Swoosh.Email
  require Logger

  alias Messngr.Auth.Challenge
  alias Messngr.Mailer

  @type sms_target :: String.t()
  @type otp_code :: String.t()

  @doc """
  Deliver the OTP `code` for the given `challenge`.

  Returns `:ok` on success or `{:error, reason}` when the delivery channel fails.
  """
  @spec deliver_challenge(Challenge.t(), otp_code()) :: :ok | {:error, term()}
  def deliver_challenge(%Challenge{channel: :email} = challenge, code) do
    case deliver_email(challenge, code) do
      {:ok, _response} -> :ok
      {:error, reason} ->
        Logger.warning("failed to deliver auth email", channel: :email, reason: inspect(reason))
        {:error, {:email_delivery_failed, reason}}
    end
  end

  def deliver_challenge(%Challenge{channel: :phone, target: target}, code) do
    adapter().deliver(target, code, %{})
  end

  defp deliver_email(%Challenge{target: target}, code) do
    {name, address} = email_sender()

    new()
    |> to(target)
    |> from({name, address})
    |> subject("Your Messngr login code")
    |> text_body("Your login code is #{code}. It expires in 10 minutes.")
    |> html_body("<p>Your login code is <strong>#{code}</strong>. It expires in 10 minutes.</p>")
    |> Mailer.deliver()
  end

  defp email_sender do
    Application.get_env(:msgr, __MODULE__, [])
    |> Keyword.get(:email_sender, {"Messngr", "login@messngr.local"})
  end

  defp adapter do
    Application.get_env(:msgr, __MODULE__, [])
    |> Keyword.get(:sms_adapter, Messngr.Auth.Notifier.LogSmsAdapter)
  end

  defmodule SmsAdapter do
    @moduledoc """
    Behaviour describing an SMS adapter capable of delivering OTP codes.
    """

    @callback deliver(Messngr.Auth.Notifier.sms_target(), Messngr.Auth.Notifier.otp_code(), map()) ::
                :ok | {:error, term()}
  end

  defmodule LogSmsAdapter do
    @moduledoc """
    Development adapter that simply logs the SMS payload instead of calling an
    external provider.
    """

    @behaviour Messngr.Auth.Notifier.SmsAdapter
    require Logger

    @impl true
    def deliver(target, code, _metadata) do
      Logger.info("Delivering OTP challenge", channel: :sms, target: target, code: code)
      :ok
    end
  end
end
