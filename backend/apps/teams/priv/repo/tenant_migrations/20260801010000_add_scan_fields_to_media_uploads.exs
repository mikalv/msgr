defmodule Teams.Repo.TenantMigrations.AddScanFieldsToMediaUploads do
  use Ecto.Migration

  def change do
    alter table(:media_uploads) do
      add :scan_status, :string, null: false, default: "awaiting_upload"
      add :scanned_at, :utc_datetime
      add :threat_name, :string
      add :quarantine_key, :string
    end

    create index(:media_uploads, [:scan_status])
  end
end
