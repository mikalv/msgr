defmodule Messngr.Accounts.AccountSettings do
  @moduledoc """
  Per-account user preferences that sync between devices.

  Uses the account_id as primary key (one settings row per account).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "account_settings" do
    belongs_to :account, Messngr.Accounts.Account, type: :binary_id, primary_key: true

    # Notifications
    field :notify_desktop, :boolean, default: true
    field :notify_mobile, :boolean, default: true
    field :notify_about, :string, default: "everything"
    field :notify_thread_replies, :boolean, default: true
    field :notify_sounds, :boolean, default: true

    # Do Not Disturb
    field :dnd_enabled, :boolean, default: false
    field :dnd_start, :time
    field :dnd_end, :time

    # Privacy
    field :show_online_status, :boolean, default: true
    field :show_read_receipts, :boolean, default: true
    field :show_typing_indicators, :boolean, default: true

    # Language & region
    field :locale, :string, default: "en"
    field :date_format, :string, default: "auto"
    field :time_24h, :boolean, default: true

    # Status
    field :status_text, :string
    field :status_emoji, :string
    field :status_expires_at, :utc_datetime

    field :updated_at, :utc_datetime
  end

  @castable_fields [
    :notify_desktop,
    :notify_mobile,
    :notify_about,
    :notify_thread_replies,
    :notify_sounds,
    :dnd_enabled,
    :dnd_start,
    :dnd_end,
    :show_online_status,
    :show_read_receipts,
    :show_typing_indicators,
    :locale,
    :date_format,
    :time_24h,
    :status_text,
    :status_emoji,
    :status_expires_at
  ]

  @valid_notify_about ~w(everything mentions dms_only nothing)

  @doc false
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, @castable_fields)
    |> validate_inclusion(:notify_about, @valid_notify_about)
    |> put_change(:updated_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
