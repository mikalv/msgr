defmodule Messngr.Apps.Tools.Registry do
  @moduledoc """
  Registry for LLM executor tools.

  Maps tool names to their implementing modules. Tools are registered
  globally and referenced by name in LLM app manifests.
  """

  alias Messngr.Apps.Tools.GitHub

  @tools %{
    "github.create_issue" => GitHub.CreateIssue,
    "github.list_labels" => GitHub.ListLabels
  }

  @doc "Get a tool module by name. Returns nil if not found."
  def get_tool(name) when is_binary(name) do
    Map.get(@tools, name)
  end

  @doc "List all registered tool names."
  def list_tool_names do
    Map.keys(@tools)
  end

  @doc "List all registered tools as {name, module} pairs."
  def list_tools do
    Enum.map(@tools, fn {name, mod} ->
      %{
        name: name,
        description: mod.description(),
        parameters: mod.parameters()
      }
    end)
  end
end
