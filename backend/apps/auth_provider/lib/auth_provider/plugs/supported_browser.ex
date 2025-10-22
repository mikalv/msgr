defmodule AuthProvider.Plug.SupportedBrowser do
  @moduledoc """
  Only allow access with supported browsers
  """

  @support_browsers ~w(Chrome Firefox Safari iPhone iPad Edge Android)

  def init(options), do: options

  def call(conn, _opts) do
    if browser_supported?(conn) do
      conn
    else
      conn
      |> Phoenix.Controller.put_view(EyrWeb.PageView)
      |> Phoenix.Controller.put_layout({EyrWeb.LayoutView, "app.html"})
      |> Phoenix.Controller.render("browser.html")
      |> Plug.Conn.halt()
    end
  end

  defp browser_supported?(conn) do
    case browser_name(conn) do
      nil -> true
      name -> name in @support_browsers
    end
  end

  defp browser_name(conn) do
    if Code.ensure_loaded?(Browser) and function_exported?(Browser, :name, 1) do
      apply(Browser, :name, [conn])
    else
      nil
    end
  end
end
