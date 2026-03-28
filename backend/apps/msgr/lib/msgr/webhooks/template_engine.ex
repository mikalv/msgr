defmodule Messngr.Webhooks.TemplateEngine do
  @moduledoc """
  Renders webhook payloads into readable messages using Liquid templates.

  Supports:
  - Custom templates (user-defined Liquid)
  - Built-in presets for common services (GitHub, Sentry, Grafana, etc.)
  - Fallback to extracting text/content from payload
  """

  require Logger

  @presets %{
    "github" => """
    {% if action %}**{{ action | capitalize }}**{% endif %} \
    {% if pull_request %}PR: **{{ pull_request.title }}** by {{ pull_request.user.login }}
    {{ pull_request.html_url }}{% endif %}\
    {% if issue %}Issue: **{{ issue.title }}** by {{ issue.user.login }}
    {{ issue.html_url }}{% endif %}\
    {% if commits %}{{ pusher.name }} pushed {{ commits.size }} commit(s) to `{{ ref }}`
    {% for c in commits %}- {{ c.message | truncate: 80 }}
    {% endfor %}{% endif %}\
    {% if release %}Release **{{ release.tag_name }}**: {{ release.name }}
    {{ release.html_url }}{% endif %}\
    {% unless pull_request %}{% unless issue %}{% unless commits %}{% unless release %}\
    {{ action | default: "Event" }}: {{ sender.login | default: "unknown" }}{% endunless %}{% endunless %}{% endunless %}{% endunless %}
    """,
    "sentry" => """
    🚨 **{{ event.title | default: data.event.title | default: "Error" }}**
    Project: {{ project_name | default: data.project_name | default: "unknown" }}
    Level: {{ level | default: data.level | default: "error" }}
    {% if url %}{{ url }}{% endif %}{% if data.url %}{{ data.url }}{% endif %}
    """,
    "grafana" => """
    {% if state %}**Alert {{ state }}**: {{ ruleName | default: title }}{% endif %}
    {% if message %}{{ message }}{% endif %}
    {% if evalMatches %}{% for m in evalMatches %}- {{ m.metric }}: {{ m.value }}
    {% endfor %}{% endif %}
    """,
    "gitlab" => """
    {% if object_kind == "merge_request" %}**{{ object_attributes.action | capitalize }}** MR: **{{ object_attributes.title }}** by {{ user.name }}
    {{ object_attributes.url }}{% endif %}\
    {% if object_kind == "pipeline" %}Pipeline **{{ object_attributes.status }}** for `{{ object_attributes.ref }}`
    {{ project.web_url }}/pipelines/{{ object_attributes.id }}{% endif %}\
    {% if object_kind == "push" %}{{ user_name }} pushed {{ total_commits_count }} commit(s) to `{{ ref }}`
    {% for c in commits %}- {{ c.message | truncate: 80 }}
    {% endfor %}{% endif %}
    """,
    "generic" => """
    {{ text | default: message | default: content | default: body | default: description | default: "Webhook received" }}
    """
  }

  @doc "List available preset names."
  def preset_names, do: Map.keys(@presets)

  @doc "Get a preset template by name."
  def get_preset(name), do: Map.get(@presets, name)

  @doc """
  Render a webhook payload using the given template or preset.

  Returns `{:ok, rendered_text}` or `{:error, reason}`.
  """
  def render(payload, template, preset) when is_map(payload) do
    template_source =
      cond do
        is_binary(template) and template != "" -> template
        is_binary(preset) and preset != "" -> Map.get(@presets, preset, @presets["generic"])
        true -> nil
      end

    if template_source do
      render_liquid(template_source, payload)
    else
      # No template — use default extraction
      {:ok, extract_default(payload)}
    end
  end

  defp render_liquid(template_source, payload) do
    try do
      with {:ok, template} <- Solid.parse(template_source),
           {:ok, rendered} <- Solid.render(template, payload) do
        text =
          rendered
          |> IO.iodata_to_binary()
          |> String.trim()
          |> String.replace(~r/\n{3,}/, "\n\n")

        if text == "" do
          {:ok, extract_default(payload)}
        else
          {:ok, text}
        end
      else
        {:error, reason} ->
          Logger.warning("[WebhookTemplate] Render failed: #{inspect(reason)}")
          {:ok, extract_default(payload)}
      end
    rescue
      e ->
        Logger.warning("[WebhookTemplate] Exception: #{inspect(e)}")
        {:ok, extract_default(payload)}
    end
  end

  defp extract_default(payload) do
    payload["text"] ||
      payload["content"] ||
      payload["message"] ||
      payload["body"] ||
      payload["description"] ||
      Jason.encode!(payload) |> String.slice(0, 500)
  end
end
