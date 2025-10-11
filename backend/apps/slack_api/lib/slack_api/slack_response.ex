defmodule SlackApi.SlackResponse do
  @moduledoc """
  Helpers for shaping responses so they look like Slack Web API payloads.
  """

  @type payload :: map()

  @doc """
  Returns a successful payload merged with additional attributes.
  """
  @spec success(payload()) :: payload()
  def success(extra \\ %{}) when is_map(extra) do
    Map.merge(%{ok: true}, extra)
  end

  @doc """
  Returns an error payload with the provided reason.
  """
  @spec error(String.t() | atom(), payload()) :: payload()
  def error(reason, extra \\ %{}) do
    reason =
      reason
      |> to_string()
      |> String.replace(~r/[^a-z0-9_\.\-]/i, "_")
      |> String.downcase()

    extra
    |> Map.merge(%{ok: false, error: reason})
  end
end
