defmodule SecurityTokenManager do
  use GenServer

  @derive {Inspect, only: [:expires_at]}
  defstruct [:access_key, :secret_access, :security_token, :expires_at]

  @security_token_size 20
  @milliseconds_in_second 1000
  @expires_in_seconds 60 * 15 # 15 minutes

  def format_status(_reason, [pdict, state]) do
    {:ok,
      [
        pdict,
        %{
          state
          | access_key: "<sensitive_data>",
            secret_access: "<sensitive_data>",
            security_token: "<sensitive_data>"
        }
      ]}
  end

  def start_link do
    GenServer.start_link(
      __MODULE__,
      %{
        access_key: System.get_env("ACCESS_KEY"),
        secret_access: System.get_env("SECRET_ACCESS")
      },
      name: __MODULE__
    )
  end

  def get_security_token do
    GenServer.call(__MODULE__, :get_security_token)
  end

  def handle_call(:get_security_token, _from, state) do
    {:reply, state.security_token, state}
  end

  def handle_info(:refresh_token, state) do
    {security_token, expires_at} =
      generate_security_token(state.access_key, state.secret_access)

    schedule_refresh_token(expires_at)

    new_state = %{state | security_token: security_token, expires_at: expires_at}
    {:noreply, new_state}
  end

  def init(args) do
    schedule_refresh_token(DateTime.utc_now())

    {:ok, %__MODULE__{access_key: args[:access_key], secret_access: args[:secret_access]}}
  end

  # This function simulates an authentication process where `access_key` and `secret_access` are provided
  # to a downstream service, which in turn returns a `security_token` along with its `expires_at timestamp.
  defp generate_security_token(_access_key, _secret_access) do
    {security_token(), expires_at()}
  end

  defp schedule_refresh_token(expires_at) do
    current_time = DateTime.utc_now()
    time_difference = DateTime.diff(expires_at, current_time)

    # Send a `:refresh_token message after the time difference in seconds
    Process.send_after(self(), :refresh_token, time_difference * @milliseconds_in_second)
  end

  # generates a random token for demonstration purposes.
  defp security_token do
    :crypto.strong_rand_bytes(@security_token_size) |> Base.encode64()
  end

  defp expires_at do
    DateTime.utc_now() |> DateTime.add(@expires_in_seconds)
  end
end


defimpl Inspect, for: SecurityTokenManager do
  def inspect(%SecurityTokenManager{} = state, opts) do
    Inspect.Map.inspect(
      %{
        access_key: "<redacted>",
        secret_access: "<redacted>",
        security_token: "<redacted>",
        expires_at: state.expires_at
      },
      opts
    )
  end
end
