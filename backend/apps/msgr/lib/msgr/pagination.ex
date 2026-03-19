defmodule Messngr.Pagination do
  @moduledoc """
  Cursor-based pagination helper for chat messages.

  Supports `before`, `after`, and `around` cursors with configurable limit.
  All cursor values are UUIDs (message IDs).
  """

  import Ecto.Query

  @default_limit 50
  @max_limit 100

  @type cursor_opts :: %{
          optional(:before) => String.t(),
          optional(:after) => String.t(),
          optional(:around) => String.t(),
          optional(:limit) => non_neg_integer()
        }

  @doc """
  Applies cursor-based pagination to a queryable.

  Returns `{query, meta}` where meta contains `:direction` for the caller
  to know whether results need reversing.

  ## Options

    * `:before` - fetch messages with id < this cursor, newest first
    * `:after` - fetch messages with id > this cursor, oldest first
    * `:around` - fetch limit/2 before and limit/2 after this cursor
    * `:limit` - max results (default #{@default_limit}, max #{@max_limit})
  """
  def paginate(queryable, opts \\ %{}) do
    limit = parse_limit(opts)

    cond do
      opts[:around] ->
        around(queryable, opts[:around], limit)

      opts[:before] ->
        before(queryable, opts[:before], limit)

      opts[:after] ->
        after_cursor(queryable, opts[:after], limit)

      true ->
        # Default: newest messages first
        query =
          queryable
          |> order_by([m], desc: m.inserted_at, desc: m.id)
          |> limit(^limit)

        {query, %{direction: :desc}}
    end
  end

  defp before(queryable, cursor_id, limit) do
    query =
      queryable
      |> where([m], m.id < ^cursor_id)
      |> order_by([m], desc: m.inserted_at, desc: m.id)
      |> limit(^limit)

    {query, %{direction: :desc}}
  end

  defp after_cursor(queryable, cursor_id, limit) do
    query =
      queryable
      |> where([m], m.id > ^cursor_id)
      |> order_by([m], asc: m.inserted_at, asc: m.id)
      |> limit(^limit)

    {query, %{direction: :asc}}
  end

  defp around(queryable, cursor_id, limit) do
    half = div(limit, 2)

    before_query =
      queryable
      |> where([m], m.id < ^cursor_id)
      |> order_by([m], desc: m.inserted_at, desc: m.id)
      |> limit(^half)

    after_query =
      queryable
      |> where([m], m.id >= ^cursor_id)
      |> order_by([m], asc: m.inserted_at, asc: m.id)
      |> limit(^(half + 1))

    {union_all(after_query, ^before_query), %{direction: :around}}
  end

  @doc """
  Parses pagination params from a controller params map (string keys).
  """
  def parse_params(params) do
    %{}
    |> maybe_put(:before, params["before"])
    |> maybe_put(:after, params["after"])
    |> maybe_put(:around, params["around"])
    |> maybe_put(:limit, parse_limit_param(params["limit"]))
  end

  defp parse_limit(opts) do
    case opts[:limit] do
      nil -> @default_limit
      n when is_integer(n) and n > 0 and n <= @max_limit -> n
      n when is_integer(n) and n > @max_limit -> @max_limit
      _ -> @default_limit
    end
  end

  defp parse_limit_param(nil), do: nil

  defp parse_limit_param(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> min(n, @max_limit)
      _ -> nil
    end
  end

  defp parse_limit_param(val) when is_integer(val) and val > 0, do: min(val, @max_limit)
  defp parse_limit_param(_), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
