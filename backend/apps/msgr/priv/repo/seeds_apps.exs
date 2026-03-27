# Seed first-party apps for the marketplace.
# Run with: mix run apps/msgr/priv/repo/seeds_apps.exs

alias Messngr.Apps

apps = [
  %{
    slug: "github",
    name: "GitHub",
    description: "Get notifications for PRs, issues, and deployments. Use /issue to create issues from chat.",
    category: "developer-tools",
    executor_type: "webhook",
    visibility: "public",
    featured: true,
    required_scopes: ["messages:write", "channels:read"],
    config_schema: %{
      "token" => %{"type" => "secret", "label" => "GitHub Personal Access Token", "required" => true},
      "repo" => %{"type" => "string", "label" => "Default repository (owner/name)", "placeholder" => "mikalv/relay"}
    },
    channel_config_schema: %{
      "repo" => %{"type" => "string", "label" => "Repository for this channel"},
      "notify_prs" => %{"type" => "boolean", "label" => "Notify on pull requests", "default" => true},
      "notify_issues" => %{"type" => "boolean", "label" => "Notify on issues", "default" => true},
      "notify_releases" => %{"type" => "boolean", "label" => "Notify on releases", "default" => false}
    }
  },
  %{
    slug: "calendar",
    name: "Calendar",
    description: "JMAP calendar integration. Get event reminders and manage schedules from chat.",
    category: "calendar",
    executor_type: "builtin",
    visibility: "public",
    featured: true,
    required_scopes: ["messages:write"],
    config_schema: %{
      "jmap_url" => %{"type" => "url", "label" => "JMAP Server URL", "required" => true},
      "jmap_token" => %{"type" => "secret", "label" => "JMAP Auth Token", "required" => true}
    },
    channel_config_schema: %{
      "calendar_id" => %{"type" => "string", "label" => "Calendar ID"},
      "remind_before" => %{"type" => "select", "label" => "Remind before event", "options" => ["5 min", "15 min", "30 min", "1 hour"], "default" => "15 min"}
    }
  },
  %{
    slug: "jira",
    name: "Jira",
    description: "Track Jira issues and get notifications on status changes. Create issues from chat.",
    category: "productivity",
    executor_type: "webhook",
    visibility: "public",
    featured: false,
    required_scopes: ["messages:write", "channels:read"],
    config_schema: %{
      "jira_url" => %{"type" => "url", "label" => "Jira Instance URL", "required" => true, "placeholder" => "https://yourteam.atlassian.net"},
      "api_token" => %{"type" => "secret", "label" => "Jira API Token", "required" => true},
      "email" => %{"type" => "string", "label" => "Jira Account Email", "required" => true}
    },
    channel_config_schema: %{
      "project_key" => %{"type" => "string", "label" => "Jira Project Key (e.g. PROJ)"},
      "notify_created" => %{"type" => "boolean", "label" => "Notify on issue created", "default" => true},
      "notify_status" => %{"type" => "boolean", "label" => "Notify on status change", "default" => true}
    }
  },
  %{
    slug: "rss",
    name: "RSS Feed",
    description: "Subscribe to RSS/Atom feeds and post new entries to a channel automatically.",
    category: "communication",
    executor_type: "builtin",
    visibility: "public",
    featured: false,
    required_scopes: ["messages:write"],
    config_schema: %{},
    channel_config_schema: %{
      "feed_url" => %{"type" => "url", "label" => "RSS/Atom Feed URL", "required" => true},
      "check_interval" => %{"type" => "select", "label" => "Check interval", "options" => ["5 min", "15 min", "1 hour", "6 hours"], "default" => "15 min"}
    }
  },
  %{
    slug: "sentry",
    name: "Sentry",
    description: "Get real-time error alerts from Sentry in your channels.",
    category: "developer-tools",
    executor_type: "webhook",
    visibility: "public",
    featured: true,
    required_scopes: ["messages:write"],
    config_schema: %{
      "dsn" => %{"type" => "string", "label" => "Sentry DSN or Organization Slug"}
    },
    channel_config_schema: %{
      "project" => %{"type" => "string", "label" => "Sentry Project Slug"},
      "min_level" => %{"type" => "select", "label" => "Minimum alert level", "options" => ["debug", "info", "warning", "error", "fatal"], "default" => "error"}
    }
  },
  %{
    slug: "grafana",
    name: "Grafana",
    description: "Receive Grafana alert notifications in your channels.",
    category: "developer-tools",
    executor_type: "webhook",
    visibility: "public",
    featured: false,
    required_scopes: ["messages:write"],
    config_schema: %{},
    channel_config_schema: %{
      "notify_resolved" => %{"type" => "boolean", "label" => "Notify when alerts resolve", "default" => true}
    }
  }
]

for app_attrs <- apps do
  case Apps.get_app_by_slug(app_attrs.slug) do
    nil ->
      {:ok, app} = Apps.create_app(app_attrs)
      IO.puts("Created app: #{app.name} (#{app.slug})")
    existing ->
      IO.puts("App already exists: #{existing.name} (#{existing.slug})")
  end
end
