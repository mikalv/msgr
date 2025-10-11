defmodule Messngr.Chat do
  @moduledoc """
  Chat contexts for å opprette samtaler, legge til deltakere og sende meldinger.
  """

  import Ecto.Query

  alias Phoenix.PubSub

  alias Messngr.{Accounts, Media, Repo}
  alias Messngr.Accounts.Profile
  alias Messngr.Chat.{Conversation, Message, Participant}

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
  @message_kinds [:text, :markdown, :code, :system, :image, :video, :audio, :location]

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
    :ets.insert(table, {conversation_id, profile_id})

    payload = watcher_payload(conversation_id)
    broadcast_watchers(conversation_id, payload)
    {:ok, payload}
  end

  def unwatch_conversation(conversation_id, profile_id) do
    table = ensure_watcher_table!()
    :ets.delete_object(table, {conversation_id, profile_id})

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
          from {c, _cp} in query,
            where:
              fragment("COALESCE(?, ?) < ?", c.updated_at, c.inserted_at, ^cutoff) or
                (fragment("COALESCE(?, ?) = ?", c.updated_at, c.inserted_at, ^cutoff) and
                   c.id < ^conversation.id)

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
    ensure_watcher_table!()

    conversation_id
    |> :ets.lookup(@watcher_table)
    |> Enum.map(fn {^conversation_id, profile_id} -> profile_id end)
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

  defp maybe_resolve_media(kind, conversation_id, profile_id, attrs) when kind in [:audio, :video] do
    media =
      case Map.get(attrs, "media") || Map.get(attrs, :media) do
        %{} = map -> map
        _ -> %{}
      end

    upload_id =
      media["upload_id"] || media["uploadId"] || media[:upload_id] || media[:uploadId] ||
        attrs["upload_id"] || attrs["uploadId"] || attrs[:upload_id] || attrs[:uploadId]

    if is_binary(upload_id) do
      metadata = Map.drop(media, ["upload_id", "uploadId"])

      case Media.consume_upload(upload_id, conversation_id, profile_id, metadata) do
        {:ok, payload} ->
          sanitized =
            attrs
            |> Map.drop(["media", "upload_id", "uploadId"])

          {payload, sanitized}

        {:error, reason} -> Repo.rollback(reason)
      end
    else
      Repo.rollback(:missing_media_upload)
    end
  end

  defp maybe_resolve_media(_kind, _conversation_id, _profile_id, attrs), do: {nil, attrs}

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
end
