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
      values: [:text, :markdown, :code, :system, :image, :video, :audio, :location],
      default: :text
    field :payload, :map, default: %{}

    belongs_to :conversation, Messngr.Chat.Conversation
    belongs_to :profile, Messngr.Accounts.Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :status, :conversation_id, :profile_id, :sent_at, :kind, :payload])
    |> validate_required([:conversation_id, :profile_id, :kind])
    |> put_default_payload()
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
      kind in [:audio, :video] ->
        validate_media_payload(changeset, payload)

      kind == :image ->
        require_payload_keys(changeset, payload, ["url"])

      kind == :location ->
        require_payload_keys(changeset, payload, ["latitude", "longitude"])

      true ->
        changeset
    end
  end

  defp validate_media_payload(changeset, payload) do
    required = ["media"]

    case require_payload_keys(changeset, payload, required) do
      %Ecto.Changeset{valid?: false} = changeset -> changeset
      %Ecto.Changeset{} ->
        media = Map.get(payload, "media") || %{}
        missing =
          ["bucket", "objectKey", "contentType", "byteSize", "url"]
          |> Enum.reject(&Map.has_key?(media, &1))

        if missing == [] do
          changeset
        else
          add_error(changeset, :payload, "missing media keys: #{Enum.join(missing, ", ")}")
        end
    end
  end

  defp require_payload_keys(changeset, payload, keys) do
    missing = Enum.reject(keys, &Map.has_key?(payload, &1))

    if missing == [] do
      changeset
    else
      add_error(changeset, :payload, "missing keys: #{Enum.join(missing, ", ")}")
    end
  end
end
