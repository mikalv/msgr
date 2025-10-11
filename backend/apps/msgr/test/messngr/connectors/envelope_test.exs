defmodule Messngr.Connectors.EnvelopeTest do
  use ExUnit.Case, async: true

  alias Msgr.Connectors.Envelope

  describe "new/4" do
    test "builds a canonical envelope with defaults" do
      {:ok, envelope} = Envelope.new(:telegram, :send, %{body: "hi"})

      assert envelope.schema == "msgr.bridge.v1"
      assert envelope.service == "telegram"
      assert envelope.action == "send"
      assert envelope.metadata == %{}
      assert is_binary(envelope.trace_id)
      assert envelope.payload == %{body: "hi"}
      assert DateTime.compare(envelope.occurred_at, DateTime.utc_now()) in [:lt, :eq]
    end

    test "accepts overrides for trace_id, metadata, schema and occurred_at" do
      occurred_at = DateTime.utc_now() |> DateTime.add(-60, :second)

      {:ok, envelope} =
        Envelope.new("discord", "outbound_message", %{body: "yo"},
          trace_id: "custom",
          metadata: %{retries: 1},
          schema: "msgr.bridge.v2",
          occurred_at: occurred_at
        )

      assert envelope.schema == "msgr.bridge.v2"
      assert envelope.trace_id == "custom"
      assert envelope.metadata == %{retries: 1}
      assert envelope.occurred_at == DateTime.truncate(occurred_at, :millisecond)
    end

    test "rejects non map payloads" do
      assert {:error, {:invalid_payload, _}} = Envelope.new(:telegram, :send, :invalid)
    end

    test "rejects invalid metadata" do
      assert {:error, {:metadata, :not_a_map, _}} =
               Envelope.new(:telegram, :send, %{}, metadata: [:oops])
    end
  end

  describe "serialisation" do
    test "to_map/1 encodes occurred_at as ISO8601" do
      {:ok, envelope} = Envelope.new(:slack, :send, %{body: "hey"}, trace_id: "trace")

      map = Envelope.to_map(envelope)

      assert map.service == "slack"
      assert map.trace_id == "trace"
      assert {:ok, _datetime, 0} = DateTime.from_iso8601(map.occurred_at)
    end

    test "from_map/1 reconstructs the envelope" do
      occurred_at = DateTime.utc_now() |> DateTime.truncate(:millisecond)

      map = %{
        "schema" => "msgr.bridge.v1",
        "service" => "snapchat",
        "action" => "sync",
        "trace_id" => "trace",
        "occurred_at" => DateTime.to_iso8601(occurred_at),
        "metadata" => %{"env" => "test"},
        "payload" => %{"cursor" => "1"}
      }

      assert {:ok, envelope} = Envelope.from_map(map)
      assert envelope.service == "snapchat"
      assert envelope.metadata == %{"env" => "test"}
      assert envelope.payload == %{"cursor" => "1"}
      assert envelope.occurred_at == occurred_at
    end

    test "from_map/1 returns error for invalid occurred_at" do
      map = %{service: "telegram", action: "send", trace_id: "t", occurred_at: :not_a_datetime, payload: %{}}

      assert {:error, {:invalid_occurred_at, :not_a_datetime}} = Envelope.from_map(map)
    end
  end
end
