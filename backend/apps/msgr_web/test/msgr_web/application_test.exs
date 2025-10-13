defmodule MessngrWeb.ApplicationTest do
  use ExUnit.Case, async: true

  alias MessngrWeb.Application, as: WebApp

  describe "prometheus_child_spec/1" do
    test "returns nil when disabled" do
      refute WebApp.prometheus_child_spec(enabled: false)
      refute WebApp.prometheus_child_spec(%{enabled: false})
    end

    test "builds telemetry exporter child spec when enabled" do
      assert {TelemetryMetricsPrometheus, options} =
               WebApp.prometheus_child_spec(enabled: true, port: 9_999, name: :custom_metrics)

      assert Keyword.fetch!(options, :port) == 9_999
      assert Keyword.fetch!(options, :name) == :custom_metrics
      assert Keyword.fetch!(options, :metrics) == MessngrWeb.Telemetry.metrics()
    end
  end
end
