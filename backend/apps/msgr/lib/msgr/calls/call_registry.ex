defmodule Messngr.Calls.CallRegistry do
  @moduledoc """
  Supervises in-memory call sessions for WebRTC signalling. The registry keeps
  track of which conversations currently have an active call and which profiles
  participate in each call so that Phoenix channels can route SDP offers and
  ICE candidates to the correct peers.
  """

  use GenServer

  alias Messngr.Calls.{CallSession, Participant}
  alias UUID

  @valid_kinds [:direct, :group]

  defmodule State do
    @moduledoc false
    defstruct sessions: %{}, conversation_index: %{}
  end

  @type option :: {:name, atom()}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %State{}, name: name)
  end

  @doc """
  Starts a new call for the provided conversation. Only one active call per
  conversation is allowed; attempting to start a second call will return
  `{:error, :call_in_progress}`.
  """
  @spec create_call(String.t(), String.t(), keyword()) :: {:ok, CallSession.t()} | {:error, term()}
  def create_call(conversation_id, host_profile_id, opts \\ []) do
    GenServer.call(server(opts), {:create_call, conversation_id, host_profile_id, opts})
  end

  @doc """
  Returns an active call by ID.
  """
  @spec fetch_call(String.t(), keyword()) :: {:ok, CallSession.t()} | {:error, term()}
  def fetch_call(call_id, opts \\ []) do
    GenServer.call(server(opts), {:fetch_call, call_id})
  end

  @doc """
  Returns an active call for the given conversation.
  """
  @spec fetch_call_for_conversation(String.t(), keyword()) :: {:ok, CallSession.t()} | {:error, term()}
  def fetch_call_for_conversation(conversation_id, opts \\ []) do
    GenServer.call(server(opts), {:fetch_call_for_conversation, conversation_id})
  end

  @doc """
  Adds a participant to the call, returning the updated session and the
  participant struct.
  """
  @spec join_call(String.t(), String.t(), keyword()) ::
          {:ok, CallSession.t(), Participant.t()} | {:error, term()}
  def join_call(call_id, profile_id, opts \\ []) do
    GenServer.call(server(opts), {:join_call, call_id, profile_id, opts})
  end

  @doc """
  Removes a participant from the call. If the call becomes empty it is removed
  from the registry.
  """
  @spec leave_call(String.t(), String.t(), keyword()) ::
          {:ok, :participant_left | :call_ended, CallSession.t() | nil} | {:error, term()}
  def leave_call(call_id, profile_id, opts \\ []) do
    GenServer.call(server(opts), {:leave_call, call_id, profile_id})
  end

  @doc """
  Forcefully ends a call and removes it from the registry.
  """
  @spec end_call(String.t(), keyword()) :: :ok | {:error, term()}
  def end_call(call_id, opts \\ []) do
    GenServer.call(server(opts), {:end_call, call_id})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:create_call, conversation_id, host_profile_id, opts}, _from, state) do
    with :ok <- validate_kind(Keyword.get(opts, :kind, :group)),
         :ok <- ensure_available(state, conversation_id) do
      call_id = Keyword.get_lazy(opts, :call_id, &UUID.uuid4/0)
      kind = Keyword.get(opts, :kind, :group)
      media = normalise_media(Keyword.get(opts, :media, [:audio, :video]))
      metadata = Keyword.get(opts, :metadata, %{})

      session =
        CallSession.new(%{
          id: call_id,
          conversation_id: conversation_id,
          kind: kind,
          media: media,
          host_profile_id: host_profile_id,
          metadata: metadata
        })

      session = put_host_metadata(session, metadata)

      {:reply, {:ok, session}, put_session(state, session)}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:fetch_call, call_id}, _from, state) do
    case Map.fetch(state.sessions, call_id) do
      {:ok, session} -> {:reply, {:ok, session}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:fetch_call_for_conversation, conversation_id}, _from, state) do
    with {:ok, call_id} <- Map.fetch(state.conversation_index, conversation_id),
         {:ok, session} <- Map.fetch(state.sessions, call_id) do
      {:reply, {:ok, session}, state}
    else
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:join_call, call_id, profile_id, opts}, _from, state) do
    case Map.fetch(state.sessions, call_id) do
      :error ->
        {:reply, {:error, :not_found}, state}

      {:ok, session} ->
        metadata = opts |> Keyword.get(:metadata, %{}) |> normalise_metadata()
        role = Keyword.get(opts, :role, :participant)
        status = Keyword.get(opts, :status, :connecting)

        case CallSession.add_participant(session, profile_id, role: role, status: status, metadata: metadata) do
          {:ok, updated_session, participant} ->
            new_state = put_session(state, updated_session)
            {:reply, {:ok, updated_session, participant}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:leave_call, call_id, profile_id}, _from, state) do
    case Map.fetch(state.sessions, call_id) do
      :error ->
        {:reply, {:error, :not_found}, state}

      {:ok, session} ->
        case CallSession.remove_participant(session, profile_id) do
          {:missing, _} ->
            {:reply, {:ok, :participant_left, session}, state}

          {:removed, updated_session} ->
            cond do
              CallSession.empty?(updated_session) ->
                new_state = drop_session(state, updated_session)
                {:reply, {:ok, :call_ended, nil}, new_state}

              profile_id == updated_session.host_profile_id ->
                new_state = drop_session(state, updated_session)
                {:reply, {:ok, :call_ended, nil}, new_state}

              true ->
                new_state = put_session(state, updated_session)
                {:reply, {:ok, :participant_left, updated_session}, new_state}
            end
        end
    end
  end

  def handle_call({:end_call, call_id}, _from, state) do
    case Map.fetch(state.sessions, call_id) do
      :error -> {:reply, {:error, :not_found}, state}
      {:ok, session} -> {:reply, :ok, drop_session(state, session)}
    end
  end

  defp put_session(state, %CallSession{} = session) do
    %State{
      sessions: Map.put(state.sessions, session.id, session),
      conversation_index: Map.put(state.conversation_index, session.conversation_id, session.id)
    }
  end

  defp drop_session(state, %CallSession{} = session) do
    %State{
      sessions: Map.delete(state.sessions, session.id),
      conversation_index: Map.delete(state.conversation_index, session.conversation_id)
    }
  end

  defp ensure_available(%State{conversation_index: index}, conversation_id) do
    if Map.has_key?(index, conversation_id) do
      {:error, :call_in_progress}
    else
      :ok
    end
  end

  defp validate_kind(kind) when kind in @valid_kinds, do: :ok
  defp validate_kind(_), do: {:error, :invalid_kind}

  defp normalise_media(media) when is_list(media) do
    media
    |> Enum.map(&normalise_medium/1)
    |> Enum.uniq()
  end

  defp normalise_media(_), do: [:audio, :video]

  defp normalise_medium(value) when value in [:audio, :video], do: value
  defp normalise_medium("audio"), do: :audio
  defp normalise_medium("video"), do: :video
  defp normalise_medium(_), do: :audio

  defp normalise_metadata(metadata) when is_map(metadata), do: metadata
  defp normalise_metadata(_), do: %{}

  defp put_host_metadata(%CallSession{} = session, metadata) do
    host_metadata =
      metadata
      |> normalise_metadata()
      |> Map.put("role", "host")
      |> Map.put_new("kind", "host")

    host = Participant.host(session.host_profile_id)
    participants = Map.put(session.participants, session.host_profile_id, %{host | metadata: host_metadata})
    %CallSession{session | participants: participants}
  end

  defp server(opts), do: Keyword.get(opts, :name, __MODULE__)
end
