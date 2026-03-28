defmodule Messngr.Apps.Tools.GitHub.CreateIssue do
  @moduledoc """
  LLM tool: Create a GitHub issue.

  Requires `github_token` in secrets and `repo` in channel config.
  """

  @behaviour Messngr.Apps.Tools.Tool

  require Logger

  @impl true
  def name, do: "github.create_issue"

  @impl true
  def description, do: "Create a GitHub issue"

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "title" => %{"type" => "string", "description" => "Issue title"},
        "body" => %{"type" => "string", "description" => "Issue body in markdown"},
        "labels" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Labels to apply"
        }
      },
      "required" => ["title", "body"]
    }
  end

  @impl true
  def execute(args, context) do
    repo = get_in(context, [:config, "repo"])
    token = get_in(context, [:secrets, "github_token"])

    unless repo do
      {:error, "Mangler repo-konfigurasjon for kanalen"}
    else
      unless token do
        {:error, "Mangler github_token i hemmeligheter"}
      else
        create_issue(repo, token, args)
      end
    end
  end

  defp create_issue(repo, token, args) do
    url = "https://api.github.com/repos/#{repo}/issues"

    body =
      %{
        "title" => args["title"],
        "body" => args["body"]
      }
      |> maybe_add_labels(args["labels"])

    headers = [
      {~c"Authorization", String.to_charlist("Bearer #{token}")},
      {~c"Content-Type", ~c"application/json"},
      {~c"Accept", ~c"application/vnd.github+json"},
      {~c"User-Agent", ~c"Msgr-App-Platform"}
    ]

    case :httpc.request(
           :post,
           {String.to_charlist(url), headers, ~c"application/json", Jason.encode!(body)},
           [{:timeout, 30_000}, {:connect_timeout, 10_000}],
           [{:body_format, :binary}]
         ) do
      {:ok, {{_, status, _}, _resp_headers, resp_body}} when status >= 200 and status < 300 ->
        case Jason.decode(resp_body) do
          {:ok, data} ->
            {:ok,
             %{
               "number" => data["number"],
               "url" => data["html_url"],
               "title" => data["title"],
               "state" => data["state"]
             }}

          {:error, _} ->
            {:error, "Kunne ikke parse GitHub-respons"}
        end

      {:ok, {{_, status, _}, _resp_headers, resp_body}} ->
        Logger.error("GitHub API returned #{status}: #{resp_body}")
        {:error, "GitHub API feil: #{status}"}

      {:error, reason} ->
        Logger.error("GitHub API request failed: #{inspect(reason)}")
        {:error, "Kunne ikke nå GitHub API"}
    end
  end

  defp maybe_add_labels(body, nil), do: body
  defp maybe_add_labels(body, []), do: body
  defp maybe_add_labels(body, labels) when is_list(labels), do: Map.put(body, "labels", labels)
end
