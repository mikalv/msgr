defmodule Messngr.Repo.Migrations.AddStructureTypeAndVisibilityToConversations do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'conversation_structure_type') THEN
        CREATE TYPE conversation_structure_type AS ENUM ('family', 'business', 'friends', 'project', 'other');
      END IF;
    END$$;
    """)

    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'conversation_visibility') THEN
        CREATE TYPE conversation_visibility AS ENUM ('private', 'team');
      END IF;
    END$$;
    """)

    alter table(:conversations) do
      add :structure_type, :conversation_structure_type
      add :visibility, :conversation_visibility, default: 'private', null: false
    end
  end

  def down do
    alter table(:conversations) do
      remove :structure_type
      remove :visibility
    end
  end
end
