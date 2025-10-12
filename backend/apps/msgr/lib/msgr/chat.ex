defmodule Messngr.Chat do
  @moduledoc """
  Chat contexts for å opprette samtaler, legge til deltakere og sende meldinger.
  """

  import Ecto.Query

  alias Phoenix.PubSub

  alias Messngr.{Accounts, Media, Repo}
  alias Messngr.Chat.{
    Conversation,
    Message,
    MessageReaction,
    MessageThread,
    Participant,
    PinnedMessage
  }
  alias Messngr.Accounts.Profile

  @conversation_topic_prefix "conversation"

  @spec create_direct_conversation(binary(), binary()) ::
          {:ok, Conversation.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def create_direct_conversation(profile_a_id, profile_b_id) do
    Repo.transaction(fn ->
      with {:ok, conversation} <- %Conversation{} |> Conversation.changeset(%{kind: :direct}) |> Repo.insert(),
           {:ok, _} <- add_participant(conversation, profile_a_id, :owner),
           {:ok, _} <- add_participant(conversation, profile_b_id, :member) do
        preload_conversation(conversation.id)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @spec create_group_conversation(binary(), [binary()], map()) ::
          {:ok, Conversation.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def create_group_conversation(owner_profile_id, participant_ids, attrs \\ %{}) do
    participant_ids = List.wrap(participant_ids)
    attrs = Map.put(attrs, :visibility, :private)
    create_structured_conversation(:group, owner_profile_id, participant_ids, attrs)
  end

  @spec create_channel_conversation(binary(), map()) ::
          {:ok, Conversation.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def create_channel_conversation(owner_profile_id, attrs \\ %{}) do
    participant_ids =
      attrs
      |> Map.get("participant_ids")
      |> Kernel.||(Map.get(attrs, :participant_ids))
      |> List.wrap()

    create_structured_conversation(:channel, owner_profile_id, participant_ids, attrs)
  end

  @spec add_participant(Conversation.t(), binary(), :member | :owner) ::
          {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  def add_participant(%Conversation{id: conversation_id}, profile_id, role \\ :member) do
    %Participant{}
    |> Participant.changeset(%{conversation_id: conversation_id, profile_id: profile_id, role: role})
    |> Repo.insert()
  end

  @spec send_message(binary(), binary(), map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  @message_kinds [:text, :markdown, :code, :system, :image, :video, :audio, :voice, :file, :thumbnail, :location]

  def send_message(conversation_id, profile_id, attrs) do
    Repo.transaction(fn ->
      _participant = ensure_participant!(conversation_id, profile_id)

      kind = resolve_kind(attrs)
      {media_payload, sanitized_attrs} =
        maybe_resolve_media(kind, conversation_id, profile_id, attrs)

      base_payload = Map.get(sanitized_attrs, "payload") || %{}
      merged_payload = merge_payload(base_payload, media_payload)

      message_attrs =
        sanitized_attrs
        |> Map.put("payload", merged_payload)
        |> Map.put("kind", kind)
        |> Map.put_new("conversation_id", conversation_id)
        |> Map.put_new("profile_id", profile_id)
        |> Map.put_new_lazy("sent_at", fn -> DateTime.utc_now() end)

      case %Message{} |> Message.changeset(message_attrs) |> Repo.insert() do
        {:ok, message} -> Repo.preload(message, :profile)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
        {:ok, message} ->
          broadcast_message(message)
          {:ok, message}
        {:error, reason} -> {:error, reason}
    end
  end

  @spec react_to_message(binary(), binary(), binary(), String.t(), map()) ::
          {:ok, MessageReaction.t()} | {:error, term()}
  def react_to_message(conversation_id, profile_id, message_id, emoji, opts \\ %{}) do
    Repo.transaction(fn ->
      _participant = ensure_participant!(conversation_id, profile_id)
      message = fetch_message!(conversation_id, message_id)

      attrs = %{
        message_id: message.id,
        profile_id: profile_id,
        emoji: normalize_emoji(emoji),
        metadata: normalize_metadata(opts[:metadata] || Map.get(opts, "metadata"))
      }

      %MessageReaction{}
      |> MessageReaction.changeset(attrs)
      |> Repo.insert(
        conflict_target: [:message_id, :profile_id, :emoji],
        on_conflict: {:replace, [:metadata, :updated_at]}
      )
      |> case do
        {:ok, reaction} -> Repo.preload(reaction, :profile)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, reaction} ->
        broadcast_reaction_added(conversation_id, reaction)
        {:ok, reaction}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec remove_reaction(binary(), binary(), binary(), String.t()) ::
          {:ok, :removed | :noop} | {:error, term()}
  def remove_reaction(conversation_id, profile_id, message_id, emoji) do
    Repo.transaction(fn ->
      _participant = ensure_participant!(conversation_id, profile_id)
      message = fetch_message!(conversation_id, message_id)
      normalized = normalize_emoji(emoji)

      case Repo.get_by(MessageReaction,
             message_id: message.id,
             profile_id: profile_id,
             emoji: normalized
           ) do
        nil ->
          :noop

        %MessageReaction{} = reaction ->
          {:ok, _} = Repo.delete(reaction)
          {:removed, reaction}
      end
    end)
    |> case do
      {:ok, {:removed, reaction}} ->
        broadcast_reaction_removed(conversation_id, reaction)
        {:ok, :removed}

      {:ok, :noop} ->
        {:ok, :noop}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec pin_message(binary(), binary(), binary(), map()) ::
          {:ok, PinnedMessage.t()} | {:error, term()}
  def pin_message(conversation_id, profile_id, message_id, opts \\ %{}) do
    Repo.transaction(fn ->
      _participant = ensure_participant!(conversation_id, profile_id)
      _message = fetch_message!(conversation_id, message_id)

      attrs = %{
        conversation_id: conversation_id,
        message_id: message_id,
        pinned_by_id: profile_id,
        pinned_at: opts[:pinned_at] || Map.get(opts, "pinned_at") || DateTime.utc_now(),
        metadata: normalize_metadata(opts[:metadata] || Map.get(opts, "metadata"))
      }

      %PinnedMessage{}
      |> PinnedMessage.changeset(attrs)
      |> Repo.insert(
        conflict_target: [:conversation_id, :message_id],
        on_conflict: {:replace, [:pinned_by_id, :pinned_at, :metadata, :updated_at]}
      )
      |> case do
        {:ok, pinned} -> Repo.preload(pinned, [:message, :pinned_by])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, pinned} ->
        broadcast_message_pinned(conversation_id, pinned)
        {:ok, pinned}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec unpin_message(binary(), binary(), binary()) :: {:ok, :unpinned | :noop} | {:error, term()}
  def unpin_message(conversation_id, profile_id, message_id) do
    Repo.transaction(fn ->
      _participant = ensure_participant!(conversation_id, profile_id)
      _message = fetch_message!(conversation_id, message_id)

      case Repo.get_by(PinnedMessage,
             conversation_id: conversation_id,
             message_id: message_id
           ) do
        nil ->
          :noop

        %PinnedMessage{} = pinned ->
          {:ok, _} = Repo.delete(pinned)
          {:unpinned, pinned}
      end
    end)
    |> case do
      {:ok, {:unpinned, pinned}} ->
        broadcast_message_unpinned(conversation_id, pinned)
        {:ok, :unpinned}

      {:ok, :noop} ->
        {:ok, :noop}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec mark_message_read(binary(), binary(), binary()) ::
          {:ok, Participant.t()} | {:error, term()}
  def mark_message_read(conversation_id, profile_id, message_id) do
    Repo.transaction(fn ->
      participant = ensure_participant!(conversation_id, profile_id)
      message = fetch_message!(conversation_id, message_id)

      read_at = DateTime.utc_now()
      attrs = %{last_read_at: read_at}

      participant
      |> Participant.changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, updated} -> {updated, message, read_at}
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, {participant, message, read_at}} ->
        broadcast_message_read(conversation_id, participant.profile_id, message.id, read_at)
        {:ok, participant}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec update_message(binary(), binary(), binary(), map()) ::
          {:ok, Message.t()} | {:error, term()}
  def update_message(conversation_id, profile_id, message_id, attrs) do
    Repo.transaction(fn ->
      participant = ensure_participant!(conversation_id, profile_id)
      message = fetch_message!(conversation_id, message_id)

      if message.profile_id != participant.profile_id do
        Repo.rollback(:forbidden)
      end

      update_attrs =
        attrs
        |> take_permitted_attrs([:body, :payload, :metadata])
        |> maybe_normalize_metadata()
        |> Map.put(:edited_at, DateTime.utc_now())

      message
      |> Message.changeset(update_attrs)
      |> Repo.update()
      |> case do
        {:ok, updated} -> Repo.preload(updated, :profile)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, message} ->
        broadcast_message_updated(message)
        {:ok, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec delete_message(binary(), binary(), binary(), map()) ::
          {:ok, Message.t()} | {:error, term()}
  def delete_message(conversation_id, profile_id, message_id, opts \\ %{}) do
    Repo.transaction(fn ->
      participant = ensure_participant!(conversation_id, profile_id)
      message = fetch_message!(conversation_id, message_id)

      if message.profile_id != participant.profile_id do
        Repo.rollback(:forbidden)
      end

      delete_attrs =
        %{deleted_at: DateTime.utc_now()}
        |> maybe_put_delete_metadata(opts)

      message
      |> Message.changeset(delete_attrs)
      |> Repo.update()
      |> case do
        {:ok, deleted} -> Repo.preload(deleted, :profile)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, message} ->
        broadcast_message_deleted(message)
        {:ok, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @default_limit 50
  @watcher_table :messngr_conversation_watchers

  @spec list_messages(binary(), keyword()) :: %{entries: [Message.t()], meta: map()}
  def list_messages(conversation_id, opts \\ []) do
    limit =
      opts
      |> Keyword.get(:limit, @default_limit)
      |> clamp_limit()

    cond do
      opts[:around_id] -> list_messages_around(conversation_id, opts[:around_id], limit)
      opts[:after_id] -> list_messages_after(conversation_id, opts[:after_id], limit)
      true -> list_messages_before(conversation_id, opts[:before_id], limit)
    end
  end

  defp preload_conversation(id) do
    Conversation
    |> Repo.get!(id)
    |> Repo.preload(participants: [:profile])
  end

  defp ensure_participant!(conversation_id, profile_id) do
    Repo.get_by!(Participant, conversation_id: conversation_id, profile_id: profile_id)
  end

  defp clamp_limit(value) when is_integer(value) and value > 0 do
    min(value, 200)
  end

  defp clamp_limit(_value), do: @default_limit

  defp list_messages_before(conversation_id, before_id, limit)
       when is_integer(limit) and limit <= 0 do
    empty_page()
  end

  defp list_messages_before(conversation_id, before_id, limit) do
    base_query =
      from m in Message,
        where: m.conversation_id == ^conversation_id,
        order_by: [desc: m.inserted_at, desc: m.id]

    {query, pivot} = maybe_before_cursor(conversation_id, base_query, before_id)

    results =
      query
      |> limit(^(limit + 1))
      |> Repo.all()

    has_more_before = length(results) > limit

    entries =
      results
      |> Enum.take(limit)
      |> Enum.reverse()
      |> Repo.preload(:profile)

    %{entries: entries, meta: build_meta(conversation_id, entries, pivot, :before, has_more_before)}
  end

  defp list_messages_after(conversation_id, after_id, limit)
       when is_integer(limit) and limit <= 0 do
    empty_page()
  end

  defp list_messages_after(conversation_id, after_id, limit) do
    base_query =
      from m in Message,
        where: m.conversation_id == ^conversation_id,
        order_by: [asc: m.inserted_at, asc: m.id]

    {query, pivot} = maybe_after_cursor(conversation_id, base_query, after_id)

    results =
      query
      |> limit(^(limit + 1))
      |> Repo.all()

    has_more_after = length(results) > limit

    entries =
      results
      |> Enum.take(limit)
      |> Repo.preload(:profile)

    %{entries: entries, meta: build_meta(conversation_id, entries, pivot, :after, has_more_after)}
  end

  defp list_messages_around(conversation_id, message_id, limit) do
    with %Message{conversation_id: ^conversation_id} = pivot <- Repo.get(Message, message_id) do
      pivot = Repo.preload(pivot, :profile)

      before_limit = div(limit, 2)
      after_limit = max(limit - before_limit - 1, 0)

      before_page =
        if before_limit > 0 do
          list_messages_before(conversation_id, message_id, before_limit)
        else
          empty_page()
        end

      after_page =
        if after_limit > 0 do
          list_messages_after(conversation_id, message_id, after_limit)
        else
          empty_page()
        end

      entries = before_page.entries ++ [pivot] ++ after_page.entries

      meta = %{
        start_cursor: cursor_id(List.first(entries)),
        end_cursor: cursor_id(List.last(entries)),
        has_more: %{
          before:
            before_page.meta.has_more.before || has_more(conversation_id, List.first(entries), :before),
          after:
            after_page.meta.has_more.after || has_more(conversation_id, List.last(entries), :after)
        }
      }

      %{entries: entries, meta: meta}
    else
      _ -> list_messages_before(conversation_id, nil, limit)
    end
  end

  def after_id(messages) when is_list(messages) do
    messages
    |> List.last()
    |> cursor_id()
  end

  def around_id(conversation_id, message_id, opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_limit) |> clamp_limit()
    list_messages_around(conversation_id, message_id, limit)
  end

  def has_more(_conversation_id, nil, _direction), do: false

  def has_more(conversation_id, %Message{} = pivot, :before) do
    from(m in Message,
      where: m.conversation_id == ^conversation_id,
      where:
        m.inserted_at < ^pivot.inserted_at or
          (m.inserted_at == ^pivot.inserted_at and m.id < ^pivot.id),
      select: 1,
      limit: 1
    )
    |> Repo.exists?()
  end

  def has_more(conversation_id, %Message{} = pivot, :after) do
    from(m in Message,
      where: m.conversation_id == ^conversation_id,
      where:
        m.inserted_at > ^pivot.inserted_at or
          (m.inserted_at == ^pivot.inserted_at and m.id > ^pivot.id),
      select: 1,
      limit: 1
    )
    |> Repo.exists?()
  end

  defp build_meta(conversation_id, entries, pivot, :before, has_more_before) do
    first = List.first(entries) || pivot
    last = List.last(entries) || pivot

    %{
      start_cursor: cursor_id(List.first(entries)),
      end_cursor: cursor_id(List.last(entries)),
      has_more: %{
        before: has_more_before,
        after: has_more(conversation_id, last, :after)
      }
    }
  end

  defp build_meta(conversation_id, entries, pivot, :after, has_more_after) do
    first = List.first(entries) || pivot
    last = List.last(entries) || pivot

    %{
      start_cursor: cursor_id(List.first(entries)),
      end_cursor: cursor_id(List.last(entries)),
      has_more: %{
        before: has_more(conversation_id, first, :before),
        after: has_more_after
      }
    }
  end

  defp build_meta(_conversation_id, _entries, _pivot, _direction, _flag) do
    %{start_cursor: nil, end_cursor: nil, has_more: %{before: false, after: false}}
  end

  defp maybe_before_cursor(_conversation_id, query, nil), do: {query, nil}

  defp maybe_before_cursor(conversation_id, query, message_id) do
    case Repo.get(Message, message_id) do
      %Message{conversation_id: ^conversation_id} = message ->
        {
          from(m in query,
            where:
              m.inserted_at < ^message.inserted_at or
                (m.inserted_at == ^message.inserted_at and m.id < ^message.id)
          ),
          Repo.preload(message, :profile)
        }

      _ ->
        {query, nil}
    end
  end

  defp maybe_after_cursor(_conversation_id, query, nil), do: {query, nil}

  defp maybe_after_cursor(conversation_id, query, message_id) do
    case Repo.get(Message, message_id) do
      %Message{conversation_id: ^conversation_id} = message ->
        {
          from(m in query,
            where:
              m.inserted_at > ^message.inserted_at or
                (m.inserted_at == ^message.inserted_at and m.id > ^message.id)
          ),
          Repo.preload(message, :profile)
        }

      _ ->
        {query, nil}
    end
  end

  defp cursor_id(nil), do: nil
  defp cursor_id(%Message{id: id}), do: id

  defp empty_page do
    %{entries: [], meta: %{start_cursor: nil, end_cursor: nil, has_more: %{before: false, after: false}}}
  end

  @spec list_conversations(binary(), keyword()) :: %{entries: [Conversation.t()], meta: map()}
  def list_conversations(profile_id, opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_limit) |> clamp_limit()

    base_query =
      from c in Conversation,
        join: cp in assoc(c, :participants),
        where: cp.profile_id == ^profile_id,
        preload: [participants: [:profile]],
        order_by: [desc: c.updated_at, desc: c.inserted_at, desc: c.id],
        select: {c, cp}

    {query, pivot} = maybe_conversation_after(profile_id, base_query, opts[:after_id])

    results =
      query
      |> limit(^(limit + 1))
      |> Repo.all()

    has_more_after = length(results) > limit

    entries =
      results
      |> Enum.take(limit)
      |> Enum.map(&hydrate_conversation_summary(&1))

    pivot_conversation = pivot && elem(pivot, 0)

    first_entry = List.first(entries) || pivot_conversation
    last_entry = List.last(entries) || pivot_conversation

    meta = %{
      start_cursor: conversation_cursor(List.first(entries)),
      end_cursor: conversation_cursor(List.last(entries)),
      has_more: %{
        before: conversation_has_more(profile_id, first_entry, :before),
        after: has_more_after or conversation_has_more(profile_id, last_entry, :after)
      }
    }

    %{entries: entries, meta: meta}
  end

  def watch_conversation(conversation_id, profile_id) do
    ensure_participant!(conversation_id, profile_id)

    table = ensure_watcher_table!()
    purge_expired_watchers(conversation_id)
    :ets.match_delete(table, {conversation_id, profile_id, :_})
    :ets.insert(table, {conversation_id, profile_id, current_time_ms()})

    payload = watcher_payload(conversation_id)
    broadcast_watchers(conversation_id, payload)
    {:ok, payload}
  end

  def unwatch_conversation(conversation_id, profile_id) do
    table = ensure_watcher_table!()
    :ets.match_delete(table, {conversation_id, profile_id, :_})

    payload = watcher_payload(conversation_id)
    broadcast_watchers(conversation_id, payload)
    {:ok, payload}
  end

  def list_watchers(conversation_id) do
    watcher_payload(conversation_id)
  end

  @spec conversation_for_profiles(binary(), binary()) :: Conversation.t() | nil
  def conversation_for_profiles(profile_a_id, profile_b_id) do
    Repo.one(
      from c in Conversation,
        join: pa in assoc(c, :participants),
        join: pb in assoc(c, :participants),
        where:
          c.kind == :direct and pa.profile_id == ^profile_a_id and pb.profile_id == ^profile_b_id,
        preload: [participants: [:profile]]
    )
  end

  @spec ensure_direct_conversation(binary(), binary()) :: {:ok, Conversation.t()} | {:error, term()}
  def ensure_direct_conversation(profile_a_id, profile_b_id) do
    case conversation_for_profiles(profile_a_id, profile_b_id) do
      nil -> create_direct_conversation(profile_a_id, profile_b_id)
      conversation -> {:ok, conversation}
    end
  end

  @doc """
  Subscribe prosessen til PubSub-strømmen for en gitt samtale.
  """
  @spec subscribe_to_conversation(binary()) :: :ok | {:error, term()}
  def subscribe_to_conversation(conversation_id) do
    PubSub.subscribe(Messngr.PubSub, conversation_topic(conversation_id))
  end

  @doc false
  def broadcast_message(%Message{} = message) do
    PubSub.broadcast(
      Messngr.PubSub,
      conversation_topic(message.conversation_id),
      {:message_created, message}
    )

    :ok
  end

  @doc false
  def broadcast_message_updated(%Message{} = message) do
    PubSub.broadcast(
      Messngr.PubSub,
      conversation_topic(message.conversation_id),
      {:message_updated, message}
    )

    :ok
  end

  @doc false
  def broadcast_message_deleted(%Message{} = message) do
    PubSub.broadcast(
      Messngr.PubSub,
      conversation_topic(message.conversation_id),
      {:message_deleted, %{message_id: message.id, deleted_at: message.deleted_at}}
    )

    :ok
  end

  @doc false
  @spec broadcast_backlog(binary(), map()) :: :ok
  def broadcast_backlog(conversation_id, page) when is_map(page) do
    PubSub.broadcast(
      Messngr.PubSub,
      conversation_topic(conversation_id),
      {:message_backlog, page}
    )

    :ok
  end

  @spec ensure_profile!(binary(), binary()) :: Accounts.Profile.t()
  def ensure_profile!(account_id, profile_id) do
    profile = Accounts.get_profile!(profile_id)

    if profile.account_id != account_id do
      raise ArgumentError, "profile does not belong to account"
    end

    profile
  end

  @spec ensure_membership(binary(), binary()) :: Participant.t()
  def ensure_membership(conversation_id, profile_id) do
    ensure_participant!(conversation_id, profile_id)
  end

  defp conversation_topic(conversation_id) do
    "#{@conversation_topic_prefix}:#{conversation_id}"
  end

  defp conversation_cursor(nil), do: nil
  defp conversation_cursor(%Conversation{id: id}), do: id

  defp maybe_conversation_after(_profile_id, query, nil), do: {query, nil}

  defp maybe_conversation_after(profile_id, query, conversation_id) do
    case fetch_membership(conversation_id, profile_id) do
      {conversation, participant} ->
        cutoff = conversation.updated_at || conversation.inserted_at

        filtered =
          query
          |> where([
            c,
            _cp
          ],
            fragment("COALESCE(?, ?) < ?", c.updated_at, c.inserted_at, ^cutoff) or
              (fragment("COALESCE(?, ?) = ?", c.updated_at, c.inserted_at, ^cutoff) and
                 c.id < ^conversation.id)
          )

        {filtered, {conversation, participant}}

      _ ->
        {query, nil}
    end
  end

  defp fetch_membership(conversation_id, profile_id) do
    from(c in Conversation,
      join: cp in assoc(c, :participants),
      where: c.id == ^conversation_id and cp.profile_id == ^profile_id,
      preload: [participants: [:profile]],
      select: {c, cp}
    )
    |> Repo.one()
  end

  defp hydrate_conversation_summary({conversation, participant}) do
    last_message =
      from(m in Message,
        where: m.conversation_id == ^conversation.id,
        order_by: [desc: m.inserted_at, desc: m.id],
        limit: 1
      )
      |> Repo.one()
      |> case do
        nil -> nil
        message -> Repo.preload(message, :profile)
      end

    last_read_at = participant.last_read_at

    unread_count =
      from(m in Message,
        where: m.conversation_id == ^conversation.id,
        where:
          is_nil(^last_read_at) or m.inserted_at > ^last_read_at
      )
      |> Repo.aggregate(:count, :id)

    conversation
    |> Map.put(:unread_count, unread_count)
    |> Map.put(:last_message, last_message)
  end

  defp conversation_has_more(_profile_id, nil, _direction), do: false

  defp conversation_has_more(profile_id, %Conversation{} = pivot, :before) do
    cutoff = pivot.updated_at || pivot.inserted_at

    from(c in Conversation,
      join: cp in assoc(c, :participants),
      where: cp.profile_id == ^profile_id,
      where:
        fragment("COALESCE(?, ?) > ?", c.updated_at, c.inserted_at, ^cutoff) or
          (fragment("COALESCE(?, ?) = ?", c.updated_at, c.inserted_at, ^cutoff) and c.id > ^pivot.id),
      select: 1,
      limit: 1
    )
    |> Repo.exists?()
  end

  defp conversation_has_more(profile_id, %Conversation{} = pivot, :after) do
    cutoff = pivot.updated_at || pivot.inserted_at

    from(c in Conversation,
      join: cp in assoc(c, :participants),
      where: cp.profile_id == ^profile_id,
      where:
        fragment("COALESCE(?, ?) < ?", c.updated_at, c.inserted_at, ^cutoff) or
          (fragment("COALESCE(?, ?) = ?", c.updated_at, c.inserted_at, ^cutoff) and c.id < ^pivot.id),
      select: 1,
      limit: 1
    )
    |> Repo.exists?()
  end

  defp ensure_watcher_table! do
    case :ets.whereis(@watcher_table) do
      :undefined ->
        try do
          :ets.new(@watcher_table, [:named_table, :bag, :public, read_concurrency: true, write_concurrency: true])
        rescue
          ArgumentError -> :ets.whereis(@watcher_table)
        end

      tid ->
        tid
    end
  end

  defp watcher_payload(conversation_id) do
    purge_expired_watchers(conversation_id)
    profiles = conversation_watcher_profiles(conversation_id)

    watchers = Enum.map(profiles, &watcher_profile_payload/1)

    %{watchers: watchers, count: length(watchers)}
  end

  defp conversation_watcher_profiles(conversation_id) do
    conversation_id
    |> watcher_ids()
    |> load_profiles()
    |> Enum.sort_by(& &1.name)
  end

  defp watcher_ids(conversation_id) do
    table = ensure_watcher_table!()

    now = current_time_ms()
    ttl = watcher_ttl_ms()

    conversation_id
    |> :ets.lookup(table)
    |> Enum.reduce([], fn
      {^conversation_id, profile_id, inserted_at}, acc ->
        if expired_watcher?(inserted_at, now, ttl) do
          :ets.delete_object(table, {conversation_id, profile_id, inserted_at})
          acc
        else
          [profile_id | acc]
        end

      _other, acc ->
        acc
    end)
    |> Enum.uniq()
  end

  defp load_profiles([]), do: []

  defp load_profiles(ids) do
    from(p in Profile, where: p.id in ^ids)
    |> Repo.all()
  end

  defp watcher_profile_payload(%Profile{} = profile) do
    %{id: profile.id, name: profile.name, mode: profile.mode}
  end

  defp broadcast_watchers(conversation_id, payload) do
    PubSub.broadcast(
      Messngr.PubSub,
      conversation_topic(conversation_id),
      {:conversation_watchers, payload}
    )

    :ok
  end

  defp purge_expired_watchers(conversation_id) do
    table = ensure_watcher_table!()
    ttl = watcher_ttl_ms()
    now = current_time_ms()

    :ets.lookup(table, conversation_id)
    |> Enum.each(fn
      {^conversation_id, profile_id, inserted_at} ->
        if expired_watcher?(inserted_at, now, ttl) do
          :ets.delete_object(table, {conversation_id, profile_id, inserted_at})
        end

      _ ->
        :ok
    end)

    :ok
  end

  defp expired_watcher?(inserted_at, now, ttl) when is_integer(ttl) do
    now - inserted_at > ttl
  end

  defp watcher_ttl_ms do
    case Application.get_env(:msgr, :conversation_watcher_ttl_ms, 30_000) do
      value when is_integer(value) and value >= 0 -> value
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int, _} when int >= 0 -> int
          _ -> 30_000
        end

      _ -> 30_000
    end
  end

  defp current_time_ms do
    System.system_time(:millisecond)
  end


  defp resolve_kind(attrs) do
    attrs
    |> Map.get("kind")
    |> Kernel.||(Map.get(attrs, :kind))
    |> Kernel.||(Map.get(attrs, "type"))
    |> Kernel.||(Map.get(attrs, :type))
    |> case do
      value when is_binary(value) ->
        normalized = String.downcase(value)
        Enum.find(@message_kinds, :text, &(&1 |> Atom.to_string() == normalized))

      value when is_atom(value) and value in @message_kinds ->
        value

      _ ->
        :text
    end
  end

  defp create_structured_conversation(kind, owner_profile_id, participant_ids, attrs) do
    owner_profile_id = to_string(owner_profile_id)
    topic = attrs |> Map.get("topic") |> Kernel.||(Map.get(attrs, :topic))
    structure_type =
      attrs
      |> Map.get("structure_type")
      |> Kernel.||(Map.get(attrs, :structure_type))
      |> normalize_structure_type(default_structure_type_for(kind))

    visibility =
      attrs
      |> Map.get("visibility")
      |> Kernel.||(Map.get(attrs, :visibility))
      |> normalize_visibility(default_visibility_for(kind), kind)

    conversation_attrs =
      %{kind: kind}
      |> maybe_put_topic(topic)
      |> maybe_put_structure_type(structure_type)
      |> Map.put(:visibility, visibility)

    member_ids = normalize_participant_ids(participant_ids, owner_profile_id)

    Repo.transaction(fn ->
      with {:ok, conversation} <- %Conversation{} |> Conversation.changeset(conversation_attrs) |> Repo.insert(),
           {:ok, _owner} <- add_participant(conversation, owner_profile_id, :owner),
           {:ok, _members} <- add_members(conversation, member_ids) do
        preload_conversation(conversation.id)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp add_members(_conversation, []), do: {:ok, []}

  defp add_members(conversation, member_ids) do
    Enum.reduce_while(member_ids, {:ok, []}, fn member_id, {:ok, acc} ->
      case add_participant(conversation, member_id, :member) do
        {:ok, participant} -> {:cont, {:ok, [participant | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, participants} -> {:ok, Enum.reverse(participants)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_participant_ids(ids, owner_profile_id) do
    owner_profile_id = to_string(owner_profile_id)

    ids
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == owner_profile_id))
    |> Enum.uniq()
  end

  defp maybe_put_topic(attrs, nil), do: attrs
  defp maybe_put_topic(attrs, topic), do: Map.put(attrs, :topic, topic)

  defp maybe_put_structure_type(attrs, nil), do: attrs
  defp maybe_put_structure_type(attrs, structure_type), do: Map.put(attrs, :structure_type, structure_type)

  defp normalize_structure_type(nil, default), do: default

  defp normalize_structure_type(value, _default) when value in [:family, :business, :friends, :project, :other],
    do: value

  defp normalize_structure_type(value, default) when is_binary(value) do
    normalized = String.downcase(value)

    case normalized do
      "family" -> :family
      "familie" -> :family
      "business" -> :business
      "bedrift" -> :business
      "friends" -> :friends
      "venner" -> :friends
      "vennegjeng" -> :friends
      "project" -> :project
      "prosjekt" -> :project
      "other" -> :other
      _ -> default
    end
  end

  defp normalize_structure_type(_value, default), do: default

  defp default_structure_type_for(:group), do: :friends
  defp default_structure_type_for(:channel), do: :project
  defp default_structure_type_for(_kind), do: :other

  defp normalize_visibility(nil, default, kind), do: enforce_visibility(kind, default)

  defp normalize_visibility(value, default, kind) when is_binary(value) do
    normalized = String.downcase(value)

    case normalized do
      "private" -> enforce_visibility(kind, :private)
      "team" -> enforce_visibility(kind, :team)
      "hidden" -> enforce_visibility(kind, :private)
      "public" -> enforce_visibility(kind, :team)
      _ -> enforce_visibility(kind, default)
    end
  end

  defp normalize_visibility(value, _default, kind) when value in [:private, :team] do
    enforce_visibility(kind, value)
  end

  defp normalize_visibility(_value, default, kind), do: enforce_visibility(kind, default)

  defp enforce_visibility(:group, _value), do: :private
  defp enforce_visibility(:direct, _value), do: :private
  defp enforce_visibility(_kind, value), do: value

  defp default_visibility_for(:group), do: :private
  defp default_visibility_for(:channel), do: :team
  defp default_visibility_for(_kind), do: :private

  defp maybe_resolve_media(kind, conversation_id, profile_id, attrs)
       when kind in [:audio, :video, :image, :voice, :file, :thumbnail] do
    media =
      case Map.get(attrs, "media") || Map.get(attrs, :media) do
        %{} = map -> map
        _ -> %{}
      end

    upload_id =
      media["upload_id"] || media["uploadId"] || media[:upload_id] || media[:uploadId] ||
        attrs["upload_id"] || attrs["uploadId"] || attrs[:upload_id] || attrs[:uploadId]

    if is_binary(upload_id) do
      metadata = build_media_metadata(kind, media)

      case Media.consume_upload(upload_id, conversation_id, profile_id, metadata) do
        {:ok, payload} ->
          normalized_payload = normalize_media_payload(kind, payload)
          caption = get_in(normalized_payload, ["media", "caption"])

          sanitized =
            attrs
            |> Map.drop(["media", :media, "upload_id", :upload_id, "uploadId", :uploadId])
            |> maybe_put_caption_body(caption)

          {normalized_payload, sanitized}

        {:error, reason} -> Repo.rollback(reason)
      end
    else
      Repo.rollback(:missing_media_upload)
    end
  end

  defp maybe_resolve_media(_kind, _conversation_id, _profile_id, attrs), do: {nil, attrs}

  defp normalize_media_payload(kind, payload) do
    media = Map.get(payload, "media") || %{}

    normalized_caption =
      media
      |> Map.get("caption")
      |> Kernel.||(media["description"])
      |> case do
        nil -> nil
        value when is_binary(value) -> String.trim(value)
        _ -> nil
      end

    normalized_thumbnail = normalize_thumbnail(media)
    normalized_waveform = normalize_waveform(media)

    media =
      media
      |> Map.drop(["description", "waveForm", "thumbnailUrl"])
      |> maybe_put_string("caption", normalized_caption)
      |> maybe_put_map("thumbnail", normalized_thumbnail)
      |> maybe_put_waveform(normalized_waveform)

    %{"media" => media}
    |> Map.merge(Map.drop(payload, ["media", :media]))
    |> maybe_put_media_body(kind, normalized_caption)
  end

  defp normalize_thumbnail(media) do
    thumb = media["thumbnail"] || media["thumbnailUrl"]

    cond do
      is_map(thumb) ->
        normalized = Map.new(thumb, fn {k, v} -> {to_string(k), v} end)
        object_key = normalized["objectKey"] || normalized["object_key"]
        content_type = normalized["contentType"] || normalized["content_type"]

        normalized
        |> Map.drop(["object_key", "content_type"])
        |> maybe_put_string("objectKey", object_key)
        |> maybe_put_string("bucket", normalized["bucket"])
        |> maybe_put_string("contentType", content_type)

      is_binary(thumb) ->
        %{"url" => thumb, "width" => media["width"], "height" => media["height"]}

      true ->
        nil
    end
  end

  defp normalize_waveform(media) do
    wave = media["waveform"] || media["waveForm"]

    cond do
      is_list(wave) -> Enum.map(wave, &normalize_waveform_point/1)
      true -> nil
    end
  end

  defp normalize_waveform_point(value) when is_number(value), do: clamp(round(value), 0, 100)

  defp normalize_waveform_point(_), do: nil

  defp maybe_put_waveform(media, nil), do: Map.delete(media, "waveform")

  defp maybe_put_waveform(media, waveform) do
    clean =
      waveform
      |> Enum.filter(&is_integer/1)
      |> Enum.take(512)
    if clean == [] do
      Map.delete(media, "waveform")
    else
      Map.put(media, "waveform", clean)
    end
  end

  defp maybe_put_string(map, _key, nil), do: map
  defp maybe_put_string(map, key, value) when is_binary(value) and value != "" do
    Map.put(map, key, value)
  end
  defp maybe_put_string(map, key, _value), do: Map.delete(map, key)

  defp maybe_put_map(map, _key, nil), do: map
  defp maybe_put_map(map, key, value) when is_map(value), do: Map.put(map, key, value)
  defp maybe_put_map(map, key, _), do: Map.delete(map, key)

  defp maybe_put_media_body(payload, kind, caption) when kind in [:image, :video, :audio, :voice, :file] do
    if caption && caption != "" do
      Map.put(payload, "body", caption)
    else
      payload
    end
  end

  defp maybe_put_media_body(payload, _kind, _caption), do: payload

  defp maybe_put_caption_body(attrs, caption) do
    cond do
      is_map(attrs) and is_binary(caption) and caption != "" -> Map.put(attrs, "body", caption)
      true -> attrs
    end
  end

  defp clamp(value, min, max) when value < min, do: min
  defp clamp(value, min, max) when value > max, do: max
  defp clamp(value, _min, _max), do: value

  defp merge_payload(base, nil), do: base || %{}

  defp merge_payload(base, media_payload) when is_map(media_payload) do
    Map.merge(base || %{}, media_payload, fn _key, existing, incoming ->
      cond do
        is_map(existing) and is_map(incoming) ->
          Map.merge(existing, incoming, fn _inner_key, _old, new -> new end)

        true ->
          incoming
      end
    end)
  end

  defp build_media_metadata(kind, media) do
    media_map =
      media
      |> Map.drop(["upload_id", "uploadId", :upload_id, :uploadId])
      |> normalize_media_map(kind)

    if Enum.empty?(media_map) do
      %{}
    else
      %{"media" => media_map}
    end
  end

  defp normalize_media_map(media, kind) do
    media
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case normalize_media_entry(kind, key, value) do
        {normalized_key, normalized_value} -> Map.put(acc, normalized_key, normalized_value)
        :skip -> acc
      end
    end)
    |> maybe_attach_dimensions(media)
  end

  defp maybe_attach_dimensions(map, media) do
    case fetch_dimensions(media) do
      {nil, nil} -> map
      {width, height} ->
        map
        |> Map.put_new("width", width)
        |> Map.put_new("height", height)
    end
  end

  defp fetch_dimensions(media) do
    direct_width = normalize_positive_integer(Map.get(media, "width") || Map.get(media, :width))
    direct_height = normalize_positive_integer(Map.get(media, "height") || Map.get(media, :height))

    case Map.get(media, "dimensions") || Map.get(media, :dimensions) do
      %{} = dims ->
        width = direct_width || normalize_positive_integer(Map.get(dims, "width") || Map.get(dims, :width))
        height = direct_height || normalize_positive_integer(Map.get(dims, "height") || Map.get(dims, :height))
        {width, height}

      _ ->
        {direct_width, direct_height}
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["caption", :caption] do
    case normalize_string(value, 0, 2000) do
      nil -> :skip
      caption -> {"caption", caption}
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["checksum", :checksum, "hash", :hash] do
    case normalize_checksum(value) do
      nil -> :skip
      checksum -> {"checksum", checksum}
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["duration", :duration] do
    case normalize_duration(value) do
      nil -> :skip
      duration -> {"duration", duration}
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["durationMs", :durationMs, "duration_ms", :duration_ms] do
    case normalize_duration_ms(value) do
      nil -> :skip
      duration_ms -> {"durationMs", duration_ms}
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["waveform", :waveform] do
    case normalize_waveform(value) do
      nil -> :skip
      waveform -> {"waveform", waveform}
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["thumbnail", :thumbnail] do
    case normalize_thumbnail(value) do
      nil -> :skip
      thumbnail -> {"thumbnail", thumbnail}
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["waveformSampleRate", :waveformSampleRate] do
    case normalize_positive_integer(value) do
      nil -> :skip
      rate -> {"waveformSampleRate", rate}
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["metadata", :metadata] do
    case value do
      %{} = metadata ->
        nested =
          metadata
          |> Enum.reduce(%{}, fn {nested_key, nested_value}, acc ->
            if is_binary(nested_key) do
              Map.put(acc, nested_key, nested_value)
            else
              acc
            end
          end)

        if map_size(nested) == 0, do: :skip, else: {"metadata", nested}

      _ ->
        :skip
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["width", :width, "height", :height] do
    # Dimensions handled separately to support nested maps.
    case normalize_positive_integer(value) do
      nil -> :skip
      normalized -> {Atom.to_string(key), normalized}
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["mimeType", :mimeType] do
    case normalize_string(value, 3, 256) do
      nil -> :skip
      mime -> {"mimeType", mime}
    end
  end

  defp normalize_media_entry(_kind, key, value) when key in ["contentType", :contentType] do
    case normalize_string(value, 3, 256) do
      nil -> :skip
      mime -> {"contentType", mime}
    end
  end

  defp normalize_media_entry(_kind, _key, _value), do: :skip

  defp normalize_duration(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _} -> normalize_duration(number)
      :error -> nil
    end
  end

  defp normalize_duration(value) when is_number(value) do
    cond do
      value <= 0 -> nil
      true -> Float.round(value * 1.0, 3)
    end
  end

  defp normalize_duration(_), do: nil

  defp normalize_duration_ms(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _} -> normalize_duration_ms(number)
      :error -> nil
    end
  end

  defp normalize_duration_ms(value) when is_integer(value) and value > 0, do: value
  defp normalize_duration_ms(value) when is_float(value) and value > 0, do: trunc(Float.round(value))
  defp normalize_duration_ms(_), do: nil

  defp normalize_checksum(value) when is_binary(value) do
    trimmed = String.trim(value)

    if Regex.match?(~r/\A[A-Fa-f0-9]{32,128}\z/, trimmed) do
      String.downcase(trimmed)
    else
      nil
    end
  end

  defp normalize_checksum(_), do: nil

  defp normalize_waveform(value) when is_list(value) do
    normalized =
      value
      |> Enum.map(fn point ->
        cond do
          is_number(point) ->
            point
            |> Kernel./(1.0)
            |> max(0.0)
            |> min(1.0)

          true ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.take(512)

    if normalized == [], do: nil, else: normalized
  end

  defp normalize_waveform(_), do: nil

  defp normalize_thumbnail(%{} = value) do
    normalized =
      value
      |> Enum.reduce(%{}, fn {key, val}, acc ->
        case normalize_thumbnail_entry(key, val) do
          {normalized_key, normalized_value} -> Map.put(acc, normalized_key, normalized_value)
          :skip -> acc
        end
      end)

    if map_size(normalized) == 0 do
      nil
    else
      normalized
    end
  end

  defp normalize_thumbnail(_), do: nil

  defp normalize_thumbnail_entry(key, value) when key in ["bucket", :bucket, "bucketName", :bucketName] do
    case normalize_string(value, 1, 200) do
      nil -> :skip
      bucket -> {"bucket", bucket}
    end
  end

  defp normalize_thumbnail_entry(key, value) when key in ["objectKey", :objectKey, "object_key", :object_key] do
    case normalize_string(value, 1, 500) do
      nil -> :skip
      object_key -> {"objectKey", object_key}
    end
  end

  defp normalize_thumbnail_entry(key, value) when key in ["width", :width, "height", :height] do
    case normalize_positive_integer(value) do
      nil -> :skip
      normalized -> {Atom.to_string(key), normalized}
    end
  end

  defp normalize_thumbnail_entry(key, value) when key in ["url", :url] do
    case normalize_string(value, 5, 2048) do
      nil -> :skip
      url -> {"url", url}
    end
  end

  defp normalize_thumbnail_entry(key, value) when key in ["contentType", :contentType, "mimeType", :mimeType] do
    case normalize_string(value, 3, 256) do
      nil -> :skip
      mime -> {"contentType", mime}
    end
  end

  defp normalize_thumbnail_entry(_key, _value), do: :skip

  defp normalize_string(value, min, max) when is_binary(value) do
    trimmed = String.trim(value)

    if String.length(trimmed) in min..max do
      trimmed
    else
      nil
    end
  end

  defp normalize_string(_, _, _), do: nil

  defp normalize_positive_integer(value) when is_integer(value) and value > 0, do: value

  defp normalize_positive_integer(value) when is_float(value) and value > 0 do
    trunc(Float.round(value))
  end

  defp normalize_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _} when number > 0 -> number
      _ -> nil
    end
  end

  defp normalize_positive_integer(_), do: nil
  defp fetch_message!(conversation_id, message_id) do
    case Repo.get_by(Message, id: message_id, conversation_id: conversation_id) do
      %Message{deleted_at: nil} = message -> message
      %Message{deleted_at: _} -> Repo.rollback(:message_deleted)
      nil -> Repo.rollback(:message_not_found)
    end
  end

  defp normalize_emoji(nil), do: Repo.rollback(:invalid_emoji)

  defp normalize_emoji(emoji) when is_binary(emoji) do
    value = emoji |> String.trim()

    if value == "" do
      Repo.rollback(:invalid_emoji)
    else
      value
    end
  end

  defp normalize_emoji(_emoji), do: Repo.rollback(:invalid_emoji)

  defp normalize_metadata(nil), do: %{}
  defp normalize_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata(_metadata), do: Repo.rollback(:invalid_metadata)

  defp broadcast_reaction_added(conversation_id, %MessageReaction{} = reaction) do
    broadcast_conversation_event(conversation_id, {:reaction_added, reaction_payload(reaction)})
  end

  defp broadcast_reaction_removed(conversation_id, %MessageReaction{} = reaction) do
    broadcast_conversation_event(conversation_id, {:reaction_removed, reaction_payload(reaction)})
  end

  defp broadcast_message_pinned(conversation_id, %PinnedMessage{} = pinned) do
    broadcast_conversation_event(conversation_id, {:message_pinned, pinned_payload(pinned)})
  end

  defp broadcast_message_unpinned(conversation_id, %PinnedMessage{} = pinned) do
    broadcast_conversation_event(conversation_id, {:message_unpinned, pinned_payload(pinned)})
  end

  defp broadcast_message_read(conversation_id, profile_id, message_id, read_at) do
    broadcast_conversation_event(conversation_id, {:message_read, %{
      profile_id: profile_id,
      message_id: message_id,
      read_at: read_at
    }})
  end

  defp broadcast_conversation_event(conversation_id, event) do
    payload =
      case event do
        {:reaction_added, reaction} ->
          {:reaction_added, enrich_reaction_event(reaction)}

        {:reaction_removed, reaction} ->
          {:reaction_removed, enrich_reaction_event(reaction)}

        {:message_pinned, pinned} ->
          {:message_pinned, pinned}

        {:message_unpinned, pinned} ->
          {:message_unpinned, pinned}

        {:message_read, attrs} ->
          {:message_read, attrs}

        other ->
          other
      end

    PubSub.broadcast(Messngr.PubSub, conversation_topic(conversation_id), payload)
    :ok
  end

  defp enrich_reaction_event(reaction) do
    message_id = Map.fetch!(reaction, :message_id)
    Map.put(reaction, :aggregates, reaction_aggregates(message_id))
  end

  defp reaction_payload(%MessageReaction{} = reaction) do
    %{
      id: reaction.id,
      message_id: reaction.message_id,
      profile_id: reaction.profile_id,
      emoji: reaction.emoji,
      metadata: reaction.metadata,
      inserted_at: reaction.inserted_at,
      updated_at: reaction.updated_at
    }
  end

  defp pinned_payload(%PinnedMessage{} = pinned) do
    %{
      id: pinned.id,
      conversation_id: pinned.conversation_id,
      message_id: pinned.message_id,
      pinned_by_id: pinned.pinned_by_id,
      pinned_at: pinned.pinned_at,
      metadata: pinned.metadata
    }
  end

  defp reaction_aggregates(message_id) do
    MessageReaction
    |> where([r], r.message_id == ^message_id)
    |> Repo.all()
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, reactions} ->
      %{
        emoji: emoji,
        count: Enum.count(reactions),
        profile_ids: reactions |> Enum.map(& &1.profile_id) |> Enum.uniq()
      }
    end)
  end

  defp take_permitted_attrs(attrs, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      value = Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))

      if is_nil(value) do
        acc
      else
        Map.put(acc, key, value)
      end
    end)
  end

  defp maybe_normalize_metadata(attrs) do
    case Map.fetch(attrs, :metadata) do
      {:ok, metadata} -> Map.put(attrs, :metadata, normalize_metadata(metadata))
      :error -> attrs
    end
  end

  defp maybe_put_delete_metadata(map, opts) do
    metadata = opts[:metadata] || Map.get(opts, "metadata")

    if is_nil(metadata) do
      map
    else
      Map.put(map, :metadata, normalize_metadata(metadata))
    end
  end
end
