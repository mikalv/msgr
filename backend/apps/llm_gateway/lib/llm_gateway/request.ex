defmodule LlmGateway.Request do
  @moduledoc """
  Normalises request payloads before they are forwarded to providers.
  """

  alias LlmGateway.Telemetry

  @typedoc """
  Represents a chat message.
  """
  @type chat_message :: %{role: String.t(), content: String.t()}
  @type chat_messages :: [chat_message()]

  defstruct [:messages, :temperature, :max_tokens, :model, :response_format]

  @type t :: %__MODULE__{
          messages: chat_messages(),
          temperature: number() | nil,
          max_tokens: pos_integer() | nil,
          model: String.t() | nil,
          response_format: map() | nil
        }

  @required_message_keys ~w(role content)a
  @default_model "gpt-4o-mini"

  @spec build(chat_messages(), keyword()) :: {:ok, t()} | {:error, term()}
  def build(messages, opts \\ []) do
    Telemetry.emit(:request_build_started)

    with :ok <- validate_messages(messages) do
      request = %__MODULE__{
        messages: messages,
        temperature: opts[:temperature],
        max_tokens: opts[:max_tokens],
        model: opts[:model] || Application.get_env(:llm_gateway, :default_model, @default_model),
        response_format: opts[:response_format]
      }

      Telemetry.emit(:request_build_finished)
      {:ok, request}
    end
  end

  defp validate_messages(messages) when is_list(messages) and messages != [] do
    case Enum.find(messages, &missing_keys?/1) do
      nil -> :ok
      message -> {:error, {:invalid_message, message}}
    end
  end

  defp validate_messages(_), do: {:error, :messages_required}

  defp missing_keys?(message) when is_map(message) do
    Enum.any?(@required_message_keys, fn key ->
      value = Map.get(message, key) || Map.get(message, Atom.to_string(key))
      is_nil(value)
    end)
  end

  defp missing_keys?(_), do: true
end
