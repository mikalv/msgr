defmodule Messngr.Chat do
  @moduledoc """
  Chat contexts for å opprette samtaler, legge til deltakere og sende meldinger.
  """

  import Ecto.Query

  alias Phoenix.PubSub

  alias Messngr.{Accounts, Media, Repo}
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

  @default_message_limit 50

  @spec list_messages(binary(), keyword()) :: %{entries: [Message.t()], meta: map()}
  def list_messages(conversation_id, opts \\ []) do
    limit = normalize_limit(opts, @default_message_limit)
    before_id = Keyword.get(opts, :before_id)
    after_id = Keyword.get(opts, :after_id)
    around_id = Keyword.get(opts, :around_id)

    base_query =
      from m in Message,
        where: m.conversation_id == ^conversation_id,
        order_by: [desc: m.sent_at, desc: m.inserted_at]

    query =
      base_query
      |> maybe_before(before_id)
      |> maybe_after(after_id)

    raw_messages =
      query
      |> limit(^(limit + 1))
      |> Repo.all()
      |> Repo.preload(:profile)

    has_more? = has_more(raw_messages, limit: limit)
    page_entries = raw_messages |> Enum.take(limit) |> Enum.reverse()

    meta = %{
      before_id: first_id(page_entries),
      after_id: after_id(page_entries, limit: limit, requested_after: after_id),
      around_id: around_id(page_entries, around_id: around_id),
      has_more: has_more?
    }

    %{entries: page_entries, meta: meta}
  end

  @spec list_conversations(binary(), keyword()) :: %{entries: list(), meta: map()}
  def list_conversations(profile_id, opts \\ []) do
    limit = normalize_limit(opts, 20)
    before_id = Keyword.get(opts, :before_id)
    after_id = Keyword.get(opts, :after_id)

    latest_message_query =
      from m in Message,
        order_by: [desc: m.sent_at, desc: m.inserted_at],
        limit: 1,
        preload: [:profile]

    base_query =
      from participant in Participant,
        as: :participant,
        where: participant.profile_id == ^profile_id,
        join: conversation in assoc(participant, :conversation),
        as: :conversation,
        preload: [
          conversation: {conversation, [participants: [:profile], messages: ^latest_message_query]}
        ],
        order_by: [desc: conversation.updated_at, desc: conversation.inserted_at]

    query =
      base_query
      |> maybe_conversation_before(before_id)
      |> maybe_conversation_after(after_id)

    raw_participants =
      query
      |> limit(^(limit + 1))
      |> Repo.all()

    has_more? = has_more(raw_participants, limit: limit)

    entries =
      raw_participants
      |> Enum.take(limit)
      |> Enum.map(fn participant ->
        conversation = participant.conversation
        last_message = conversation.messages |> List.first()

        %{
          conversation: conversation,
          participant: participant,
          last_message: last_message,
          unread_count: unread_count(conversation.id, participant)
        }
      end)

    meta = %{
      before_id: last_conversation_id(entries),
      after_id: first_conversation_id(entries),
      around_id: nil,
      has_more: has_more?
    }

    %{entries: entries, meta: meta}
  end

  defp preload_conversation(id) do
    Conversation
    |> Repo.get!(id)
    |> Repo.preload(participants: [:profile])
  end

  defp ensure_participant!(conversation_id, profile_id) do
    Repo.get_by!(Participant, conversation_id: conversation_id, profile_id: profile_id)
  end

  defp normalize_limit(opts, default) do
    opts
    |> Keyword.get(:limit, default)
    |> case do
      limit when is_integer(limit) and limit > 0 -> min(limit, 200)
      _ -> default
    end
  end

  def after_id([], opts), do: Keyword.get(opts, :requested_after)

  def after_id(entries, _opts) do
    entries
    |> List.last()
    |> case do
      nil -> nil
      %{id: id} -> id
      %Conversation{id: id} -> id
      entry -> Map.get(entry, :id)
    end
  end

  def around_id([], opts), do: Keyword.get(opts, :around_id)

  def around_id(entries, opts) do
    Keyword.get(opts, :around_id) ||
      (entries
       |> Enum.at(div(Enum.count(entries), 2))
       |> case do
         nil -> nil
         %{id: id} -> id
         %Conversation{id: id} -> id
         entry -> Map.get(entry, :id)
       end)
  end

  def has_more(entries, opts \\ []) do
    limit = normalize_limit(opts, @default_message_limit)
    Enum.count(entries) > limit
  end

  defp first_id([]), do: nil
  defp first_id([%{id: id} | _]), do: id
  defp first_id([%Conversation{id: id} | _]), do: id
  defp first_id([entry | _]), do: Map.get(entry, :id)

  defp first_conversation_id([]), do: nil

  defp first_conversation_id([entry | _]) do
    case entry do
      %{conversation: %Conversation{id: id}} -> id
      _ -> nil
    end
  end

  defp last_conversation_id([]), do: nil

  defp last_conversation_id(entries) do
    entries
    |> List.last()
    |> case do
      %{conversation: %Conversation{id: id}} -> id
      _ -> nil
    end
  end

  defp unread_count(conversation_id, %Participant{} = participant) do
    base_query =
      from m in Message,
        where: m.conversation_id == ^conversation_id,
        where: m.profile_id != ^participant.profile_id

    query =
      case participant.last_read_at do
        nil -> base_query
        last_read_at -> from m in base_query, where: m.inserted_at > ^last_read_at
      end

    Repo.aggregate(query, :count, :id)
  end

  defp maybe_before(query, nil), do: query

  defp maybe_before(query, message_id) do
    case Repo.get(Message, message_id) do
      %Message{inserted_at: inserted_at, sent_at: nil} ->
        from m in query, where: m.inserted_at < ^inserted_at

      %Message{inserted_at: inserted_at, sent_at: sent_at} ->
        from m in query,
          where:
            fragment(
              "(? > ?) OR (? = ? AND ? < ?)",
              ^sent_at,
              m.sent_at,
              ^sent_at,
              m.sent_at,
              ^inserted_at,
              m.inserted_at
            )

      _ -> query
    end
  end

  defp maybe_after(query, nil), do: query

  defp maybe_after(query, message_id) do
    case Repo.get(Message, message_id) do
      %Message{inserted_at: inserted_at, sent_at: nil} ->
        from m in query, where: m.inserted_at > ^inserted_at

      %Message{inserted_at: inserted_at, sent_at: sent_at} ->
        from m in query,
          where:
            fragment(
              "(? < ?) OR (? = ? AND ? > ?)",
              ^sent_at,
              m.sent_at,
              ^sent_at,
              m.sent_at,
              ^inserted_at,
              m.inserted_at
            )

      _ -> query
    end
  end

  defp maybe_conversation_before(query, nil), do: query

  defp maybe_conversation_before(query, conversation_id) do
    case Repo.get(Conversation, conversation_id) do
      %Conversation{updated_at: updated_at, inserted_at: inserted_at} ->
        from q in query,
          where:
            fragment(
              "(? > ?) OR (? = ? AND ? < ?)",
              ^updated_at,
              parent_as(:conversation).updated_at,
              ^updated_at,
              parent_as(:conversation).updated_at,
              ^inserted_at,
              parent_as(:conversation).inserted_at
            )

      _ -> query
    end
  end

  defp maybe_conversation_after(query, nil), do: query

  defp maybe_conversation_after(query, conversation_id) do
    case Repo.get(Conversation, conversation_id) do
      %Conversation{updated_at: updated_at, inserted_at: inserted_at} ->
        from q in query,
          where:
            fragment(
              "(? < ?) OR (? = ? AND ? > ?)",
              ^updated_at,
              parent_as(:conversation).updated_at,
              ^updated_at,
              parent_as(:conversation).updated_at,
              ^inserted_at,
              parent_as(:conversation).inserted_at
            )

      _ -> query
    end
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

  def broadcast_backlog(conversation_id, page) do
    PubSub.broadcast(
      Messngr.PubSub,
      conversation_topic(conversation_id),
      {:message_page, page}
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
