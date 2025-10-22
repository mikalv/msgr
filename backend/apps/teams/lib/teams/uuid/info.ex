defmodule Teams.UUID.Info do
  @moduledoc """
  Lightweight UUID inspection used by `Teams.UUID`.
  """

  @enforce_keys [:uuid]
  defstruct [:uuid, :version, :variant]

  @type t :: %__MODULE__{
          uuid: String.t(),
          version: integer() | nil,
          variant: atom() | nil
        }

  @spec new(String.t()) :: {:ok, t()} | {:error, String.t()}
  def new(uuid) when is_binary(uuid) do
    with {:ok, normalized} <- cast_uuid(uuid) do
      {:ok,
       %__MODULE__{
         uuid: normalized,
         version: detect_version(normalized),
         variant: detect_variant(normalized)
       }}
    else
      :error -> {:error, "invalid UUID"}
    end
  end

  def new(_), do: {:error, "invalid UUID"}

  @spec new!(String.t()) :: t()
  def new!(uuid) do
    case new(uuid) do
      {:ok, info} -> info
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  defp cast_uuid(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, normalized} -> {:ok, normalized}
      :error -> :error
    end
  end

  defp detect_version(<<_::32, ?-, _::16, ?-, ver::4, _rest::bitstring>>) do
    ver
  end

  defp detect_version(_), do: nil

  defp detect_variant(<<_::36, ?-, _::3, variant::2, _rest::bitstring>>) do
    case variant do
      0b10 -> :rfc4122
      0b00 -> :reserved_ncs
      0b01 -> :reserved_microsoft
      0b11 -> :reserved_future
    end
  end

  defp detect_variant(_), do: nil
end
