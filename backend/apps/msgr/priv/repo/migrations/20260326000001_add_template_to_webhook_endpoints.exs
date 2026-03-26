defmodule Messngr.Repo.Migrations.AddTemplateToWebhookEndpoints do
  use Ecto.Migration

  def change do
    alter table(:webhook_endpoints) do
      add :template, :text
      add :template_preset, :string
    end
  end
end
