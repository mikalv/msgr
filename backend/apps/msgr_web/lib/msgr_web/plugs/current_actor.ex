defmodule MessngrWeb.Plugs.CurrentActor do
  @moduledoc """
  Backwards-compatible wrapper around `MessngrWeb.Plugs.NoiseSession` so existing
  pipelines keep working while Noise authentication is rolled out.
  """

  alias MessngrWeb.Plugs.NoiseSession

  @behaviour Plug

  @impl Plug
  def init(opts), do: NoiseSession.init(opts)

  @impl Plug
  def call(conn, opts), do: NoiseSession.call(conn, opts)
end
