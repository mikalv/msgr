defmodule Messngr.Repo.Migrations.AddAvatarUrlToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add_if_not_exists :avatar_url, :text
    end
  end
end
