defmodule Messngr.Bridges.Auth do
  @moduledoc """
  Manages the catalog of bridge connectors and the lifecycle of bridge
  authentication sessions. The catalog is intentionally static for now, giving
  the client enough metadata to render discovery UI without hardcoding service
  details.
  """

  alias Messngr.Accounts.Account
  alias Messngr.Bridges.Auth.{CredentialInbox, CredentialVault}
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
    def slack do
      %__MODULE__{
        id: "slack",
        service: "slack",
        display_name: "Slack",
        description: "Connect Slack workspaces with multi-channel sync and thread support.",
        status: :available,
        categories: ["work"],
        prerequisites: ["Slack workspace admin consent"],
        tags: ["oauth", "multi-tenant"],
        auth: %{
          method: "oauth",
          auth_surface: "embedded_browser",
          oauth: %{
            scopes: ["channels:read", "channels:history", "chat:write"],
            pkce: true,
            allow_multiple: true
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

    @doc false
    def teams do
      %__MODULE__{
        id: "teams",
        service: "teams",
        display_name: "Microsoft Teams",
        description: "Sync Microsoft Teams chats and channels across tenants with Msgr.",
        status: :available,
        categories: ["work"],
        prerequisites: ["Azure AD admin consent"],
        tags: ["oauth", "multi-tenant"],
        auth: %{
          method: "oauth",
          auth_surface: "embedded_browser",
          oauth: %{
            scopes: ["Chat.ReadWrite", "ChannelMessage.Send", "Group.Read.All"],
            pkce: true,
            allow_multiple: true
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

  @default_oauth_provider Messngr.Bridges.Auth.Providers.Mock
  @pkce_verifier_bytes 32
  @credential_submission_ttl_seconds 300

  @catalog [
    CatalogEntry.telegram(),
    CatalogEntry.signal(),
    CatalogEntry.matrix(),
    CatalogEntry.irc(),
    CatalogEntry.slack(),
    CatalogEntry.teams()
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

  @doc """
  Retrieves a session by identifier without validating ownership. This is used
  for the browser-based OAuth flows where the embedded webview can only supply
  the session token.
  """
  @spec get_session(Ecto.UUID.t()) :: {:ok, AuthSession.t()} | {:error, term()}
  def get_session(session_id) when is_binary(session_id) do
    case Repo.get(AuthSession, session_id) do
      %AuthSession{} = session -> ensure_not_expired(session)
      nil -> {:error, :not_found}
    end
  end

  def get_session(_session_id), do: {:error, :not_found}

  @doc """
  Initiates the OAuth/OIDC redirect for a session, generating PKCE material and
  recording provider metadata. The caller is expected to redirect the user to
  the returned URL.
  """
  @spec initiate_oauth_redirect(AuthSession.t()) ::
          {:ok, AuthSession.t(), String.t()} | {:error, term()}
  def initiate_oauth_redirect(%AuthSession{} = session) do
    with :ok <- ensure_oauth_session(session),
         {:ok, _} <- ensure_not_expired(session),
         {provider, provider_opts} <- resolve_oauth_provider(session.service),
         state <- random_token(),
         code_verifier <- pkce_verifier(),
         code_challenge <- pkce_challenge(code_verifier),
         callback_path <- session_callback_path(session),
         {:ok, redirect_url, provider_metadata} <-
           provider.authorization_url(session, state,
             code_challenge: code_challenge,
             callback_path: callback_path,
             provider_opts: provider_opts
           ) do
      now = current_timestamp()

      oauth_metadata =
        session.metadata
        |> Map.get("oauth", %{})
        |> Map.merge(%{
          "state" => state,
          "code_verifier" => code_verifier,
          "code_challenge" => code_challenge,
          "redirect_url" => redirect_url,
          "provider" => stringify_map(provider_metadata || %{}),
          "initiated_at" => DateTime.to_iso8601(now)
        })

      metadata = Map.put(session.metadata, "oauth", oauth_metadata)

      session
      |> AuthSession.update_changeset(%{metadata: metadata, last_transition_at: now})
      |> Repo.update()
      |> case do
        {:ok, updated} -> {:ok, updated, redirect_url}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def initiate_oauth_redirect(_session), do: {:error, :invalid_session}

  @doc """
  Completes the OAuth callback by validating the state parameter, exchanging the
  code for tokens, and storing the credential reference in the session
  metadata.
  """
  @spec complete_oauth_callback(AuthSession.t(), map()) ::
          {:ok, AuthSession.t(), map()} | {:error, term()}
  def complete_oauth_callback(%AuthSession{} = session, params) when is_map(params) do
    with :ok <- ensure_oauth_session(session),
         {:ok, _} <- ensure_not_expired(session),
         {:ok, oauth_metadata} <- fetch_oauth_metadata(session),
         {:ok, state} <- fetch_required(oauth_metadata, "state"),
         {:ok, verifier} <- fetch_required(oauth_metadata, "code_verifier"),
         {:ok, provided_state} <- fetch_param(params, "state"),
         :ok <- verify_state(state, provided_state),
         {:ok, code} <- fetch_param(params, "code"),
         {provider, provider_opts} <- resolve_oauth_provider(session.service),
         {:ok, tokens} <-
           provider.exchange_code(session, code,
             code_verifier: verifier,
             callback_path: session_callback_path(session),
             provider_opts: provider_opts,
             provider_metadata: oauth_metadata["provider"] || %{}
           ),
         {:ok, credential_ref} <-
           CredentialVault.store_tokens(session.service, session.id, stringify_map(tokens)) do
      now = current_timestamp()

      oauth_metadata =
        oauth_metadata
        |> Map.put("authorization_code", code)
        |> Map.put("credential_ref", credential_ref)
        |> Map.put("completed_at", DateTime.to_iso8601(now))
        |> Map.put("status", "token_stored")
        |> Map.delete("code_verifier")
        |> Map.delete("code_challenge")

      metadata = Map.put(session.metadata, "oauth", oauth_metadata)

      attrs = %{state: "completing", metadata: metadata, last_transition_at: now}

      session
      |> AuthSession.update_changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, updated} -> {:ok, updated, %{credential_ref: credential_ref}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def complete_oauth_callback(_session, _params), do: {:error, :invalid_session}

  @doc """
  Queues credentials for non-OAuth flows. Secrets are placed in the credential
  inbox for daemons to retrieve while only a scrubbed summary is stored on the
  session metadata.
  """
  @spec submit_credentials(Account.t() | Ecto.UUID.t(), String.t(), Ecto.UUID.t(), map()) ::
          {:ok, AuthSession.t(), map()} | {:error, term()}
  def submit_credentials(account, connector_id, session_id, credentials) do
    ttl = @credential_submission_ttl_seconds

    with {:ok, session} <- fetch_session(account, session_id),
         :ok <- ensure_connector_match(session, connector_id),
         :ok <- ensure_non_oauth_session(session),
         {:ok, credential_map} <- normalise_credentials(credentials),
         :ok <- CredentialInbox.put(session.id, credential_map, ttl: ttl) do
      now = current_timestamp()
      summary = credential_summary(credential_map, ttl, now)

      metadata = Map.put(session.metadata, "credential_submission", summary)

      attrs = %{state: "completing", metadata: metadata, last_transition_at: now}

      session
      |> AuthSession.update_changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, updated} -> {:ok, updated, summary}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Allows bridge daemons to dequeue credential payloads. Returns an error if the
  payload is missing or expired.
  """
  @spec checkout_credentials(Ecto.UUID.t()) :: {:ok, map()} | {:error, term()}
  def checkout_credentials(session_id) when is_binary(session_id) do
    CredentialInbox.checkout(session_id)
  end

  def checkout_credentials(_session_id), do: {:error, :not_found}

  @doc """
  Returns session metadata with sensitive fields removed so it can be exposed to
  the Msgr client safely.
  """
  @spec public_metadata(AuthSession.t() | map()) :: map()
  def public_metadata(%AuthSession{metadata: metadata}), do: public_metadata(metadata)

  def public_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, key, scrub_metadata(key, value))
    end)
  end

  def public_metadata(_other), do: %{}

  defp ensure_connector_match(%AuthSession{} = session, connector_id) when is_binary(connector_id) do
    connector = session.catalog_snapshot["id"] || session.service

    if connector == connector_id do
      :ok
    else
      {:error, :connector_mismatch}
    end
  end

  defp ensure_connector_match(_session, _connector_id), do: {:error, :connector_mismatch}

  defp ensure_oauth_session(%AuthSession{login_method: "oauth"}), do: :ok
  defp ensure_oauth_session(%AuthSession{}), do: {:error, :unsupported_login_method}

  defp ensure_non_oauth_session(%AuthSession{login_method: "oauth"}), do: {:error, :unsupported_login_method}
  defp ensure_non_oauth_session(%AuthSession{}), do: :ok

  defp ensure_not_expired(%AuthSession{expires_at: nil} = session), do: {:ok, session}

  defp ensure_not_expired(%AuthSession{expires_at: expires_at} = session) do
    case DateTime.compare(expires_at, DateTime.utc_now()) do
      :lt -> {:error, :session_expired}
      _ -> {:ok, session}
    end
  end

  defp resolve_oauth_provider(service) do
    providers =
      :msgr
      |> Application.get_env(:bridge_auth, [])
      |> Keyword.get(:providers, %{})

    providers =
      Enum.reduce(providers, %{}, fn {key, value}, acc ->
        Map.put(acc, normalise_provider_key(key), normalise_provider(value))
      end)

    Map.get(providers, normalise_provider_key(service), normalise_provider(@default_oauth_provider))
  end

  defp normalise_provider({module, opts}) when is_atom(module) and is_list(opts), do: {module, opts}
  defp normalise_provider(module) when is_atom(module), do: {module, []}

  defp normalise_provider(%{module: module} = map) when is_atom(module) do
    opts = Map.get(map, :opts) || Map.get(map, "opts") || []
    {module, normalise_provider_opts(opts)}
  end

  defp normalise_provider(_other), do: {@default_oauth_provider, []}

  defp normalise_provider_opts(opts) when is_list(opts), do: opts
  defp normalise_provider_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalise_provider_opts(opts), do: List.wrap(opts)

  defp normalise_provider_key(value) when is_binary(value), do: value
  defp normalise_provider_key(value) when is_atom(value), do: Atom.to_string(value)
  defp normalise_provider_key(value), do: to_string(value)

  defp fetch_oauth_metadata(%AuthSession{} = session) do
    metadata = Map.get(session.metadata, "oauth") || %{}

    if metadata == %{} do
      {:error, :oauth_not_initiated}
    else
      {:ok, metadata}
    end
  end

  defp fetch_required(map, key) when is_map(map) do
    cond do
      Map.has_key?(map, key) -> {:ok, map[key]}
      true ->
        case maybe_atom_key(key) do
          nil -> {:error, {:missing_value, key}}
          atom when Map.has_key?(map, atom) -> {:ok, map[atom]}
          _ -> {:error, {:missing_value, key}}
        end
    end
  end

  defp fetch_required(_map, key), do: {:error, {:missing_value, key}}

  defp maybe_atom_key(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> nil
    end
  end

  defp maybe_atom_key(_), do: nil

  defp fetch_param(params, key) when is_map(params) do
    case Map.fetch(params, key) do
      {:ok, value} when value in [nil, ""] -> {:error, {:missing_param, key}}
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_param, key}}
    end
  end

  defp fetch_param(_params, key), do: {:error, {:missing_param, key}}

  defp verify_state(expected, provided) when expected == provided, do: :ok
  defp verify_state(_expected, _provided), do: {:error, :state_mismatch}

  defp random_token(bytes \\ 24) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp pkce_verifier, do: random_token(@pkce_verifier_bytes)

  defp pkce_challenge(verifier) when is_binary(verifier) do
    :crypto.hash(:sha256, verifier)
    |> Base.url_encode64(padding: false)
  end

  defp pkce_challenge(_verifier), do: nil

  defp current_timestamp, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp stringify_map(value) when is_map(value) do
    value
    |> Enum.map(fn {key, val} ->
      string_key =
        cond do
          is_binary(key) -> key
          is_atom(key) -> Atom.to_string(key)
          true -> to_string(key)
        end

      normalised_val =
        cond do
          is_map(val) -> stringify_map(val)
          is_list(val) -> Enum.map(val, &stringify_map/1)
          true -> val
        end

      {string_key, normalised_val}
    end)
    |> Map.new()
  end

  defp stringify_map(value) when is_list(value), do: Enum.map(value, &stringify_map/1)
  defp stringify_map(value), do: value

  defp normalise_credentials(credentials) when is_map(credentials) do
    credentials
    |> stringify_map()
    |> case do
      %{} = map when map == %{} -> {:error, :invalid_credentials_payload}
      %{} = map -> {:ok, map}
      _ -> {:error, :invalid_credentials_payload}
    end
  end

  defp normalise_credentials(_), do: {:error, :invalid_credentials_payload}

  defp credential_summary(credentials, ttl, timestamp) do
    fields =
      credentials
      |> Map.keys()
      |> Enum.map(&to_string/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.sort()

    %{
      "fields" => fields,
      "submitted_at" => DateTime.to_iso8601(timestamp),
      "ttl_seconds" => ttl,
      "status" => "queued"
    }
  end

  defp scrub_metadata("oauth", value) when is_map(value) do
    value
    |> stringify_map()
    |> Map.drop(["state", "code_verifier", "code_challenge", "authorization_code"])
    |> Map.update("provider", %{}, fn provider -> stringify_map(provider) end)
  end

  defp scrub_metadata(_key, value), do: value

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
