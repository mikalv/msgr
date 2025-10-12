defmodule Messngr.Chat.MessageReceipt do
  @moduledoc """
  Tracks per-recipient delivery and read acknowledgements for chat messages.

  A receipt is created for every participant (excluding the sender) when a
  message is persisted. Clients update the receipt as soon as a device has
  received or read the message so that the sender can see delivery guarantees
  across devices.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias __MODULE__

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type status :: :pending | :delivered | :read
  @type t :: %__MODULE__{
          id: binary() | nil,
          message: Messngr.Chat.Message.t() | Ecto.Association.NotLoaded.t() | nil,
          message_id: binary() | nil,
          recipient: Messngr.Accounts.Profile.t() | Ecto.Association.NotLoaded.t() | nil,
          recipient_id: binary() | nil,
          device: Messngr.Accounts.Device.t() | Ecto.Association.NotLoaded.t() | nil,
          device_id: binary() | nil,
          status: status() | nil,
          delivered_at: DateTime.t() | nil,
          read_at: DateTime.t() | nil,
          metadata: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "message_receipts" do
    belongs_to :message, Messngr.Chat.Message
    belongs_to :recipient, Messngr.Accounts.Profile
    belongs_to :device, Messngr.Accounts.Device

    field :status, Ecto.Enum, values: [:pending, :delivered, :read], default: :pending
    field :delivered_at, :utc_datetime
    field :read_at, :utc_datetime
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(%MessageReceipt{} = receipt, attrs) when is_map(attrs) do
    receipt
    |> cast(attrs, [
      :message_id,
      :recipient_id,
      :device_id,
      :status,
      :delivered_at,
      :read_at,
      :metadata
    ])
    |> validate_required([:message_id, :recipient_id])
    |> normalize_metadata()
    |> enforce_status_progression()
    |> validate_status_timestamps()
    |> unique_constraint(:recipient_id,
      name: :message_receipts_message_id_recipient_id_index
    )
  end

  defp normalize_metadata(changeset) do
    update_change(changeset, :metadata, fn
      nil -> %{}
      %{} = metadata -> metadata
      value when is_map(value) -> value
      _ -> %{}
    end)
  end

  defp enforce_status_progression(changeset) do
    current = changeset.data.status
    next = get_field(changeset, :status)

    cond do
      is_nil(current) -> changeset
      is_nil(next) -> changeset
      status_rank(next) < status_rank(current) ->
        add_error(changeset, :status, "cannot regress status")
      true -> changeset
    end
  end

  defp validate_status_timestamps(changeset) do
    changeset
    |> validate_required_for(:delivered, :delivered_at)
    |> validate_required_for(:read, :read_at)
  end

  defp validate_required_for(changeset, status, field) do
    if get_field(changeset, :status) in [status, :read] do
      validate_required(changeset, [field])
    else
      changeset
    end
  end

  defp status_rank(:pending), do: 0
  defp status_rank(:delivered), do: 1
  defp status_rank(:read), do: 2
  defp status_rank(_), do: -1
end

