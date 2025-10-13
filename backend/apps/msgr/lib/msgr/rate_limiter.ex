defmodule Messngr.RateLimiter do
  @moduledoc """
  Thin wrapper around the Hammer rate-limiter that provides repository-wide
  defaults and a consistent error contract for callers.
  """

  @type bucket :: String.t()
  @type limit_name :: atom()

  @doc """
  Checks the configured rate limit for the given `name` and `bucket`.

  Returns `:ok` when the request is allowed or `{:error, :rate_limited}` when the
  configured threshold has been reached. When Hammer reports an internal error we
  return the error tuple so callers can decide how to react.
  """
  @spec check(limit_name(), bucket(), keyword()) :: :ok | {:error, term()}
  def check(name, bucket, opts \\ []) when is_atom(name) and is_binary(bucket) do
    config = Application.get_env(:msgr, :rate_limits, [])
    name_config = Keyword.get(config, name, [])

    limit =
      opts
      |> Keyword.get(:limit, Keyword.get(name_config, :limit, 5))

    period =
      opts
      |> Keyword.get(:period, Keyword.get(name_config, :period, :timer.minutes(10)))

    case Hammer.check_rate(storage_key(name, bucket), period, limit) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  @spec storage_key(limit_name(), bucket()) :: String.t()
  def storage_key(name, bucket), do: "msgr:#{name}:#{bucket}"
end
