defmodule Messngr.Apps.Tools.GitHub.ListLabels do
  @moduledoc """
  LLM tool: List labels on a GitHub repository.

  Requires `github_token` in secrets and `repo` in channel config.
  """

  @behaviour Messngr.Apps.Tools.Tool

  require Logger

  @impl true
  def name, do: "github.list_labels"

  @impl true
  def description, do: "List available labels on a GitHub repository"

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{},
      "required" => []
    }
  end

  @impl true
  def execute(_args, context) do
    repo = get_in(context, [:config, "repo"])
    token = get_in(context, [:secrets, "github_token"])

    unless repo do
      {:error, "Mangler repo-konfigurasjon for kanalen"}
    else
      unless token do
        {:error, "Mangler github_token i hemmeligheter"}
      else
        list_labels(repo, token)
      end
    end
  end

  defp list_labels(repo, token) do
    url = "https://api.github.com/repos/#{repo}/labels?per_page=100"

    headers = [
      {~c"Authorization", String.to_charlist("Bearer #{token}")},
      {~c"Accept", ~c"application/vnd.github+json"},
      {~c"User-Agent", ~c"Msgr-App-Platform"}
    ]

    case :httpc.request(
           :get,
           {String.to_charlist(url), headers},
           [{:timeout, 15_000}, {:connect_timeout, 10_000}],
           [{:body_format, :binary}]
         ) do
      {:ok, {{_, status, _}, _resp_headers, resp_body}} when status >= 200 and status < 300 ->
        case Jason.decode(resp_body) do
          {:ok, labels} when is_list(labels) ->
            {:ok, %{
              "labels" => Enum.map(labels, fn l ->
                %{
                  "name" => l["name"],
                  "description" => l["description"],
                  "color" => l["color"]
                }
              end)
            }}

          _ ->
            {:error, "Kunne ikke parse GitHub label-respons"}
        end

      {:ok, {{_, status, _}, _resp_headers, resp_body}} ->
        Logger.error("GitHub API returned #{status}: #{resp_body}")
        {:error, "GitHub API feil: #{status}"}

      {:error, reason} ->
        Logger.error("GitHub API request failed: #{inspect(reason)}")
        {:error, "Kunne ikke nå GitHub API"}
    end
  end
end
