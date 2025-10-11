defmodule Messngr.FeatureFlags do
  @moduledoc """
  Runtime-configurable feature flags used to gradually roll out backend
  capabilities without redeploying. Flags are stored in `:persistent_term`
  so they can be toggled via remote Mix tasks or runtime RPC calls.
  """

  use GenServer

  @typedoc "Supported feature flag identifiers"
  @type flag :: :noise_handshake_required

  @flags [:noise_handshake_required]

  @doc """
  Starts the feature flag server and loads defaults from application config.
  """
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    defaults = Application.get_env(:msgr, :feature_flags, [])

    Enum.each(@flags, fn flag ->
      value = Keyword.get(defaults, flag, false)
      put(flag, value)
    end)

    {:ok, %{}}
  end

  @doc """
  Returns the list of supported flags.
  """
  @spec flags() :: [flag()]
  def flags, do: @flags

  @doc """
  Reads the current value for the given `flag`.
  """
  @spec get(flag()) :: boolean()
  def get(flag) when flag in @flags do
    :persistent_term.get(persistent_key(flag), false)
  end

  @doc """
  Convenience wrapper for `get/1` specialised for the Noise handshake rollout.
  """
  @spec require_noise_handshake?() :: boolean()
  def require_noise_handshake?, do: get(:noise_handshake_required)

  @doc """
  Updates the value for the given `flag` at runtime.
  """
  @spec put(flag(), boolean()) :: :ok
  def put(flag, value) when flag in @flags do
    :persistent_term.put(persistent_key(flag), !!value)
    :ok
  end

  defp persistent_key(flag), do: {__MODULE__, flag}
end
