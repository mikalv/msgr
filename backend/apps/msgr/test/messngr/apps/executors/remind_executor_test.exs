defmodule Messngr.Apps.Executors.RemindExecutorTest do
  use ExUnit.Case, async: true

  alias Messngr.Apps.Executors.RemindExecutor

  describe "parse_remind_args/1" do
    test "parses minutes" do
      assert {:ok, "30 minutter", "Check deployment"} =
               RemindExecutor.parse_remind_args("30m Check deployment")
    end

    test "parses hours" do
      assert {:ok, "2 timer", "Team standup"} =
               RemindExecutor.parse_remind_args("2h Team standup")
    end

    test "parses seconds" do
      assert {:ok, "45 sekunder", "Ping"} = RemindExecutor.parse_remind_args("45s Ping")
    end

    test "parses days" do
      assert {:ok, "3 dager", "Release"} = RemindExecutor.parse_remind_args("3d Release")
    end

    test "singular forms" do
      assert {:ok, "1 minutt", "Test"} = RemindExecutor.parse_remind_args("1m Test")
      assert {:ok, "1 time", "Test"} = RemindExecutor.parse_remind_args("1h Test")
      assert {:ok, "1 sekund", "Test"} = RemindExecutor.parse_remind_args("1s Test")
      assert {:ok, "1 dag", "Test"} = RemindExecutor.parse_remind_args("1d Test")
    end

    test "returns error for nil" do
      assert {:error, msg} = RemindExecutor.parse_remind_args(nil)
      assert msg =~ "Bruk:"
    end

    test "returns error for empty string" do
      assert {:error, msg} = RemindExecutor.parse_remind_args("")
      assert msg =~ "Bruk:"
    end

    test "returns error for invalid time format" do
      assert {:error, msg} = RemindExecutor.parse_remind_args("abc Check things")
      assert msg =~ "Ugyldig tid"
    end

    test "returns error for missing message" do
      assert {:error, msg} = RemindExecutor.parse_remind_args("30m")
      assert msg =~ "Bruk:"
    end
  end

  describe "execute/2" do
    test "returns reminder confirmation message" do
      command = %{args: "30m Check deployment"}
      assert {:ok, result} = RemindExecutor.execute(command, %{})

      assert result.type == :message
      assert result.content =~ "Påminnelse satt"
      assert result.content =~ "Check deployment"
      assert result.content =~ "30 minutter"
    end

    test "returns error for invalid args" do
      command = %{args: nil}
      assert {:error, _} = RemindExecutor.execute(command, %{})
    end
  end
end
