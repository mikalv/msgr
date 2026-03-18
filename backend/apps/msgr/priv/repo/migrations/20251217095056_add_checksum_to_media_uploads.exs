defmodule Messngr.Repo.Migrations.AddChecksumToMediaUploads do
  use Ecto.Migration

  def change do
    alter table(:media_uploads) do
      add :checksum, :string
    end
  end
end
