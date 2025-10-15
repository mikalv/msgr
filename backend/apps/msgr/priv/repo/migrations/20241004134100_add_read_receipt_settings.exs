defmodule Messngr.Repo.Migrations.AddReadReceiptSettings do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :read_receipts_enabled, :boolean, null: false, default: true
    end

    alter table(:conversations) do
      add :read_receipts_enabled, :boolean, null: false, default: true
    end
  end
end
