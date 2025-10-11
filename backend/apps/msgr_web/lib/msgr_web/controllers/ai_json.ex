defmodule MessngrWeb.AIJSON do
  @moduledoc """
  JSON views for AI related endpoints.
  """

  import Access, only: [at: 1]

  def chat(%{result: result}) do
    result
    |> metadata_payload()
    |> Map.put(:message, primary_message(result))
  end

  def summarize(%{result: result}) do
    result
    |> metadata_payload()
    |> Map.put(:summary, primary_message(result))
  end

  def run(%{result: result}) do
    result
    |> metadata_payload()
    |> Map.put(:message, primary_message(result))
  end

  def conversation_reply(%{result: result}) do
    result
    |> metadata_payload()
    |> Map.put(:reply, primary_message(result))
  end

  defp metadata_payload(result) do
    choices =
      result
      |> Map.get("choices", [])
      |> Enum.map(&format_choice/1)
      |> Enum.reject(&is_nil/1)

    %{
      id: result["id"],
      model: result["model"],
      created: result["created"],
      usage: result["usage"],
      choices: choices
    }
  end

  defp format_choice(choice) when is_map(choice) do
    %{
      index: choice["index"],
      finish_reason: choice["finish_reason"],
      message: format_message(choice["message"])
    }
  end

  defp format_choice(_), do: nil

  defp format_message(message) when is_map(message) do
    %{
      "role" => message["role"],
      "content" => message["content"]
    }
  end

  defp format_message(_), do: nil

  defp primary_message(result) do
    result
    |> get_in(["choices", at(0), "message", "content"])
  end
end
