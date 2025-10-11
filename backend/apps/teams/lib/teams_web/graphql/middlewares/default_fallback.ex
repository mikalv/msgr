defmodule TeamsWeb.GraphQL.Middlewares.DefaultFallback do

  @behaviour Absinthe.Middleware
  def call(resolution, _) do
    %{resolution | errors: Enum.flat_map(resolution.errors, &handle_error/1)}
  end

  defp handle_error(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {err, _opts} -> err end)
    |> Enum.map(fn {_k, v} -> inspect(v) end)
  end

  defp handle_error(error), do: [error]
end
