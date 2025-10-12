defmodule Messngr.Chat.Message do
  @moduledoc """
  Chat messages knyttet til en conversation. For nå lagrer vi ren tekst og en
  enkel status.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :body, :string
    field :status, Ecto.Enum, values: [:sending, :sent, :delivered, :read], default: :sent
    field :sent_at, :utc_datetime
    field :kind, Ecto.Enum,
      values: [:text, :markdown, :code, :system, :image, :video, :audio, :voice, :file, :thumbnail, :location],
      default: :text
    field :payload, :map, default: %{}
    field :metadata, :map, default: %{}
    field :edited_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :conversation, Messngr.Chat.Conversation
    belongs_to :profile, Messngr.Accounts.Profile
    belongs_to :thread, Messngr.Chat.MessageThread

    has_many :reactions, Messngr.Chat.MessageReaction
    has_many :receipts, Messngr.Chat.MessageReceipt

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :body,
      :status,
      :conversation_id,
      :profile_id,
      :sent_at,
      :kind,
      :payload,
      :metadata,
      :edited_at,
      :deleted_at,
      :thread_id
    ])
    |> validate_required([:conversation_id, :profile_id, :kind])
    |> put_default_payload()
    |> put_default_metadata()
    |> validate_body_for_kind()
    |> validate_payload_for_kind()
  end

  defp put_default_payload(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :payload) do
      nil -> put_change(changeset, :payload, %{})
      %{} = payload -> put_change(changeset, :payload, payload)
      _ -> add_error(changeset, :payload, "must be a map")
    end
  end

  defp put_default_metadata(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :metadata) do
      nil -> put_change(changeset, :metadata, %{})
      %{} = metadata -> put_change(changeset, :metadata, metadata)
      _ -> add_error(changeset, :metadata, "must be a map")
    end
  end

  defp validate_body_for_kind(%Ecto.Changeset{} = changeset) do
    kind = get_field(changeset, :kind)

    cond do
      kind in [:text, :markdown, :code] ->
        changeset
        |> validate_required([:body])
        |> validate_length(:body, min: 1, max: 4000)

      kind == :system ->
        changeset
        |> validate_required([:body])
        |> validate_length(:body, min: 1, max: 4000)

      true ->
        changeset
    end
  end

  defp validate_payload_for_kind(%Ecto.Changeset{} = changeset) do
    kind = get_field(changeset, :kind)
    payload = get_field(changeset, :payload) || %{}

    cond do
      kind in [:audio, :video, :voice, :file, :image, :thumbnail] ->
        validate_media_payload(changeset, kind, payload)

      kind == :location ->
        require_payload_keys(changeset, payload, ["latitude", "longitude"])

      true ->
        changeset
    end
  end

  defp validate_media_payload(changeset, kind, payload) do
    case require_payload_keys(changeset, payload, ["media"]) do
      %Ecto.Changeset{valid?: false} = changeset -> changeset
      %Ecto.Changeset{} ->
        media = Map.get(payload, "media") || %{}
        base_keys = ["bucket", "objectKey", "contentType", "byteSize", "url"]
        missing = Enum.reject(base_keys, &Map.has_key?(media, &1))

        cond do
          missing != [] ->
            add_error(changeset, :payload, "missing media keys: #{Enum.join(missing, ", ")}")

          true ->
            changesets =
              changeset
              |> validate_optional_caption(media)
              |> validate_optional_waveform(kind, media)
              |> validate_optional_thumbnail(media)
              |> validate_dimensions(kind, media)

            changesets
        end
    end
  end

  defp validate_dimensions(changeset, kind, media) when kind in [:image, :video] do
    cond do
      Map.has_key?(media, "width") and Map.has_key?(media, "height") ->
        changeset
        |> validate_number_in_map(media, "width", greater_than: 0)
        |> validate_number_in_map(media, "height", greater_than: 0)

      true ->
        add_error(changeset, :payload, "missing media keys: width, height")
    end
  end

  defp validate_dimensions(changeset, _kind, _media), do: changeset

  defp validate_number_in_map(changeset, media, key, opts) do
    case Map.fetch(media, key) do
      {:ok, value} when is_integer(value) or is_float(value) ->
        minimum = Keyword.get(opts, :greater_than)
        if is_number(value) and (is_nil(minimum) or value > minimum) do
          changeset
          |> validate_waveform_payload(media)
          |> validate_thumbnail_payload(media)
          |> validate_dimensions_payload(media)
          |> validate_checksum_payload(media)
        else
          add_error(changeset, :payload, "invalid #{key}")
        end

      {:ok, _other} ->
        add_error(changeset, :payload, "invalid #{key}")

      :error ->
        changeset
    end
  end

  defp validate_optional_caption(changeset, media) do
    case Map.get(media, "caption") do
      nil -> changeset
      caption when is_binary(caption) ->
        if String.length(String.trim(caption)) <= 4_000 do
          changeset
        else
          add_error(changeset, :payload, "caption is too long")
        end

      _ ->
        add_error(changeset, :payload, "caption must be a string")
    end
  end

  defp validate_optional_waveform(changeset, kind, media) when kind in [:audio, :voice] do
    case Map.get(media, "waveform") do
      nil -> changeset
      waveform when is_list(waveform) ->
        if Enum.all?(waveform, &valid_waveform_point?/1) and length(waveform) <= 512 do
          changeset
        else
          add_error(changeset, :payload, "waveform must be <=512 samples between 0 and 100")
        end

      _ ->
        add_error(changeset, :payload, "waveform must be a list of integers")
    end
  end

  defp validate_optional_waveform(changeset, _kind, _media), do: changeset

  defp valid_waveform_point?(value) when is_integer(value), do: value in 0..100
  defp valid_waveform_point?(value) when is_float(value), do: value >= 0 and value <= 100
  defp valid_waveform_point?(_), do: false

  defp validate_optional_thumbnail(changeset, media) do
    case Map.get(media, "thumbnail") do
      nil -> changeset
      %{} = thumb ->
        base_keys = ["url", "width", "height"]
        missing = Enum.reject(base_keys, &Map.has_key?(thumb, &1))

        cond do
          missing != [] ->
            add_error(changeset, :payload, "thumbnail missing keys: #{Enum.join(missing, ", ")}")

          not valid_thumbnail_dimension?(thumb["width"]) or
              not valid_thumbnail_dimension?(thumb["height"]) ->
            add_error(changeset, :payload, "thumbnail dimensions must be positive numbers")

          true ->
            changeset
        end

      _ ->
        add_error(changeset, :payload, "thumbnail must be a map")
    end
  end

  defp valid_thumbnail_dimension?(value) when is_integer(value) and value > 0, do: true
  defp valid_thumbnail_dimension?(value) when is_float(value) and value > 0, do: true
  defp valid_thumbnail_dimension?(_), do: false

  defp require_payload_keys(changeset, payload, keys) do
    missing = Enum.reject(keys, &Map.has_key?(payload, &1))

    if missing == [] do
      changeset
    else
      add_error(changeset, :payload, "missing keys: #{Enum.join(missing, ", ")}")
    end
  end

  defp validate_waveform_payload(changeset, media) do
    case Map.get(media, "waveform") do
      nil -> changeset
      waveform when is_list(waveform) ->
        valid? = Enum.all?(waveform, fn value -> is_number(value) and value >= 0 and value <= 1 end)

        if valid? do
          changeset
        else
          add_error(changeset, :payload, "waveform must contain numbers between 0 and 1")
        end

      _ ->
        add_error(changeset, :payload, "waveform must be a list")
    end
  end

  defp validate_thumbnail_payload(changeset, media) do
    case Map.get(media, "thumbnail") do
      nil -> changeset
      %{} = thumbnail ->
        missing =
          ["bucket", "objectKey", "url"]
          |> Enum.reject(&Map.has_key?(thumbnail, &1))

        if missing == [] do
          changeset
        else
          add_error(changeset, :payload, "thumbnail missing keys: #{Enum.join(missing, ", ")}")
        end

      _ ->
        add_error(changeset, :payload, "thumbnail must be a map")
    end
  end

  defp validate_dimensions_payload(changeset, media) do
    [
      validate_positive_integer(media, "width", "width must be positive"),
      validate_positive_integer(media, "height", "height must be positive")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(changeset, fn message, acc -> add_error(acc, :payload, message) end)
  end

  defp validate_positive_integer(media, key, message) do
    case Map.get(media, key) do
      nil -> nil
      value when is_integer(value) and value > 0 -> nil
      value when is_float(value) and value > 0 -> nil
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int, _} when int > 0 -> nil
          _ -> message
        end

      _ ->
        message
    end
  end

  defp validate_checksum_payload(changeset, media) do
    case Map.get(media, "checksum") do
      nil -> changeset
      checksum when is_binary(checksum) ->
        if Regex.match?(~r/\A[A-Fa-f0-9]{32,128}\z/, checksum) do
          changeset
        else
          add_error(changeset, :payload, "checksum must be hexadecimal")
        end

      _ ->
        add_error(changeset, :payload, "checksum must be a string")
    end
  end
end
