defmodule Messngr.Calls do
  @moduledoc """
  Public interface for managing real-time audio and video calls. Uses
  `Messngr.Calls.CallRegistry` to maintain in-memory state shared between the
  Phoenix signalling channels and the rest of the application.
  """

  alias Messngr.Calls.{CallRegistry, CallSession, Participant}

  @type call_id :: String.t()
  @type conversation_id :: String.t()
  @type profile_id :: String.t()
  @type join_result :: {:ok, CallSession.t(), Participant.t()} | {:error, term()}

  @spec start_call(conversation_id(), profile_id(), keyword()) :: {:ok, CallSession.t()} | {:error, term()}
  def start_call(conversation_id, host_profile_id, opts \\ []) do
    opts =
      opts
      |> Keyword.update(:media, [:audio, :video], &normalise_media/1)
      |> Keyword.update(:kind, :group, &normalise_kind/1)

    CallRegistry.create_call(conversation_id, host_profile_id, opts)
  end

  @spec fetch_call(call_id()) :: {:ok, CallSession.t()} | {:error, term()}
  def fetch_call(call_id), do: CallRegistry.fetch_call(call_id)

  @spec fetch_call_for_conversation(conversation_id()) :: {:ok, CallSession.t()} | {:error, term()}
  def fetch_call_for_conversation(conversation_id),
    do: CallRegistry.fetch_call_for_conversation(conversation_id)

  @spec join_call(call_id(), profile_id(), keyword()) :: join_result()
  def join_call(call_id, profile_id, opts \\ []) do
    opts = Keyword.update(opts, :metadata, %{}, &normalise_metadata/1)
    CallRegistry.join_call(call_id, profile_id, opts)
  end

  @spec leave_call(call_id(), profile_id(), keyword()) ::
          {:ok, :participant_left | :call_ended, CallSession.t() | nil} | {:error, term()}
  def leave_call(call_id, profile_id, opts \\ []) do
    CallRegistry.leave_call(call_id, profile_id, opts)
  end

  @spec end_call(call_id()) :: :ok | {:error, term()}
  def end_call(call_id), do: CallRegistry.end_call(call_id)

  @spec participants(CallSession.t()) :: [Participant.t()]
  def participants(%CallSession{} = call), do: Map.values(call.participants)

  defp normalise_media(media) when is_list(media) do
    media
    |> Enum.map(&normalise_medium/1)
    |> Enum.uniq()
  end

  defp normalise_media(_), do: [:audio, :video]

  defp normalise_medium(:audio), do: :audio
  defp normalise_medium(:video), do: :video
  defp normalise_medium("audio"), do: :audio
  defp normalise_medium("video"), do: :video
  defp normalise_medium(_), do: :audio

  defp normalise_kind(:group), do: :group
  defp normalise_kind("group"), do: :group
  defp normalise_kind(:direct), do: :direct
  defp normalise_kind("direct"), do: :direct
  defp normalise_kind(_), do: :group

  defp normalise_metadata(metadata) when is_map(metadata), do: metadata
  defp normalise_metadata(_), do: %{}
end
