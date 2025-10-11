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

  @spec list_messages(binary(), keyword()) :: [Message.t()]
  def list_messages(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before_id = Keyword.get(opts, :before_id)

    base_query =
      from m in Message,
        where: m.conversation_id == ^conversation_id,
        order_by: [desc: m.sent_at, desc: m.inserted_at]

    query = base_query |> maybe_before(before_id) |> limit(^limit)

    query
    |> Repo.all()
    |> Repo.preload(:profile)
    |> Enum.reverse()
  end

  defp preload_conversation(id) do
    Conversation
    |> Repo.get!(id)
    |> Repo.preload(participants: [:profile])
  end

  defp ensure_participant!(conversation_id, profile_id) do
    Repo.get_by!(Participant, conversation_id: conversation_id, profile_id: profile_id)
  end

  defp maybe_before(query, nil), do: query

  defp maybe_before(query, message_id) do
    case Repo.get(Message, message_id) do
      %Message{inserted_at: inserted_at} -> from m in query, where: m.inserted_at < ^inserted_at
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
