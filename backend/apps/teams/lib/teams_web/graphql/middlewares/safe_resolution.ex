defmodule TeamsWeb.GraphQL.Middleware.SafeResolution do
  alias Absinthe.Resolution
  import TeamsWeb.Gettext
  require Logger

  @behaviour Absinthe.Middleware

  @spec apply(list()) :: list()
  def apply(middleware) when is_list(middleware) do
    Enum.map(middleware, fn
      {{Resolution, :call}, resolver} -> {__MODULE__, resolver}
      other -> other
    end)
  end

  @impl true
  def call(resolution, resolver) do
    Resolution.call(resolution, resolver)
  rescue
    exception ->
      message = {:error, dgettext("errors", "Server Issue. Please come back later.")}

      error = Exception.format(:error, exception, __STACKTRACE__)
      if error, do: Logger.error(error)
      Resolution.put_result(resolution, message)
  end
end
