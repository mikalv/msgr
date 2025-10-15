defmodule MessngrWeb.Telemetry.Socket do
  @moduledoc """
  Emits telemetry events for Phoenix socket activity so we can inspect send→ack
  latency and typing behaviour before wiring up a full observability pipeline.
  """

  @doc """Emit an event when a user sends a message through the socket."""
  @spec message_sent(binary(), binary(), map()) :: :ok
  def message_sent(conversation_id, profile_id, metadata \\ %{}) do
    emit([:messngr, :socket, :message, :sent], %{count: 1},
      Map.merge(metadata, %{conversation_id: conversation_id, profile_id: profile_id})
    )
  end

  @doc """Emit an event when the client acknowledges delivery."""
  @spec message_acknowledged(binary(), binary(), binary(), map()) :: :ok
  def message_acknowledged(conversation_id, profile_id, message_id, metadata \\ %{}) do
    emit([:messngr, :socket, :message, :acknowledged], %{count: 1},
      Map.merge(metadata, %{
        conversation_id: conversation_id,
        profile_id: profile_id,
        message_id: message_id
      })
    )
  end

  @doc """Emit an event when a user starts typing."""
  @spec typing_started(binary(), binary(), map()) :: :ok
  def typing_started(conversation_id, profile_id, metadata \\ %{}) do
    emit([:messngr, :socket, :typing, :started], %{count: 1},
      Map.merge(metadata, %{conversation_id: conversation_id, profile_id: profile_id})
    )
  end

  @doc """Emit an event when a user stops typing."""
  @spec typing_stopped(binary(), binary(), map()) :: :ok
  def typing_stopped(conversation_id, profile_id, metadata \\ %{}) do
    emit([:messngr, :socket, :typing, :stopped], %{count: 1},
      Map.merge(metadata, %{conversation_id: conversation_id, profile_id: profile_id})
    )
  end

  defp emit(event, measurements, metadata) do
    :telemetry.execute(event, measurements, metadata)
    :ok
  end
end
