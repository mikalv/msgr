defmodule Teams.Repo.Migrations.CreateRoomsTable do
  use Ecto.Migration

  def change do
    create table(:rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :topic, :string
      add :description, :string, default: ""
      add :members, {:array, :string}
      add :is_secret, :boolean, default: false
      add :metadata, :map, default: "{}"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:rooms, [:name])


    create table(:channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :topic, :string
      add :channel_type, :string, default: "room"
      add :description, :string, default: ""
      add :members, {:array, :string}
      add :is_secret, :boolean, default: false
      add :metadata, :map, default: "{}"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:channels, [:name])
  end
end
