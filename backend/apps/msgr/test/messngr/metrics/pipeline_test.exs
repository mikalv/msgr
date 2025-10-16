defmodule Messngr.Metrics.PipelineTest do
  use Messngr.DataCase, async: false

  alias Messngr.Metrics.Pipeline

  defmodule Recorder do
    @moduledoc false

    use Agent

    def start_link(_opts) do
      Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    def record(metric, measurement, metadata) do
      Agent.update(__MODULE__, fn acc -> [%{metric: metric, measurement: measurement, metadata: metadata} | acc] end)
      :ok
    end

    def entries do
      Agent.get(__MODULE__, &Enum.reverse/1)
    end
  end

  setup do
    {:ok, _} = start_supervised(Recorder)
    {:ok, _} = start_supervised({Pipeline, reporter: &Recorder.record/3, name: nil})
    Agent.update(Recorder, fn _ -> [] end)
    :ok
  end

  test "emit_delivery_latency/2 forwards measurement" do
    Pipeline.emit_delivery_latency(120, %{conversation_id: "c1"})

    assert [%{metric: :delivery_latency, measurement: %{duration_ms: 120}}] = Recorder.entries()
  end

  test "emit_delivery_rate/3 calculates success rate" do
    Pipeline.emit_delivery_rate(8, 10, %{conversation_id: "c1"})

    assert [%{metric: :delivery_rate, measurement: %{success_rate: 0.8}}] = Recorder.entries()
  end

  test "emit_app_start/2 forwards measurement" do
    Pipeline.emit_app_start(1800, %{profile_id: "p1"})

    assert [%{metric: :app_start, measurement: %{duration_ms: 1800}}] = Recorder.entries()
  end

  test "emit_composer_render/2 forwards measurement" do
    Pipeline.emit_composer_render(95, %{profile_id: "p1"})

    assert [%{metric: :composer_render, measurement: %{duration_ms: 95}}] = Recorder.entries()
  end
end
