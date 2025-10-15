defmodule Messngr.Accounts.DeviceKey do
  @moduledoc """
  Utilities for normalising, validating, and fingerprinting device public keys.
  """

  @type encoded_key :: String.t()
  @type raw_key :: binary()

  @allowed_lengths [32, 64]

  @doc """
  Normalises a device key into a canonical, URL-safe base64 string without padding.

  The key may already be base64/base64url encoded or provided as a hex string. Any
  leading/trailing whitespace is ignored. Returns the normalised key alongside the
  raw decoded bytes when successful.
  """
  @spec normalize(term()) :: {:ok, encoded_key(), raw_key()} | {:error, atom()}
  def normalize(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> {:error, :empty}
      trimmed ->
        with {:error, _} <- decode_base64url(trimmed),
             {:error, _} <- decode_base64(trimmed),
             {:error, _} <- decode_hex(trimmed) do
          {:error, :invalid_format}
        else
          {:ok, raw} -> build_result(raw)
        end
    end
  end

  def normalize(_), do: {:error, :invalid_format}

  @doc """
  Computes a stable SHA-256 fingerprint for the given raw key bytes.
  """
  @spec fingerprint(raw_key()) :: String.t()
  def fingerprint(raw) when is_binary(raw) do
    :crypto.hash(:sha256, raw)
    |> Base.encode16(case: :lower)
  end

  def fingerprint(_), do: raise(ArgumentError, "device key fingerprint expects binary input")

  defp decode_base64url(value) do
    case Base.url_decode64(value, padding: false) do
      {:ok, raw} -> {:ok, raw}
      :error ->
        case Base.url_decode64(value, padding: true) do
          {:ok, raw} -> {:ok, raw}
          :error -> {:error, :invalid_base64url}
        end
    end
  end

  defp decode_base64(value) do
    case Base.decode64(value, padding: false) do
      {:ok, raw} -> {:ok, raw}
      :error ->
        case Base.decode64(value) do
          {:ok, raw} -> {:ok, raw}
          :error -> {:error, :invalid_base64}
        end
    end
  end

  defp decode_hex(value) do
    hex = String.downcase(value)
    size = byte_size(hex)

    cond do
      rem(size, 2) != 0 -> {:error, :invalid_hex}
      size < 64 or size > 128 -> {:error, :invalid_hex}
      true ->
        try do
          {:ok, Base.decode16!(hex, case: :lower)}
        rescue
          ArgumentError -> {:error, :invalid_hex}
        end
    end
  end

  defp build_result(raw) when byte_size(raw) in @allowed_lengths do
    encoded = Base.url_encode64(raw, padding: false)
    {:ok, encoded, raw}
  end

  defp build_result(_raw), do: {:error, :invalid_length}
end
