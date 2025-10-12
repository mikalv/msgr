defmodule MessngrWeb.RTCChannel do
  @moduledoc """
  Phoenix channel responsible for WebRTC signalling. Participants join the
  conversation-specific topic and exchange SDP offers/answers and ICE candidates
  via the server.
  """

  use MessngrWeb, :channel

  alias Ecto.UUID
  alias Messngr.Calls
  alias Messngr.Calls.{CallSession, Participant}

  @impl true
  def join("rtc:" <> conversation_id, params, %{assigns: %{current_profile: profile}} = socket) do
    with {:ok, conversation_id} <- cast_uuid(conversation_id),
         {:ok, call} <- ensure_call(conversation_id, profile.id, params),
         {:ok, call, participant} <-
           Calls.join_call(call.id, profile.id, metadata: Map.get(params, "metadata", %{})) do
      socket =
        socket
        |> assign(:call_id, call.id)
        |> assign(:conversation_id, conversation_id)
        |> assign(:profile_id, profile.id)

      payload = %{
        "call_id" => call.id,
        "conversation_id" => conversation_id,
        "kind" => Atom.to_string(call.kind),
        "media" => Enum.map(call.media, &Atom.to_string/1),
        "participants" => encode_participants(call)
      }

        {:ok, Map.put(payload, "participant", encode_participant(participant)), socket}
    else
      {:error, reason} ->
        {:error, %{reason: to_string(reason)}}
    end
  end

  def join(_topic, _params, _socket), do: {:error, %{reason: "unauthorized"}}

  @impl true
  def handle_in("signal:offer", %{"sdp" => _} = payload, socket) do
    broadcast_from!(socket, "signal:offer", decorate_payload(payload, socket))
    {:noreply, socket}
  end

  def handle_in("signal:answer", %{"sdp" => _} = payload, socket) do
    broadcast_from!(socket, "signal:answer", decorate_payload(payload, socket))
    {:noreply, socket}
  end

  def handle_in("signal:candidate", %{"candidate" => _} = payload, socket) do
    broadcast_from!(socket, "signal:candidate", decorate_payload(payload, socket))
    {:noreply, socket}
  end

  def handle_in("call:leave", _payload, socket) do
    case Calls.leave_call(socket.assigns.call_id, socket.assigns.profile_id) do
      {:ok, :call_ended, _} ->
        broadcast!(socket, "call:ended", %{"call_id" => socket.assigns.call_id})
        {:reply, :ok, socket}

      {:ok, :participant_left, call} ->
        broadcast!(socket, "participant:left", %{
          "call_id" => socket.assigns.call_id,
          "profile_id" => socket.assigns.profile_id,
          "participants" => encode_participants(call)
        })

        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("call:end", _payload, socket) do
    case Calls.end_call(socket.assigns.call_id) do
      :ok ->
        broadcast!(socket, "call:ended", %{"call_id" => socket.assigns.call_id})
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    Calls.leave_call(socket.assigns.call_id, socket.assigns.profile_id)
    :ok
  end

  defp ensure_call(_conversation_id, _profile_id, %{"call_id" => call_id}) when is_binary(call_id) do
    case Calls.fetch_call(call_id) do
      {:ok, call} -> {:ok, call}
      {:error, :not_found} -> {:error, :call_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_call(conversation_id, profile_id, params) do
    kind = params |> Map.get("kind", infer_kind(params)) |> normalise_kind()
    media = params |> Map.get("media", ["audio", "video"]) |> normalise_media()
    params_metadata = Map.get(params, "metadata", %{})

    case Calls.start_call(conversation_id, profile_id,
           kind: kind,
           media: media,
           metadata: params_metadata
         ) do
      {:ok, call} -> {:ok, call}
      {:error, :call_in_progress} -> Calls.fetch_call_for_conversation(conversation_id)
      {:error, reason} -> {:error, reason}
    end
  end

  defp decorate_payload(payload, socket) do
    payload
    |> Map.put("from", socket.assigns.profile_id)
    |> Map.put("call_id", socket.assigns.call_id)
  end

  defp encode_participants(%CallSession{} = call) do
    call.participants
    |> Map.values()
    |> Enum.map(&encode_participant/1)
  end

  defp encode_participant(%Participant{} = participant) do
    %{
      "profile_id" => participant.profile_id,
      "role" => Atom.to_string(participant.role),
      "status" => Atom.to_string(participant.status),
      "metadata" => participant.metadata
    }
  end

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_conversation}
    end
  end

  defp infer_kind(%{"peer_profile_id" => _}), do: :direct
  defp infer_kind(_), do: :group

  defp normalise_kind(kind) when kind in [:direct, :group], do: kind
  defp normalise_kind("direct"), do: :direct
  defp normalise_kind("group"), do: :group
  defp normalise_kind(_), do: :group

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
end
