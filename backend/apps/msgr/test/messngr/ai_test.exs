defmodule Messngr.AITest do
  use ExUnit.Case, async: true

  import Mox

  alias Messngr.AI

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "chat/3 normalises messages and coerces options" do
    expect(Messngr.AI.LlmClientMock, :chat_completion, fn "team", messages, opts ->
      assert messages == [%{role: "user", content: "hei"}]
      assert opts == [temperature: 0.4]
      {:ok, %{"choices" => []}}
    end)

    assert {:ok, %{"choices" => []}} =
             AI.chat("team", [%{"role" => "user", "content" => "hei"}],
               temperature: "0.4",
               ignored: :value
             )
  end

  test "chat/3 returns detailed error when a message is invalid" do
    assert {:error, {:invalid_message, %{index: 0, reason: :missing_content}}} =
             AI.chat("team", [%{role: "user"}])
  end

  test "summarize/3 builds default prompt" do
    expect(Messngr.AI.LlmClientMock, :chat_completion, fn "team", messages, _opts ->
      assert [%{role: "system", content: system}, %{role: "user", content: "Lang tekst"}] = messages
      assert String.contains?(system, "Norwegian Bokmål")
      {:ok, %{"choices" => []}}
    end)

    assert {:ok, %{"choices" => []}} = AI.summarize("team", "Lang tekst")
  end

  test "run_prompt/3 honours custom system prompt" do
    expect(Messngr.AI.LlmClientMock, :chat_completion, fn _team, messages, _opts ->
      assert [%{role: "system", content: "Custom"}, %{role: "user", content: "Skriv"}] = messages
      {:ok, %{"choices" => []}}
    end)

    assert {:ok, _} = AI.run_prompt("team", "Skriv", system_prompt: "Custom")
  end
end
