defmodule Messngr.Bridges.AuthSession do
  @moduledoc """
  Represents a bridge authentication attempt initiated by a Msgr account. Sessions
  capture the login surface, connector metadata, and client context so the
  frontend can drive wizard flows while backend workers continue the exchange.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Accounts.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @states ~w(initiated awaiting_user completing linked failed expired cancelled)

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          account_id: Ecto.UUID.t() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t() | nil,
          service: String.t() | nil,
          state: String.t() | nil,
          login_method: String.t() | nil,
          auth_surface: String.t() | nil,
          client_context: map(),
          metadata: map(),
          catalog_snapshot: map(),
          expires_at: DateTime.t() | nil,
          last_transition_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "bridge_auth_sessions" do
    belongs_to :account, Account

    field :service, :string
    field :state, :string
    field :login_method, :string
    field :auth_surface, :string
    field :client_context, :map, default: %{}
    field :metadata, :map, default: %{}
    field :catalog_snapshot, :map, default: %{}
    field :expires_at, :utc_datetime_usec
    field :last_transition_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  States supported by the session state machine.
  """
  @spec states() :: [String.t()]
  def states, do: @states

  @doc """
  Changeset used when creating a new bridge auth session.
  """
  @spec creation_changeset(t(), map()) :: Ecto.Changeset.t()
  def creation_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :account_id,
      :service,
      :state,
      :login_method,
      :auth_surface,
      :client_context,
      :metadata,
      :catalog_snapshot,
      :expires_at,
      :last_transition_at
    ])
    |> validate_required([
      :account_id,
      :service,
      :state,
      :login_method,
      :auth_surface,
      :client_context,
      :metadata,
      :catalog_snapshot,
      :last_transition_at
    ])
    |> validate_inclusion(:state, @states)
    |> validate_length(:service, min: 1)
    |> validate_length(:login_method, min: 1)
    |> validate_length(:auth_surface, min: 1)
    |> ensure_map_fields([:client_context, :metadata, :catalog_snapshot])
  end

  @doc """
  Changeset for updating an existing session (state transitions, metadata).
  """
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(session, attrs) do
    session
    |> cast(attrs, [:state, :metadata, :expires_at, :last_transition_at])
    |> validate_optional_state()
    |> ensure_map_fields([:metadata])
  end

  defp validate_optional_state(%Ecto.Changeset{} = changeset) do
    case get_change(changeset, :state) do
      nil -> changeset
      _state ->
        changeset
        |> validate_required([:state])
        |> validate_inclusion(:state, @states)
        |> validate_length(:state, min: 1)
    end
  end

  defp ensure_map_fields(%Ecto.Changeset{} = changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      if Map.has_key?(acc.changes, field) do
        validate_change(acc, field, fn
          ^field, value when is_map(value) -> []
          ^field, value -> [{field, {"must be a map", [kind: :map, value: value]}}]
        end)
      else
        acc
      end
    end)
  end
end
