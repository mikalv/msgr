defmodule Messngr.Media.VirusScan.Clamd do
  @moduledoc """
  Minimal clamd TCP client using the INSTREAM protocol.
  """

  @behaviour Messngr.Media.VirusScan.Scanner

  @default_chunk 65_536
  @recv_timeout 60_000

  @impl true
  def scan_bytes(data, opts \\ []) when is_binary(data) do
    host = Keyword.get(opts, :host) || config(:host, "127.0.0.1")
    port = Keyword.get(opts, :port) || config(:port, 3310)
    timeout = Keyword.get(opts, :timeout, @recv_timeout)

    case :gen_tcp.connect(host_charlist(host), port, [:binary, active: false], timeout) do
      {:ok, socket} ->
        try do
          with :ok <- :gen_tcp.send(socket, "zINSTREAM\0"),
               :ok <- stream_chunks(socket, data),
               :ok <- :gen_tcp.send(socket, <<0::32>>),
               {:ok, response} <- :gen_tcp.recv(socket, 0, timeout) do
            parse_response(response)
          end
        after
          :gen_tcp.close(socket)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stream_chunks(_socket, <<>>), do: :ok

  defp stream_chunks(socket, data) do
    size = byte_size(data)
    chunk_size = min(@default_chunk, size)
    <<chunk::binary-size(chunk_size), rest::binary>> = data
    packet = <<chunk_size::32, chunk::binary>>

    case :gen_tcp.send(socket, packet) do
      :ok -> stream_chunks(socket, rest)
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_response(response) when is_binary(response) do
    trimmed = response |> to_string() |> String.trim()

    cond do
      String.contains?(trimmed, "OK") and not String.contains?(trimmed, "FOUND") ->
        :clean

      String.contains?(trimmed, "FOUND") ->
        threat =
          trimmed
          |> String.replace(~r/^stream:\s*/i, "")
          |> String.replace(~r/\s+FOUND$/i, "")
          |> String.trim()

        {:infected, threat}

      true ->
        {:error, {:unexpected_response, trimmed}}
    end
  end

  defp host_charlist(host) when is_binary(host), do: String.to_charlist(host)
  defp host_charlist(host) when is_list(host), do: host
  defp host_charlist(host), do: host |> to_string() |> String.to_charlist()

  defp config(key, default) do
    Application.get_env(:msgr, Messngr.Media.VirusScan, [])
    |> Keyword.get(key, default)
  end
end
