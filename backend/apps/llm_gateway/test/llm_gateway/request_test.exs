defmodule LlmGateway.RequestTest do
  use ExUnit.Case, async: true

  alias LlmGateway.Request

  describe "build/2" do
    test "builds a request with defaults" do
      {:ok, request} = Request.build([%{role: "user", content: "hello"}])

      assert request.messages == [%{role: "user", content: "hello"}]
      assert request.max_tokens == nil
      assert request.temperature == nil
      assert is_binary(request.model)
    end

    test "validates messages" do
      assert {:error, :messages_required} = Request.build([])
      assert {:error, {:invalid_message, %{role: "user"}}} =
               Request.build([%{role: "user"}])
    end
  end
end
