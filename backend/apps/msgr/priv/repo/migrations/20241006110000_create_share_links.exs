defmodule Messngr.Repo.Migrations.CreateShareLinks do
  use Ecto.Migration

  def change do
    create table(:share_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string, null: false
      add :kind, :string, null: false
      add :usage, :string, null: false, default: "bridge"
      add :title, :string
      add :description, :text
      add :payload, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}
      add :source, :map, null: false, default: %{}
      add :capabilities, :map, null: false, default: %{}
      add :expires_at, :utc_datetime
      add :view_count, :integer, null: false, default: 0
      add :max_views, :integer

      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :bridge_account_id, references(:bridge_accounts, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:share_links, [:token])
    create index(:share_links, [:account_id])
    create index(:share_links, [:bridge_account_id])
    create index(:share_links, [:expires_at])
  end
end

