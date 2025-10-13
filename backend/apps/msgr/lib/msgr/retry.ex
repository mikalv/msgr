defmodule Messngr.Retry do
  @moduledoc """
  Utility for executing anonymous functions with retry and exponential
  backoff when transient database connectivity issues occur.
  """

  require Logger

  @default_attempts 3
  @default_backoff 25
  @default_max_backoff 400
  @default_transient [DBConnection.ConnectionError, DBConnection.OwnershipError]

  @type option ::
          {:attempts, pos_integer()}
          | {:backoff, non_neg_integer()}
          | {:max_backoff, pos_integer()}
          | {:transient, [module()]}

  @doc """
  Executes `fun` and retries when a transient database error is raised.

  The returned value of `fun` is bubbled back to the caller. Non-retryable
  exceptions are reraised immediately.
  """
  @spec run((-> result), [option()]) :: result when result: term()
  def run(fun, opts \\ []) when is_function(fun, 0) do
    attempts = Keyword.get(opts, :attempts, @default_attempts)
    backoff = Keyword.get(opts, :backoff, @default_backoff)
    max_backoff = Keyword.get(opts, :max_backoff, @default_max_backoff)
    transient = Keyword.get(opts, :transient, @default_transient)

    try_run(fun, attempts, backoff, max_backoff, transient)
  end

  defp try_run(fun, attempts_left, backoff, max_backoff, transient) when attempts_left > 0 do
    fun.()
  rescue
    exception ->
      if retryable?(exception, transient) and attempts_left > 1 do
        Logger.debug("retrying transient database operation",
          exception: exception.__struct__,
          attempts_left: attempts_left - 1
        )

        Process.sleep(backoff)
        next_backoff = min(backoff * 2, max_backoff)
        try_run(fun, attempts_left - 1, next_backoff, max_backoff, transient)
      else
        reraise(exception, __STACKTRACE__)
      end
  end

  defp retryable?(%Postgrex.Error{postgres: %{code: code}} = error, transient) do
    case code do
      :deadlock_detected -> true
      :lock_not_available -> true
      :serialization_failure -> true
      :statement_timeout -> true
      :idle_in_transaction_session_timeout -> true
      _ -> retryable_struct?(error, transient)
    end
  end

  defp retryable?(%Postgrex.Error{} = error, transient), do: retryable_struct?(error, transient)
  defp retryable?(exception, transient), do: retryable_struct?(exception, transient)

  defp retryable_struct?(exception, modules) do
    Enum.any?(modules, &match?(%{__struct__: ^&1}, exception))
  end
end
