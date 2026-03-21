defmodule Messngr.Repo.Migrations.CreateAccountSettings do
  use Ecto.Migration

  def change do
    create table(:account_settings, primary_key: false) do
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      # Notifications
      add :notify_desktop, :boolean, default: true, null: false
      add :notify_mobile, :boolean, default: true, null: false
      add :notify_about, :text, default: "everything", null: false
      add :notify_thread_replies, :boolean, default: true, null: false
      add :notify_sounds, :boolean, default: true, null: false

      # Do Not Disturb
      add :dnd_enabled, :boolean, default: false, null: false
      add :dnd_start, :time
      add :dnd_end, :time

      # Privacy
      add :show_online_status, :boolean, default: true, null: false
      add :show_read_receipts, :boolean, default: true, null: false
      add :show_typing_indicators, :boolean, default: true, null: false

      # Language & region
      add :locale, :text, default: "en", null: false
      add :date_format, :text, default: "auto", null: false
      add :time_24h, :boolean, default: true, null: false

      # Status
      add :status_text, :text
      add :status_emoji, :text
      add :status_expires_at, :utc_datetime

      add :updated_at, :utc_datetime, null: false, default: fragment("now()")
    end
  end
end
