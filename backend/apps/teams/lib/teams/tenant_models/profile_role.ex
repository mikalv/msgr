defmodule Teams.TenantModels.ProfileRole do
  @moduledoc """
  UserProject module
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Multi
  alias Teams.TenantModels.{Profile, Role}
  alias Teams.Repo

  @already_exists "ALREADY_EXISTS"

  @primary_key false
  schema "profile_roles" do
    belongs_to(:profile, Profile, primary_key: true, type: :binary_id)
    belongs_to(:role, Role, primary_key: true, type: :binary_id)

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(profile_id role_id)a
  def changeset(profile_role, params \\ %{}) do
    profile_role
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:profile_id)
    |> foreign_key_constraint(:role_id)
    |> unique_constraint([:profiles, :roles],
      name: :profile_id_role_id_unique_index,
      message: @already_exists
    )
  end

  def upsert_profile_roles(tenant, profile_id, role_ids) when is_list(role_ids) do
    {:ok, time} = Ecto.Type.cast(:utc_datetime, Timex.now())

    profile_roles =
      role_ids
      |> Enum.uniq()
      |> Enum.map(fn role_id ->
        %{
          profile_id: profile_id,
          role_id: role_id,
          inserted_at: time,
          updated_at: time
        }
      end)

    multi =
      Multi.new()
      |> Multi.delete_all(
        :profile_role_deleted,
        __MODULE__
        |> where([profile_role], profile_role.profile_id == ^profile_id), prefix: Triplex.to_prefix(tenant)
      )
      |> Multi.insert_all(:profile_role_inserted, __MODULE__, profile_roles, prefix: Triplex.to_prefix(tenant))

    case Repo.transaction(multi, prefix: Triplex.to_prefix(tenant)) do
      {:ok, _multi_result} ->
        {:ok, Profile.get_by_id(tenant, profile_id)}

      {:error, changeset} ->
        {:error, changeset}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end
end
