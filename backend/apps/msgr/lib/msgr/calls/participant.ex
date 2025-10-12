defmodule Messngr.Calls.Participant do
  @moduledoc """
  Represents a participant in an active WebRTC call.
  """

  @enforce_keys [:profile_id, :role, :status]
  defstruct [:profile_id, :role, :status, metadata: %{}]

  @type t :: %__MODULE__{
          profile_id: String.t(),
          role: :host | :participant,
          status: :connecting | :connected,
          metadata: map()
        }

  @spec new(keyword() | map()) :: t()
  def new(%__MODULE__{} = participant), do: participant

  def new(%{} = attrs) do
    attrs
    |> Map.to_list()
    |> new()
  end

  def new(opts) when is_list(opts) do
    profile_id = Keyword.fetch!(opts, :profile_id)

    opts
    |> Keyword.put_new(:role, :participant)
    |> Keyword.put_new(:status, :connecting)
    |> new(profile_id)
  end

  @spec new(String.t(), keyword()) :: t()
  def new(profile_id, opts) when is_binary(profile_id) and is_list(opts) do
    metadata = opts |> Keyword.get(:metadata, %{}) |> normalise_metadata()

    %__MODULE__{
      profile_id: profile_id,
      role: Keyword.fetch!(opts, :role),
      status: Keyword.fetch!(opts, :status),
      metadata: metadata
    }
  end

  def host(profile_id) when is_binary(profile_id) do
    %__MODULE__{profile_id: profile_id, role: :host, status: :connected, metadata: %{"kind" => "host"}}
  end

  def connect(%__MODULE__{} = participant) do
    %__MODULE__{participant | status: :connected}
  end

  defp normalise_metadata(nil), do: %{}
  defp normalise_metadata(metadata) when is_map(metadata), do: metadata
  defp normalise_metadata(_), do: %{}
end
