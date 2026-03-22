defmodule Messngr.Repo.Migrations.AddAvatarUrlToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :avatar_url, :text
    end
  end
end
