defmodule MainProxy.Plug.Metrics do
  @moduledoc """
  Metrics endpoint for EdgeRouter proxy.

  Provides Prometheus-compatible metrics about:
  - Request counts per backend
  - Backend health status
  - Request latency

  Access is controlled by IP allow-list, similar to the health endpoint.
  """
  @behaviour Plug

  import Plug.Conn
  require Logger

  @impl true
  def init(options) do
    options
  end

  @impl true
  def call(conn, _opts) do
    # Check if request is from allowed IP/network
    case check_access(conn) do
      {:ok, allowed} when allowed ->
        metrics = collect_metrics()

        conn
        |> put_resp_content_type("text/plain; version=0.0.4")
        |> send_resp(200, format_prometheus_metrics(metrics))

      {:ok, false} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          403,
          Jason.encode!(%{
            error: "Access denied",
            message: "Metrics endpoint is not accessible from your IP address"
          })
        )

      {:error, reason} ->
        Logger.error("Metrics access control error: #{inspect(reason)}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          500,
          Jason.encode!(%{
            error: "Internal server error"
          })
        )
    end
  end

  defp check_access(conn) do
    remote_ip = get_remote_ip(conn)

    # Allow from local networks and Docker networks by default
    allowed_networks = get_allowed_networks()

    allowed =
      Enum.any?(allowed_networks, fn network ->
        ip_in_network?(remote_ip, network)
      end)

    {:ok, allowed}
  rescue
    e -> {:error, e}
  end

  defp get_remote_ip(conn) do
    # Check X-Forwarded-For header first (from Rust Gateway)
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Fall back to direct connection IP
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end

  defp get_allowed_networks do
    # Default: allow localhost, private networks, and Docker networks
    default_networks = [
      # localhost
      "127.0.0.0/8",
      # Private network
      "10.0.0.0/8",
      # Private network (includes Docker default 172.17.0.0/16)
      "172.16.0.0/12",
      # Private network
      "192.168.0.0/16",
      # IPv6 localhost
      "::1/128",
      # IPv6 private
      "fc00::/7"
    ]

    # Allow override via environment variable
    case System.get_env("METRICS_ALLOWED_NETWORKS") do
      nil -> default_networks
      "" -> default_networks
      networks -> String.split(networks, ",") |> Enum.map(&String.trim/1)
    end
  end

  defp ip_in_network?(ip_str, network_str) do
    case {parse_ip(ip_str), parse_cidr(network_str)} do
      {{:ok, ip}, {:ok, {network, prefix_len}}} ->
        ip_bits = ip_to_bits(ip)
        network_bits = ip_to_bits(network)

        # Compare first prefix_len bits
        ip_prefix = binary_part(ip_bits, 0, div(prefix_len, 8))
        network_prefix = binary_part(network_bits, 0, div(prefix_len, 8))

        ip_prefix == network_prefix

      _ ->
        false
    end
  end

  defp parse_ip(ip_str) when is_binary(ip_str) do
    case :inet.parse_address(to_charlist(ip_str)) do
      {:ok, ip} -> {:ok, ip}
      {:error, _} -> {:error, :invalid_ip}
    end
  end

  defp parse_ip(ip_tuple) when is_tuple(ip_tuple), do: {:ok, ip_tuple}

  defp parse_cidr(cidr_str) do
    case String.split(cidr_str, "/") do
      [ip_str, prefix_str] ->
        with {:ok, ip} <- parse_ip(ip_str),
             {prefix_len, ""} <- Integer.parse(prefix_str) do
          {:ok, {ip, prefix_len}}
        else
          _ -> {:error, :invalid_cidr}
        end

      _ ->
        {:error, :invalid_cidr}
    end
  end

  defp ip_to_bits({a, b, c, d}), do: <<a, b, c, d>>

  defp ip_to_bits({a, b, c, d, e, f, g, h}),
    do: <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>

  defp collect_metrics do
    backends = EdgeRouter.MainProxy.backends()

    backend_metrics =
      Enum.map(backends, fn backend ->
        collect_backend_metrics(backend)
      end)

    %{
      backends: backend_metrics,
      timestamp: System.system_time(:second)
    }
  end

  defp collect_backend_metrics(%{phoenix_endpoint: endpoint} = backend)
       when not is_nil(endpoint) do
    status =
      case Process.whereis(endpoint) do
        # down
        nil -> 0
        # up
        pid when is_pid(pid) -> 1
      end

    %{
      type: "phoenix_endpoint",
      name: inspect(endpoint),
      domain: Map.get(backend, :domain, "unknown"),
      status: status
    }
  end

  defp collect_backend_metrics(%{plug: plug} = backend) when not is_nil(plug) do
    %{
      type: "plug",
      name: inspect(plug),
      path: inspect(Map.get(backend, :path, "unknown")),
      # plugs are always "up" if configured
      status: 1
    }
  end

  defp collect_backend_metrics(_backend) do
    %{
      type: "unknown",
      status: 0
    }
  end

  defp format_prometheus_metrics(metrics) do
    lines = [
      "# HELP edge_router_backend_up Whether a backend is up (1) or down (0)",
      "# TYPE edge_router_backend_up gauge"
    ]

    backend_lines =
      Enum.map(metrics.backends, fn backend ->
        labels =
          format_labels(%{
            type: backend.type,
            name: backend.name,
            domain: Map.get(backend, :domain, "unknown")
          })

        "edge_router_backend_up{#{labels}} #{backend.status}"
      end)

    info_lines = [
      "",
      "# HELP edge_router_info EdgeRouter information",
      "# TYPE edge_router_info gauge",
      "edge_router_info{version=\"1.0.0\"} 1"
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
