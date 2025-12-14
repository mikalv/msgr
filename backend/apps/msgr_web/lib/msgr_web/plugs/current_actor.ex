defmodule MessngrWeb.Plugs.CurrentActor do
  @moduledoc """
  Wrapper around `MessngrWeb.Plugs.SessionContext` for extracting session
  information from Rust Gateway headers.
  """

  alias MessngrWeb.Plugs.SessionContext

  @behaviour Plug

  @impl Plug
  def init(opts), do: SessionContext.init(opts)

  @impl Plug
  def call(conn, opts), do: SessionContext.call(conn, opts)
end
