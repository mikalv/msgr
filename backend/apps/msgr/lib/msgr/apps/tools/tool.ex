defmodule Messngr.Apps.Tools.Tool do
  @moduledoc """
  Behaviour for LLM executor tools.

  Tools are server-side functions that LLM executor apps can invoke.
  Each tool must declare its name, description, parameters schema,
  and implement the execute callback.
  """

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parameters() :: map()
  @callback execute(args :: map(), context :: map()) :: {:ok, map()} | {:error, term()}
end
