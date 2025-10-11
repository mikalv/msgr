defmodule Messngr.Calls.CallSession do
  @moduledoc """
  Represents an in-memory WebRTC call session. Stores metadata about the
  conversation, participants and requested media types so that the signalling
  layer can coordinate offers/answers between peers.
  """

  alias Messngr.Calls.Participant

  @enforce_keys [:id, :conversation_id, :kind, :media, :host_profile_id]
  defstruct [:id, :conversation_id, :kind, :media, :host_profile_id, metadata: %{}, participants: %{}]

  @type id :: String.t()
  @type conversation_id :: String.t()
  @type kind :: :direct | :group
  @type media :: [:audio | :video]

  @type t :: %__MODULE__{
          id: id(),
          conversation_id: conversation_id(),
          kind: kind(),
          media: media(),
          host_profile_id: String.t(),
          metadata: map(),
          participants: %{optional(String.t()) => Participant.t()}
        }

  @spec new(map()) :: t()
  def new(attrs) do
    id = Map.fetch!(attrs, :id)
    conversation_id = Map.fetch!(attrs, :conversation_id)
    kind = Map.fetch!(attrs, :kind)
    media = Map.get(attrs, :media, [:audio])
    host_profile_id = Map.fetch!(attrs, :host_profile_id)
    metadata = Map.get(attrs, :metadata, %{})

    base_session = %__MODULE__{
      id: id,
      conversation_id: conversation_id,
      kind: kind,
      media: media,
      host_profile_id: host_profile_id,
      metadata: metadata,
      participants: %{}
    }

    {_status, session, _participant} = add_participant(base_session, host_profile_id, role: :host, status: :connected)
    session
  end

  @spec add_participant(t(), String.t(), keyword()) :: {:ok, t(), Participant.t()} | {:error, term()}
  def add_participant(%__MODULE__{} = session, profile_id, opts \\ []) when is_binary(profile_id) do
    case Map.fetch(session.participants, profile_id) do
      {:ok, participant} ->
        {:ok, session, participant}

      :error ->
        participant =
          opts
          |> Keyword.put(:profile_id, profile_id)
          |> Keyword.put_new(:role, :participant)
          |> Keyword.put_new(:status, :connecting)
          |> Participant.new()

        {:ok, put_in(session.participants[profile_id], participant), participant}
    end
  end

  @spec remove_participant(t(), String.t()) :: {:removed | :missing, t()}
  def remove_participant(%__MODULE__{} = session, profile_id) when is_binary(profile_id) do
    case Map.pop(session.participants, profile_id) do
      {nil, _participants} ->
        {:missing, session}

      {_participant, participants} ->
        {:removed, %__MODULE__{session | participants: participants}}
    end
  end

  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{} = session), do: map_size(session.participants) == 0
end
