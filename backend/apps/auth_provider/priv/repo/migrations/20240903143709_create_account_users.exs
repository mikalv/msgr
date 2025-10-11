defmodule Teams.Repo.Migrations.CreateAccountUsers do
  use Ecto.Migration

  def change do
    create table(:account_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :msisdn, :string
      add :email, :string
      add :first_name, :string, null: true
      add :last_name, :string, null: true
      add :metadata, :map, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create constraint(:account_users, :either_msisdn_or_email_must_be_set, check: "(msisdn IS NOT NULL OR email IS NOT NULL)")
  end
end
