defmodule Messngr.CallsTest do
  use Messngr.DataCase, async: true

  alias Messngr.Calls
  alias Messngr.Calls.{CallSession, Participant}

  setup do
    %{conversation_id: Ecto.UUID.generate(), host_id: Ecto.UUID.generate()}
  end

  test "start_call registers conversation and host", %{conversation_id: conversation_id, host_id: host_id} do
    assert {:ok, %CallSession{} = call} = Calls.start_call(conversation_id, host_id, media: [:audio])
    assert call.conversation_id == conversation_id
    assert call.host_profile_id == host_id
    assert call.media == [:audio]
    assert Map.has_key?(call.participants, host_id)
  end

  test "cannot start second call for same conversation", %{conversation_id: conversation_id, host_id: host_id} do
    assert {:ok, _} = Calls.start_call(conversation_id, host_id)
    assert {:error, :call_in_progress} = Calls.start_call(conversation_id, host_id)
  end

  test "join_call adds participant", %{conversation_id: conversation_id, host_id: host_id} do
    {:ok, call} = Calls.start_call(conversation_id, host_id)
    participant_id = Ecto.UUID.generate()

    assert {:ok, %CallSession{} = updated, %Participant{} = participant} =
             Calls.join_call(call.id, participant_id, metadata: %{"tracks" => ["audio"]})

    assert participant.profile_id == participant_id
    assert participant.metadata == %{"tracks" => ["audio"]}
    assert Map.has_key?(updated.participants, participant_id)
  end

  test "direct calls reject more than two participants", %{conversation_id: conversation_id, host_id: host_id} do
    assert {:ok, %CallSession{} = call} = Calls.start_call(conversation_id, host_id, kind: :direct)

    first_participant = Ecto.UUID.generate()
    second_participant = Ecto.UUID.generate()

    assert {:ok, %CallSession{} = updated, %Participant{} = participant} =
             Calls.join_call(call.id, first_participant)

    assert participant.profile_id == first_participant
    assert Map.has_key?(updated.participants, first_participant)

    assert {:ok, ^updated, ^participant} = Calls.join_call(call.id, first_participant)
    assert {:error, :direct_call_full} = Calls.join_call(call.id, second_participant)
  end

  test "leave_call removes participant and ends empty call", %{conversation_id: conversation_id, host_id: host_id} do
    {:ok, call} = Calls.start_call(conversation_id, host_id)
    assert {:ok, :call_ended, nil} = Calls.leave_call(call.id, host_id)
    assert {:error, :not_found} = Calls.fetch_call(call.id)
  end

  test "end_call cleans up registry", %{conversation_id: conversation_id, host_id: host_id} do
    {:ok, call} = Calls.start_call(conversation_id, host_id)
    assert :ok = Calls.end_call(call.id)
    assert {:error, :not_found} = Calls.fetch_call(call.id)
  end
end
