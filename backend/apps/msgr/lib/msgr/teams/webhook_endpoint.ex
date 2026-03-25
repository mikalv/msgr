defmodule Messngr.Teams.WebhookEndpoint do
  @moduledoc """
  Incoming webhook endpoint. External services POST to /api/hooks/:token
  to create messages in a channel as a bot user.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Messngr.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @token_length 32

  schema "webhook_endpoints" do
    field :channel_id, :binary_id
    field :token, :string
    field :name, :string
    field :avatar_url, :string
    field :enabled, :boolean, default: true
    field :message_count, :integer, default: 0

    belongs_to :team, Messngr.Teams.Team
    belongs_to :created_by_account, Messngr.Accounts.Account, foreign_key: :created_by_account_id

    timestamps(type: :utc_datetime)
  end

  def changeset(endpoint, attrs) do
    endpoint
    |> cast(attrs, [:team_id, :channel_id, :token, :name, :avatar_url, :created_by_account_id, :enabled])
    |> validate_required([:team_id, :channel_id, :token, :name, :created_by_account_id])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint(:token)
  end

  @doc "Create a new webhook endpoint for a channel."
  def create(attrs) do
    %__MODULE__{}
    |> changeset(Map.put(attrs, :token, generate_token()))
    |> Repo.insert()
  end

  @doc "Find an enabled webhook endpoint by token."
  def get_by_token(token) do
    __MODULE__
    |> where([w], w.token == ^token and w.enabled == true)
    |> Repo.one()
    |> Repo.preload(:team)
  end

  @doc "List webhook endpoints for a team."
  def list_for_team(team_id) do
    __MODULE__
    |> where([w], w.team_id == ^team_id)
    |> order_by([w], desc: w.inserted_at)
    |> Repo.all()
  end

  @doc "Delete a webhook endpoint."
  def delete(id) do
    case Repo.get(__MODULE__, id) do
      nil -> {:error, :not_found}
      endpoint -> Repo.delete(endpoint)
    end
  end

  @doc "Increment the message_count after a successful post."
  def increment_count(endpoint) do
    from(w in __MODULE__, where: w.id == ^endpoint.id)
    |> Repo.update_all(inc: [message_count: 1])
  end

  defp generate_token do
    :crypto.strong_rand_bytes(@token_length)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, @token_length)
  end
end
