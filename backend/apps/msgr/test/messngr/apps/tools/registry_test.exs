defmodule Messngr.Apps.Tools.RegistryTest do
  use ExUnit.Case, async: true

  alias Messngr.Apps.Tools.Registry
  alias Messngr.Apps.Tools.GitHub

  describe "get_tool/1" do
    test "returns correct module for github.create_issue" do
      assert Registry.get_tool("github.create_issue") == GitHub.CreateIssue
    end

    test "returns correct module for github.list_labels" do
      assert Registry.get_tool("github.list_labels") == GitHub.ListLabels
    end

    test "returns nil for unknown tool" do
      assert Registry.get_tool("nonexistent.tool") == nil
    end

    test "returns nil for empty string" do
      assert Registry.get_tool("") == nil
    end
  end

  describe "list_tool_names/0" do
    test "returns all registered tool names" do
      names = Registry.list_tool_names()
      assert is_list(names)
      assert "github.create_issue" in names
      assert "github.list_labels" in names
    end
  end

  describe "list_tools/0" do
    test "returns all registered tools with metadata" do
      tools = Registry.list_tools()
      assert is_list(tools)
      assert length(tools) >= 2

      for tool <- tools do
        assert Map.has_key?(tool, :name)
        assert Map.has_key?(tool, :description)
        assert Map.has_key?(tool, :parameters)
        assert is_binary(tool.name)
        assert is_binary(tool.description)
        assert is_map(tool.parameters)
      end
    end
  end
end
