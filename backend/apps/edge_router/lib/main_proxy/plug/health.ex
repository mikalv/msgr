defmodule MainProxy.Plug.Health do
  @moduledoc """
  Health check endpoint that reports status of all registered backends.

  Returns JSON with:
  - Overall status (healthy/degraded/unhealthy)
  - Status of each backend endpoint
  - Request metadata
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
        health_status = check_backends_health()

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(health_status.status_code, Jason.encode!(health_status.body))

      {:ok, false} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{
          error: "Access denied",
          message: "Health endpoint is not accessible from your IP address"
        }))

      {:error, reason} ->
        Logger.error("Health check access control error: #{inspect(reason)}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{
          error: "Internal server error"
        }))
    end
  end

  defp check_access(conn) do
    remote_ip = get_remote_ip(conn)

    # Allow from local networks and Docker networks by default
    # Can be configured via environment variables
    allowed_networks = get_allowed_networks()

    allowed = Enum.any?(allowed_networks, fn network ->
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
      "127.0.0.0/8",      # localhost
      "10.0.0.0/8",       # Private network
      "172.16.0.0/12",    # Private network (includes Docker default 172.17.0.0/16)
      "192.168.0.0/16",   # Private network
      "::1/128",          # IPv6 localhost
      "fc00::/7"          # IPv6 private
    ]

    # Allow override via environment variable
    case System.get_env("HEALTH_ALLOWED_NETWORKS") do
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
  defp ip_to_bits({a, b, c, d, e, f, g, h}), do: <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>

  defp check_backends_health do
    backends = EdgeRouter.MainProxy.backends()

    backend_statuses = Enum.map(backends, fn backend ->
      check_backend_health(backend)
    end)

    overall_status = calculate_overall_status(backend_statuses)

    %{
      status_code: if(overall_status == :healthy, do: 200, else: 503),
      body: %{
        status: overall_status,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        backends: backend_statuses
      }
    }
  end

  defp check_backend_health(%{phoenix_endpoint: endpoint} = backend) when not is_nil(endpoint) do
    # Check if the Phoenix endpoint is running
    status = case Process.whereis(endpoint) do
      nil -> :down
      pid when is_pid(pid) -> :healthy
    end

    %{
      type: "phoenix_endpoint",
      name: inspect(endpoint),
      domain: Map.get(backend, :domain, "N/A"),
      status: status
    }
  end

  defp check_backend_health(%{plug: plug} = backend) when not is_nil(plug) do
    # Plug-based backends are always healthy if they're configured
    %{
      type: "plug",
      name: inspect(plug),
      path: inspect(Map.get(backend, :path, "N/A")),
      status: :healthy
    }
  end

  defp check_backend_health(backend) do
    %{
      type: "unknown",
      config: inspect(backend),
      status: :unknown
    }
  end

  defp calculate_overall_status(backend_statuses) do
    statuses = Enum.map(backend_statuses, & &1.status)

    cond do
      Enum.all?(statuses, &(&1 == :healthy)) -> :healthy
      Enum.any?(statuses, &(&1 == :down)) -> :unhealthy
      true -> :degraded
    end
  end
end
