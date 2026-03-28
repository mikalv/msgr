defmodule Messngr.Apps.Executors.PollExecutorTest do
  use ExUnit.Case, async: true

  alias Messngr.Apps.Executors.PollExecutor

  describe "parse_poll_args/1" do
    test "parses quoted question and options" do
      args = ~s("What for lunch?" "Pizza" "Sushi" "Tacos")

      assert {:ok, "What for lunch?", ["Pizza", "Sushi", "Tacos"]} =
               PollExecutor.parse_poll_args(args)
    end

    test "parses two options" do
      args = ~s("Yes or no?" "Yes" "No")
      assert {:ok, "Yes or no?", ["Yes", "No"]} = PollExecutor.parse_poll_args(args)
    end

    test "returns error for nil args" do
      assert {:error, msg} = PollExecutor.parse_poll_args(nil)
      assert msg =~ "Bruk:"
    end

    test "returns error for empty string" do
      assert {:error, msg} = PollExecutor.parse_poll_args("")
      assert msg =~ "Bruk:"
    end

    test "returns error for single quoted option" do
      args = ~s("Question?" "Only one")
      assert {:error, msg} = PollExecutor.parse_poll_args(args)
      assert msg =~ "minst 2 alternativer"
    end

    test "falls back to whitespace splitting when only one quoted part" do
      # Single quoted string with insufficient words -> error
      args = ~s("Alone")
      assert {:error, _} = PollExecutor.parse_poll_args(args)
    end
  end

  describe "execute/2" do
    test "returns formatted poll message" do
      command = %{args: ~s("Favoritt?" "Eple" "Banan" "Appelsin")}
      assert {:ok, result} = PollExecutor.execute(command, %{})

      assert result.type == :message
      assert result.content =~ "Favoritt?"
      assert result.content =~ "1️⃣"
      assert result.content =~ "Eple"
      assert result.content =~ "2️⃣"
      assert result.content =~ "Banan"
      assert result.content =~ "3️⃣"
      assert result.content =~ "Appelsin"
      assert result.content =~ "Reager med emoji"
    end

    test "returns error for invalid input" do
      command = %{args: nil}
      assert {:error, _} = PollExecutor.execute(command, %{})
    end
  end
end
