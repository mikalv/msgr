defmodule Messngr.Messages do
  @moduledoc """
  Context module for tenant-scoped message operations.

  Uses cursor-based pagination via `Messngr.Pagination`.
  """

  alias Teams.TenantModels.Message
  alias Messngr.Pagination

  import Ecto.Query

  @doc """
  Lists messages in a channel with cursor-based pagination.

  ## Options (cursor_opts map)
    * `:before` — message id; fetch older messages
    * `:after` — message id; fetch newer messages
    * `:around` — message id; fetch messages around this one
    * `:limit` — max results (default 50, max 100)

  Returns `{messages, meta}` where meta has `:direction` and `:has_more`.
  """
  def list_messages(prefix, channel_id, cursor_opts \\ %{}) do
    base =
      from(m in Message,
        where: m.channel_id == ^channel_id and is_nil(m.thread_parent_id),
        preload: [:sender_profile, :reactions]
      )

    {query, meta} = Pagination.paginate(base, cursor_opts)
    messages = Teams.Repo.all(query, prefix: prefix)

    # For desc direction, results come newest-first from DB; reverse to chronological
    messages =
      case meta.direction do
        :desc -> Enum.reverse(messages)
        :asc -> messages
        :around -> Enum.sort_by(messages, & &1.inserted_at, DateTime)
      end

    has_more = length(messages) >= Map.get(cursor_opts, :limit, 50)

    {messages, %{has_more: has_more}}
  end

  @doc """
  Creates a message in a channel.

  ## Attrs
    * `:channel_id` — required
    * `:sender_profile_id` — required
    * `:content` — required (JSONB map)
    * `:thread_parent_id` — optional (for thread replies)
    * `:media_refs` — optional list of media object keys
  """
  def create_message(prefix, attrs) do
    Message.create(prefix, attrs)
  end

  @doc """
  Gets a single message by id. Returns nil if not found.
  """
  def get_message(prefix, id) do
    from(m in Message, where: m.id == ^id, preload: [:sender_profile, :reactions])
    |> Teams.Repo.one(prefix: prefix)
  end

  @doc """
  Gets a thread: the parent message plus its replies with cursor pagination.
  """
  def get_thread(prefix, parent_message_id, cursor_opts \\ %{}) do
    parent =
      from(m in Message,
        where: m.id == ^parent_message_id,
        preload: [:sender_profile, :reactions]
      )
      |> Teams.Repo.one(prefix: prefix)

    case parent do
      nil ->
        {:error, :not_found}

      parent ->
        base =
          from(m in Message,
            where: m.thread_parent_id == ^parent_message_id,
            preload: [:sender_profile, :reactions]
          )

        {query, meta} = Pagination.paginate(base, cursor_opts)
        replies = Teams.Repo.all(query, prefix: prefix)

        replies =
          case meta.direction do
            :desc -> Enum.reverse(replies)
            :asc -> replies
            :around -> Enum.sort_by(replies, & &1.inserted_at, DateTime)
          end

        {:ok, %{parent: parent, replies: replies}}
    end
  end
end
