defmodule Teams.Search do
  @moduledoc """
  Search integration with Prism hybrid search engine.
  Indexes messages on send, queries on search.
  """

  require Logger

  @collection "messages"

  def prism_url do
    Application.get_env(:teams, :prism_url, "http://localhost:3080")
  end

  @doc """
  Index a message in Prism. Called after message creation.
  Best-effort — search indexing failure should never block message delivery.
  """
  def index_message(team_slug, message) do
    Task.start(fn ->
      doc = %{
        id: message.id,
        fields: %{
          message_id: message.id,
          channel_id: message.channel_id,
          team_slug: team_slug,
          sender_profile_id: message.sender_profile_id,
          sender_name: get_in(message, [:sender_profile, :display_name]) || "",
          content: extract_text(message.content),
          inserted_at: to_string(message.inserted_at)
        }
      }

      url = "#{prism_url()}/collections/#{@collection}/documents"

      case :hackney.request(:post, url, [{"Content-Type", "application/json"}], Jason.encode!(%{documents: [doc]}), [:with_body]) do
        {:ok, status, _, _} when status in 200..299 ->
          Logger.debug("Indexed message #{message.id} in Prism")

        {:ok, status, _, body} ->
          Logger.warning("Prism index failed (#{status}): #{body}")

        {:error, reason} ->
          Logger.warning("Prism index error: #{inspect(reason)}")
      end
    end)
  end

  @doc """
  Search messages via Prism. Returns list of message IDs with highlights.
  """
  def search(team_slug, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    channel_id = Keyword.get(opts, :channel_id)

    search_body = %{
      query: query,
      limit: limit,
      highlight: %{
        fields: ["content"],
        pre_tag: "<mark>",
        post_tag: "</mark>",
        fragment_size: 200
      }
    }

    # Add filter for team and optionally channel
    search_body =
      search_body
      |> Map.put(:filter, build_filter(team_slug, channel_id))

    url = "#{prism_url()}/collections/#{@collection}/search"

    case :hackney.request(:post, url, [{"Content-Type", "application/json"}], Jason.encode!(search_body), [:with_body]) do
      {:ok, status, _, body} when status in 200..299 ->
        case Jason.decode(body) do
          {:ok, %{"results" => results}} ->
            hits =
              Enum.map(results, fn hit ->
                fields = hit["fields"] || hit["_source"] || %{}
                %{
                  message_id: fields["message_id"],
                  channel_id: fields["channel_id"],
                  sender_name: fields["sender_name"],
                  content: fields["content"],
                  inserted_at: fields["inserted_at"],
                  highlight: get_in(hit, ["highlight", "content"]) || [],
                  score: hit["score"] || hit["_score"]
                }
              end)

            {:ok, hits}

          {:ok, _other} ->
            {:ok, []}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, status, _, body} ->
        {:error, {:prism_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  PostgreSQL ILIKE fallback search. Used temporarily while Prism text-field bug is unresolved.
  """
  def search_pg(prefix, query, opts \\ []) do
    import Ecto.Query
    limit = Keyword.get(opts, :limit, 20)
    channel_id = Keyword.get(opts, :channel_id)
    pattern = "%#{String.replace(query, "%", "\\%")}%"

    base = from(m in Teams.TenantModels.Message,
      where: is_nil(m.deleted_at) and is_nil(m.thread_parent_id),
      where: fragment("(?->>'text') ILIKE ?", m.content, ^pattern),
      preload: [:sender_profile],
      order_by: [desc: m.inserted_at],
      limit: ^limit
    )

    base = if channel_id, do: from(m in base, where: m.channel_id == ^channel_id), else: base

    messages = Teams.Repo.all(base, prefix: prefix)

    results = Enum.map(messages, fn m ->
      %{
        message_id: m.id,
        channel_id: m.channel_id,
        sender_name: if(m.sender_profile, do: m.sender_profile.display_name, else: ""),
        content: extract_text(m.content),
        inserted_at: to_string(m.inserted_at),
        score: 1.0
      }
    end)

    {:ok, results}
  rescue
    e ->
      Logger.warning("PostgreSQL search fallback failed: #{inspect(e)}")
      {:error, e}
  end

  defp build_filter(team_slug, nil) do
    %{team_slug: team_slug}
  end

  defp build_filter(team_slug, channel_id) do
    %{team_slug: team_slug, channel_id: channel_id}
  end

  defp extract_text(%{"text" => text}) when is_binary(text), do: text
  defp extract_text(content) when is_binary(content), do: content
  defp extract_text(content) when is_map(content), do: Map.get(content, "text", "")
  defp extract_text(_), do: ""

  defp get_in(map, keys) when is_map(map) do
    Enum.reduce_while(keys, map, fn
      key, acc when is_map(acc) -> {:cont, Map.get(acc, key)}
      key, acc when is_struct(acc) -> {:cont, Map.get(acc, key)}
      _, _ -> {:halt, nil}
    end)
  end
  defp get_in(_, _), do: nil
end
