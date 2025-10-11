defmodule AuthProvider.Plug.SupportedBrowser do
  @moduledoc """
  Only allow access with supported browsers
  """

  @support_browsers ~w(Chrome Firefox Safari iPhone iPad Edge Android)

  def init(options), do: options

  def call(conn, _opts) do
    if Browser.name(conn) in @support_browsers do
      conn
    else
      conn
      |> Phoenix.Controller.put_view(EyrWeb.PageView)
      |> Phoenix.Controller.put_layout({EyrWeb.LayoutView, "app.html"})
      |> Phoenix.Controller.render("browser.html")
      |> Plug.Conn.halt()
    end
  end
end
