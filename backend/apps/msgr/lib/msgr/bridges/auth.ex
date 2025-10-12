defmodule Messngr.Bridges.Auth do
  @moduledoc """
  Manages the catalog of bridge connectors and the lifecycle of bridge
  authentication sessions. The catalog is intentionally static for now, giving
  the client enough metadata to render discovery UI without hardcoding service
  details.
  """

  alias Messngr.Accounts.Account
  alias Messngr.Bridges.AuthSession
  alias Messngr.Repo

  defmodule CatalogEntry do
    @moduledoc """
    Helper struct that describes metadata for a bridge connector exposed in the
    catalog endpoint.
    """

    @enforce_keys [:id, :service, :display_name, :description, :auth, :capabilities, :status]
    defstruct [:id, :service, :display_name, :description, :auth, :capabilities, :status, :categories, :prerequisites, :tags]

    @type status :: :available | :coming_soon

    @type t :: %__MODULE__{
            id: String.t(),
            service: String.t(),
            display_name: String.t(),
            description: String.t(),
            auth: map(),
            capabilities: map(),
            status: status(),
            categories: [String.t()] | nil,
            prerequisites: [String.t()] | nil,
            tags: [String.t()] | nil
          }

    @doc false
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = entry) do
      entry
      |> Map.from_struct()
      |> Map.update(:auth, %{}, &deep_map/1)
      |> Map.update(:capabilities, %{}, &deep_map/1)
      |> Map.update(:categories, [], &List.wrap/1)
      |> Map.update(:prerequisites, [], &List.wrap/1)
      |> Map.update(:tags, [], &List.wrap/1)
    end

    defp deep_map(value) when is_map(value) do
      value
      |> Enum.map(fn {key, val} -> {key, deep_map(val)} end)
      |> Map.new()
    end

    defp deep_map(value) when is_list(value), do: Enum.map(value, &deep_map/1)
    defp deep_map(value), do: value

    @doc false
    def telegram do
      %__MODULE__{
        id: "telegram",
        service: "telegram",
        display_name: "Telegram",
        description: "Sync private chats, supergroups, and channels from Telegram into Msgr.",
        status: :available,
        categories: ["consumer"],
        prerequisites: ["Telegram account", "Msgr desktop or mobile client"],
        tags: ["oauth", "pkce"],
        auth: %{
          method: "oauth",
          auth_surface: "embedded_browser",
          oauth: %{
            scopes: ["basic", "messages.read", "messages.write"],
            pkce: true
          }
        },
        capabilities: %{
          messaging: %{
            directions: ["inbound", "outbound"],
            media: ["text", "image", "file"],
            reactions: true
          },
          presence: true
        }
      }
    end

    @doc false
    def signal do
      %__MODULE__{
        id: "signal",
        service: "signal",
        display_name: "Signal",
        description: "Link your Signal device to Msgr and relay encrypted conversations securely.",
        status: :available,
        categories: ["consumer"],
        prerequisites: ["Existing Signal device"],
        tags: ["device_link"],
        auth: %{
          method: "device_link",
          auth_surface: "external_device",
          polling: %{
            interval_ms: 3_000,
            timeout_ms: 180_000
          }
        },
        capabilities: %{
          messaging: %{
            directions: ["inbound", "outbound"],
            media: ["text", "image", "voice"],
            reactions: false
          }
        }
      }
    end

    @doc false
    def matrix do
      %__MODULE__{
        id: "matrix",
        service: "matrix",
        display_name: "Matrix",
        description: "Bridge Matrix rooms with Msgr spaces and maintain member parity.",
        status: :available,
        categories: ["federated"],
        prerequisites: ["Matrix homeserver credentials"],
        tags: ["password"],
        auth: %{
          method: "password",
          auth_surface: "native_form",
          form: %{
            fields: [
              %{name: "username", type: "text", label: "Username"},
              %{name: "password", type: "password", label: "Password"},
              %{name: "homeserver", type: "text", label: "Homeserver", optional: true}
            ]
          }
        },
        capabilities: %{
          messaging: %{
            directions: ["inbound", "outbound"],
            media: ["text", "image", "file"],
            edits: true
          },
          threads: true
        }
      }
    end

    @doc false
    def irc do
      %__MODULE__{
        id: "irc",
        service: "irc",
        display_name: "IRC",
        description: "Pipe classic IRC networks into Msgr with optional bouncer support.",
        status: :available,
        categories: ["legacy"],
        prerequisites: ["Server hostname", "Nickname"],
        tags: ["password", "sasl"],
        auth: %{
          method: "password",
          auth_surface: "native_form",
          form: %{
            fields: [
              %{name: "nickname", type: "text", label: "Nickname"},
              %{name: "password", type: "password", label: "Server password", optional: true},
              %{name: "server", type: "text", label: "Server"},
              %{name: "port", type: "number", label: "Port", optional: true}
            ]
          }
        },
        capabilities: %{
          messaging: %{
            directions: ["inbound", "outbound"],
            media: ["text"],
            reactions: false
          }
        }
      }
    end

    @doc false
    def slack_preview do
      %__MODULE__{
        id: "slack",
        service: "slack",
        display_name: "Slack (preview)",
        description: "Preview connector for Slack workspaces focusing on channel mirroring.",
        status: :coming_soon,
        categories: ["work"],
        prerequisites: ["Slack workspace admin consent"],
        tags: ["oauth"],
        auth: %{
          method: "oauth",
          auth_surface: "embedded_browser",
          oauth: %{
            scopes: ["channels:read", "channels:history", "chat:write"],
            pkce: true
          }
        },
        capabilities: %{
          messaging: %{
            directions: ["inbound", "outbound"],
            media: ["text", "file"],
            threads: true
          }
        }
      }
    end
  end

  alias __MODULE__.CatalogEntry

  @catalog [
    CatalogEntry.telegram(),
    CatalogEntry.signal(),
    CatalogEntry.matrix(),
    CatalogEntry.irc(),
    CatalogEntry.slack_preview()
  ]

  @catalog_lookup Map.new(@catalog, &{&1.id, &1})

  @type catalog_filter_opts :: [status: CatalogEntry.status()]

  @doc """
  Lists connectors that can be displayed in the client bridge catalog. The list
  is currently static but modelled as structs so future persistence or remote
  configuration can reuse the same API.
  """
  @spec list_catalog(catalog_filter_opts()) :: [CatalogEntry.t()]
  def list_catalog(opts \\ []) do
    case Keyword.get(opts, :status) do
      nil -> @catalog
      status -> Enum.filter(@catalog, &(&1.status == status))
    end
  end

  @doc """
  Fetches a catalog entry by identifier.
  """
  @spec fetch_catalog_entry(String.t()) :: {:ok, CatalogEntry.t()} | {:error, :unknown_connector}
  def fetch_catalog_entry(id) when is_binary(id) do
    case Map.fetch(@catalog_lookup, id) do
      {:ok, %CatalogEntry{} = entry} -> {:ok, entry}
      :error -> {:error, :unknown_connector}
    end
  end

  def fetch_catalog_entry(_id), do: {:error, :unknown_connector}

  @doc """
  Starts a new authentication session for the supplied account and connector.
  Metadata from the catalog is snapshotted onto the session so backend workers
  can complete the login flow even if the catalog changes later.
  """
  @spec start_session(Account.t() | Ecto.UUID.t(), String.t(), map()) ::
          {:ok, AuthSession.t()} | {:error, term()}
  def start_session(%Account{id: account_id}, connector_id, attrs \\ %{}) do
    start_session(account_id, connector_id, attrs)
  end

  def start_session(account_id, connector_id, attrs) when is_binary(account_id) do
    with {:ok, entry} <- fetch_catalog_entry(connector_id) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      session_attrs = %{
        account_id: account_id,
        service: entry.service,
        state: "awaiting_user",
        login_method: entry.auth[:method],
        auth_surface: entry.auth[:auth_surface],
        client_context: ensure_map(Map.get(attrs, :client_context) || Map.get(attrs, "client_context")),
        metadata: build_metadata(entry, attrs),
        catalog_snapshot: CatalogEntry.to_map(entry),
        expires_at: normalise_expires_at(attrs, now),
        last_transition_at: now
      }

      %AuthSession{}
      |> AuthSession.creation_changeset(session_attrs)
      |> Repo.insert()
    end
  end

  def start_session(_account_id, _connector_id, _attrs), do: {:error, :invalid_account}

  @doc """
  Retrieves a session ensuring it belongs to the provided account.
  """
  @spec fetch_session(Account.t() | Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, AuthSession.t()} | {:error, term()}
  def fetch_session(%Account{id: account_id}, session_id), do: fetch_session(account_id, session_id)

  def fetch_session(account_id, session_id) when is_binary(account_id) and is_binary(session_id) do
    case Repo.get(AuthSession, session_id) do
      %AuthSession{account_id: ^account_id} = session -> {:ok, session}
      %AuthSession{} -> {:error, :forbidden}
      nil -> {:error, :not_found}
    end
  end

  def fetch_session(_account_id, _session_id), do: {:error, :not_found}

  @doc """
  Returns the path that the client should open inside an embedded browser to
  begin the OAuth/OIDC redirect. The path is relative so different clients can
  apply their own base URL.
  """
  @spec session_authorization_path(AuthSession.t()) :: String.t()
  def session_authorization_path(%AuthSession{id: id}), do: "/auth/bridge/#{id}/start"

  @doc """
  Path for OIDC callbacks. Exposed so tests and the future wizard implementation
  can use the same routing helper without depending on Phoenix route helpers.
  """
  @spec session_callback_path(AuthSession.t()) :: String.t()
  def session_callback_path(%AuthSession{id: id}), do: "/auth/bridge/#{id}/callback"

  defp build_metadata(%CatalogEntry{} = entry, attrs) do
    base_metadata = ensure_map(Map.get(attrs, :metadata) || Map.get(attrs, "metadata"))

    scopes =
      entry.auth
      |> Map.get(:oauth, %{})
      |> Map.get(:scopes, [])
      |> List.wrap()
      |> Enum.reject(&is_nil/1)

    poll = Map.get(entry.auth, :polling)

    entry_metadata = %{}
    entry_metadata = if scopes == [], do: entry_metadata, else: Map.put(entry_metadata, "scopes", scopes)
    entry_metadata = if is_nil(poll), do: entry_metadata, else: Map.put(entry_metadata, "poll", poll)

    Map.merge(entry_metadata, base_metadata)
  end

  defp normalise_expires_at(attrs, now) do
    attrs
    |> Map.get(:expires_at)
    |> Kernel.||(Map.get(attrs, "expires_at"))
    |> case do
      nil -> DateTime.add(now, default_session_ttl_seconds(), :second)
      %DateTime{} = dt -> DateTime.truncate(dt, :second)
      value when is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, dt, _offset} -> DateTime.truncate(dt, :second)
          {:error, _} -> DateTime.add(now, default_session_ttl_seconds(), :second)
        end
      _ -> DateTime.add(now, default_session_ttl_seconds(), :second)
    end
  end

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_value), do: %{}

  defp default_session_ttl_seconds, do: 15 * 60
end
