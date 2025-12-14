# Elixir Backend - Fjerne Noise Protocol Kode

## Oversikt

Nå som Noise Protocol er håndtert av Rust Gateway, kan vi fjerne all Noise-relatert kode fra Elixir backend.

## Files som skal fjernes

### Noise Protocol Implementation

```bash
# Fjern Noise transport modules
rm backend/apps/msgr/lib/msgr/transport/noise/session.ex
rm backend/apps/msgr/lib/msgr/transport/noise/registry.ex
rmdir backend/apps/msgr/lib/msgr/transport/noise/

# Fjern Noise handshake modules
rm backend/apps/msgr/lib/msgr/noise/handshake.ex
rm backend/apps/msgr/lib/msgr/noise/session_store.ex
rm backend/apps/msgr/lib/msgr/noise/dev_handshake.ex
rm backend/apps/msgr/lib/msgr/noise/key_loader.ex
rmdir backend/apps/msgr/lib/msgr/noise/

# Fjern controller
rm backend/apps/msgr_web/lib/msgr_web/controllers/noise_handshake_controller.ex
```

### Plugs som skal oppdateres

#### ❌ Fjern: `NoiseSession` plug

**File:** `backend/apps/msgr_web/lib/msgr_web/plugs/noise_session.ex`

**Action:** Slett hele filen

#### ✅ Erstatt med: `SessionContext` plug

**File:** `backend/apps/msgr_web/lib/msgr_web/plugs/session_context.ex`

```elixir
defmodule MessngrWeb.Plugs.SessionContext do
  @moduledoc """
  Extract session context from headers injected by Rust Gateway
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Extract headers set by Rust Gateway
    account_id = get_req_header(conn, "x-account-id") |> List.first()
    profile_id = get_req_header(conn, "x-profile-id") |> List.first()
    device_id = get_req_header(conn, "x-device-id") |> List.first()
    session_id = get_req_header(conn, "x-session-id") |> List.first()

    Logger.debug("Session context from Rust Gateway",
      account_id: account_id,
      profile_id: profile_id,
      session_id: session_id
    )

    conn
    |> assign(:current_account_id, account_id)
    |> assign(:current_profile_id, profile_id)
    |> assign(:current_device_id, device_id)
    |> assign(:session_id, session_id)
    |> load_current_account()
    |> load_current_profile()
  end

  defp load_current_account(%{assigns: %{current_account_id: nil}} = conn), do: conn

  defp load_current_account(%{assigns: %{current_account_id: account_id}} = conn) do
    case Messngr.Accounts.get_account(account_id) do
      {:ok, account} ->
        assign(conn, :current_account, account)

      {:error, _} ->
        Logger.warn("Account not found", account_id: account_id)
        conn
    end
  end

  defp load_current_profile(%{assigns: %{current_profile_id: nil}} = conn), do: conn

  defp load_current_profile(%{assigns: %{current_profile_id: profile_id}} = conn) do
    case Messngr.Profiles.get_profile(profile_id) do
      {:ok, profile} ->
        assign(conn, :current_profile, profile)

      {:error, _} ->
        Logger.warn("Profile not found", profile_id: profile_id)
        conn
    end
  end
end
```

### Router oppdateringer

#### `backend/apps/msgr_web/lib/msgr_web/router.ex`

**Fjern:**

```elixir
# Fjern Noise handshake route
scope "/api/noise", MessngrWeb do
  pipe_through :api

  post "/handshake", NoiseHandshakeController, :create
end
```

**Oppdater pipeline:**

```elixir
# BEFORE:
pipeline :authenticated do
  plug MessngrWeb.Plugs.NoiseSession  # ❌ Fjern
end

# AFTER:
pipeline :authenticated do
  plug MessngrWeb.Plugs.SessionContext  # ✅ Ny
end
```

### WebSocket updates

#### `backend/apps/msgr_web/lib/msgr_web/channels/user_socket.ex`

**BEFORE:**

```elixir
def connect(params, socket, _connect_info) do
  case NoiseSession.verify_token(params["noise_session"]) do
    {:ok, session} ->
      {:ok, assign(socket, :current_account, session.account)}
    {:error, _} ->
      :error
  end
end
```

**AFTER:**

```elixir
def connect(params, socket, _connect_info) do
  # Rust Gateway already validated session and passed account_id
  account_id = params["account_id"]
  profile_id = params["profile_id"]

  with {:ok, account} <- Messngr.Accounts.get_account(account_id),
       {:ok, profile} <- Messngr.Profiles.get_profile(profile_id) do
    socket =
      socket
      |> assign(:current_account, account)
      |> assign(:current_profile, profile)
      |> assign(:account_id, account_id)
      |> assign(:profile_id, profile_id)

    {:ok, socket}
  else
    _ -> :error
  end
end
```

### Configuration updates

#### `backend/apps/msgr_web/config/config.exs`

**BEFORE:**

```elixir
config :msgr_web, MessngrWeb.Endpoint,
  http: [port: 4000],
  url: [host: "localhost"],
  server: true
```

**AFTER:**

```elixir
config :msgr_web, MessngrWeb.Endpoint,
  # Listen ONLY on localhost (Rust Gateway proxies)
  http: [port: 4000, ip: {127, 0, 0, 1}],
  url: [host: "localhost"],
  server: true,
  # Disable HTTPS (Rust Gateway handles TLS)
  https: false
```

### Tests oppdateringer

All tests som bruker `NoiseSession` eller `DevHandshake` må oppdateres:

**BEFORE:**

```elixir
test "authenticated request" do
  {:ok, session} = DevHandshake.create_handshake()

  conn =
    build_conn()
    |> put_req_header("authorization", "Noise #{session.token}")
    |> get("/api/conversations")

  assert json_response(conn, 200)
end
```

**AFTER:**

```elixir
test "authenticated request" do
  account = insert(:account)
  profile = insert(:profile, account: account)

  conn =
    build_conn()
    |> put_req_header("x-account-id", account.id)
    |> put_req_header("x-profile-id", profile.id)
    |> get("/api/conversations")

  assert json_response(conn, 200)
end
```

### Telemetry cleanup

**Fjern Noise telemetry events:**

```elixir
# Fjern disse events fra telemetry handlers
[:messngr, :noise, :handshake, :start]
[:messngr, :noise, :handshake, :stop]
[:messngr, :noise, :token, :verify]
```

## Migration Checklist

- [ ] **Backup database** (hvis nødvendig)
- [ ] **Create feature branch** `git checkout -b remove-noise-protocol`
- [ ] **Fjern Noise modules** (liste over)
- [ ] **Slett NoiseHandshakeController**
- [ ] **Opprett SessionContext plug**
- [ ] **Oppdater router.ex**
- [ ] **Oppdater user_socket.ex**
- [ ] **Oppdater config** (bind til localhost)
- [ ] **Fix tests**
- [ ] **Run test suite** `mix test`
- [ ] **Update documentation**
- [ ] **Create PR**

## Testing Plan

### 1. Unit Tests

```bash
cd backend
mix test
```

### 2. Integration Test

Start Rust Gateway først:

```bash
cd rust-gateway
export SERVER_STATIC_KEY=$(openssl rand -base64 32)
export BACKEND_URL=http://localhost:4000
cargo run --release
```

Start Elixir backend:

```bash
cd backend
mix phx.server
```

Test med curl:

```bash
# Handshake (handled by Rust)
curl -X POST http://localhost:8443/noise/handshake \
  -H "Content-Type: application/json" \
  -d '{"pattern":"NKpsk0","psk":"dGVzdF9wc2tfMzJfYnl0ZXNfbG9uZ19leGFjdGx5ISE="}'

# API request (proxied to Elixir)
curl http://localhost:8443/api/conversations \
  -H "Authorization: Noise <token_from_handshake>"
```

### 3. Flutter Client Test

Minimal endring nødvendig:

```dart
// BEFORE: POST to Elixir
final url = 'https://backend.example.com/api/noise/handshake';

// AFTER: POST to Rust Gateway
final url = 'https://gateway.example.com/noise/handshake';

// Alt annet er likt!
```

## Rollback Plan

Hvis det oppstår problemer:

```bash
# Revert branch
git checkout main

# Restart services
cd backend && mix phx.server

# Point Flutter directly to Elixir (temporary)
```

## Performance Impact

**Forventet:**
- ✅ Lavere CPU i Elixir (ingen crypto)
- ✅ Enklere kodebase
- ✅ Raskere Noise operations (Rust)
- ⚠️ Minimal proxy overhead (~0.5ms)

**Monitor:**
- Request latency (Phoenix LiveDashboard)
- Error rates (Sentry)
- Connection counts

## Benefits

✅ **Enklere Elixir kodebase**
- Mindre kode å vedlikeholde
- Standard Phoenix patterns
- Ingen crypto-logikk

✅ **Bedre separasjon**
- Rust: Edge security + crypto
- Elixir: Business logic

✅ **Lettere å teste**
- Mock headers i stedet for Noise sessions
- Ingen DevHandshake-logic

✅ **Bedre sikkerhet**
- Krypto isolert i Rust
- Elixir aldri ser tokens direkte
