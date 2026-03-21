defmodule Messngr.Apps.Executors.TopicExecutorTest do
  use ExUnit.Case, async: true

  alias Messngr.Apps.Executors.TopicExecutor

  describe "execute/2" do
    test "returns update_topic action with correct args" do
      command = %{args: "Ny viktig topic"}
      assert {:ok, result} = TopicExecutor.execute(command, %{})

      assert result.type == :update_topic
      assert result.topic == "Ny viktig topic"
      assert result.content =~ "Topic oppdatert"
      assert result.content =~ "Ny viktig topic"
    end

    test "trims whitespace from topic" do
      command = %{args: "  Trimmet topic  "}
      assert {:ok, result} = TopicExecutor.execute(command, %{})

      assert result.topic == "Trimmet topic"
    end

    test "returns error for nil args" do
      command = %{args: nil}
      assert {:error, msg} = TopicExecutor.execute(command, %{})
      assert msg =~ "Bruk:"
    end

    test "returns error for empty string" do
      command = %{args: ""}
      assert {:error, msg} = TopicExecutor.execute(command, %{})
      assert msg =~ "Bruk:"
    end

    test "returns error for whitespace-only args" do
      command = %{args: "   "}
      assert {:error, msg} = TopicExecutor.execute(command, %{})
      assert msg =~ "Bruk:"
    end
  end
end
