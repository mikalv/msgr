defmodule SlackApi.SlackTimestamp do
  @moduledoc """
  Helpers for Slack-style timestamps that also allow reversible message lookups.
  """

  @doc """
  Encodes a timestamp, optionally embedding a UUID so the resulting string can
  be converted back to the originating record.
  """
  @spec encode(DateTime.t(), keyword()) :: String.t()
  def encode(%DateTime{} = datetime, opts \\ []) do
    seconds = DateTime.to_unix(datetime, :second)

    fractional =
      case Keyword.get(opts, :message_id) do
        nil ->
          datetime
          |> DateTime.to_unix(:microsecond)
          |> rem(1_000_000)
          |> Integer.to_string()
          |> String.pad_leading(6, "0")

        message_id when is_binary(message_id) ->
          message_id
          |> encode_uuid_fractional()
      end

    "#{seconds}.#{fractional}"
  end

  @doc """
  Extracts the UUID that was previously embedded in a timestamp string.
  """
  @spec decode_message_id(String.t()) :: {:ok, binary()} | :error
  def decode_message_id(ts) when is_binary(ts) do
    case String.split(ts, ".", parts: 2) do
      [_seconds, fractional] -> decode_uuid_fractional(fractional)
      _ -> :error
    end
  end

  def decode_message_id(_), do: :error

  defp encode_uuid_fractional(message_id) do
    case Ecto.UUID.dump(message_id) do
      {:ok, uuid_bin} ->
        uuid_bin
        |> :binary.decode_unsigned()
        |> Integer.to_string()

      :error ->
        raise ArgumentError, "invalid message id"
    end
  end

  defp decode_uuid_fractional(fractional) do
    with {int, ""} <- Integer.parse(fractional),
         binary <- :binary.encode_unsigned(int),
         padded <- pad_binary(binary, 16),
         {:ok, uuid} <- Ecto.UUID.load(padded) do
      {:ok, uuid}
    else
      _ -> :error
    end
  end

  defp pad_binary(binary, size) when byte_size(binary) < size do
    padding = size - byte_size(binary)
    :binary.copy(<<0>>, padding) <> binary
  end

  defp pad_binary(binary, _size), do: binary
end
