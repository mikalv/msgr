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
end
