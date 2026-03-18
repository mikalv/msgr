defmodule MessngrWeb.HealthController do
  use MessngrWeb, :controller
  require Logger

  @moduledoc """
  Health check endpoint for MessngrWeb.Endpoint.

  Returns JSON with:
  - Overall status (healthy/degraded/unhealthy)
  - Status of each backend endpoint (when running via EdgeRouter)
  - Request metadata
  """

  def health(conn, _params) do
    health_status = check_backends_health()

    conn
    |> put_status(health_status.status_code)
    |> json(health_status.body)
  end

  def metrics(conn, _params) do
    metrics = collect_metrics()

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, format_prometheus_metrics(metrics))
  end

  defp check_backends_health do
    # Check if MessngrWeb.Endpoint is running (it obviously is if we're here)
    backends = [
      %{
        type: "phoenix_endpoint",
        name: "MessngrWeb.Endpoint",
        status: :healthy
      }
    ]

    # If we're in a dev/test environment, include info about other endpoints
    if Application.get_env(:msgr_web, :dev_routes) do
      other_endpoints = [
        {AuthProvider.Endpoint, "AuthProvider.Endpoint"},
        {TeamsWeb.Endpoint, "TeamsWeb.Endpoint"}
      ]

      other_statuses =
        Enum.map(other_endpoints, fn {endpoint, name} ->
          status =
            case Process.whereis(endpoint) do
              nil -> :down
              pid when is_pid(pid) -> :healthy
            end

          %{
            type: "phoenix_endpoint",
            name: name,
            status: status
          }
        end)

      %{
        status_code: 200,
        body: %{
          status: :healthy,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          backends: backends ++ other_statuses
        }
      }
    else
      %{
        status_code: 200,
        body: %{
          status: :healthy,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          backends: backends
        }
      }
    end
  end

  defp collect_metrics do
    backends = [
      %{
        type: "phoenix_endpoint",
        name: "MessngrWeb.Endpoint",
        status: 1
      }
    ]

    %{
      backends: backends,
      timestamp: System.system_time(:second)
    }
  end

  defp format_prometheus_metrics(metrics) do
    lines = [
      "# HELP msgr_backend_up Whether a backend is up (1) or down (0)",
      "# TYPE msgr_backend_up gauge"
    ]

    backend_lines =
      Enum.map(metrics.backends, fn backend ->
        labels =
          format_labels(%{
            type: backend.type,
            name: backend.name
          })

        "msgr_backend_up{#{labels}} #{backend.status}"
      end)

    info_lines = [
      "",
      "# HELP msgr_info MessngrWeb information",
      "# TYPE msgr_info gauge",
      "msgr_info{version=\"1.0.0\"} 1"
    ]

    (lines ++ backend_lines ++ info_lines)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp format_labels(labels) do
    labels
    |> Enum.map(fn {key, value} ->
      ~s(#{key}="#{escape_label_value(value)}")
    end)
    |> Enum.join(",")
  end

  defp escape_label_value(value) do
    value
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end
end
