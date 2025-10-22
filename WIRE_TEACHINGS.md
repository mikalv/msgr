# Wire Server Teachings

An architecture safari through `wire-server/` (see `wire-server/README.md:21`) surfaces several repeatable patterns that can strengthen our own backend. Below is a condensed field report with references into the upstream tree and ideas for how we can translate them into `msgr/`.

## Architecture Snapshot

- **Clearly bounded services.** Wire splits responsibilities into independently deployable services such as the `galley` conversation service, the `brig` account service, and the `gundeck` push hub (`wire-server/README.md:25`). Each owns its datastore schema and background jobs.
- **Typed ingress layer.** All public traffic is funneled through `nginz`, an nginx build linked with their custom `libzauth` module for ed25519-token auth (`wire-server/README.md:26`, `wire-server/libs/libzauth/README.md:1`, `wire-server/libs/zauth/README.md:1`).
- **Shared contract library.** The `libs/wire-api` package exposes the same Servant route and DTO definitions to every service, so server and client stubs compile against identical types (`wire-server/libs/wire-api/src/Wire/API/User/Auth.hs:21`).

## Patterns Worth Emulating

### Observability-First Service Harness

- Startup pipelines eagerly wire Prometheus, OpenTelemetry, gzip, and structured request IDs into every Servant application (`wire-server/services/galley/src/Galley/Run.hs:92`, `wire-server/services/gundeck/src/Gundeck/Run.hs:133`). The middleware stack is consistent across services, cutting boilerplate and ensuring traces/metrics land everywhere.
- Migration runners execute before the HTTP listener comes up (`wire-server/services/galley/src/Galley/Run.hs:73`), enforcing a “schema first” invariant that avoids skew in rolling deploys.

**Takeaway for `msgr`:** consolidate our Phoenix plug stack so telemetry, compression, and error envelopes line up across apps; fail fast if Ecto migrations haven’t been applied.

### Multi-Store Persistence with Message Fan-Out

- A single service environment carries pools for Cassandra, Postgres, RabbitMQ, HTTP/2 clients, and SQS/AWS creds (`wire-server/services/galley/src/Galley/Env.hs:54`). That lets Galley transact across chat history (Cassandra) and relational state (Postgres) while scheduling deletes over AMQP.
- Gundeck dedicates a process to wiring RabbitMQ exchanges and monitoring fan-out load, plus background listeners on SQS for mobile push (`wire-server/services/gundeck/src/Gundeck/Run.hs:73`, `wire-server/services/gundeck/src/Gundeck/Run.hs:96`).

**Takeaway for `msgr`:** codify which persistence tier serves each concern (e.g., Postgres for relational, Redis for session, S3 for blobs) and expose a single “Env” struct in each OTP app so queues, stores, and clients are initialized together.

### Typed Internal HTTP Clients

- Cross-service calls are funneled through thin, typed helpers (e.g., Galley notifying Spar or fetching SCIM metadata via `Bilge` HTTP builders) (`wire-server/services/galley/src/Galley/Intra/Spar.hs:34`). The request shape and expected status codes live next to the caller logic.

**Takeaway for `msgr`:** wrap internal bridge-to-core requests in small modules (HTTP or gRPC) that capture verb, path, and success criteria, rather than sprinkling `Finch.request/1` calls through the code.

### Edge Authentication Discipline

- Access tokens are self-described (versioned, key-indexed, timestamped) and signed with ed25519 (`wire-server/libs/zauth/README.md:1`). `libzauth` lets nginx verify them before the request ever hits an app server.

**Takeaway for `msgr`:** even before we ship an nginx module, we can decouple token parsing from business logic and make signature validation a plug that runs ahead of controllers.

### Documentation & Release Tooling

- Documentation changes ship from the code repo and are auto-validated against the downstream docs site via submodule automation (`wire-server/docs/README.md:1`). Build tooling lives next to services (Makefiles, Nix shells, Helm charts) making the repo a self-contained “platform”.

**Takeaway for `msgr`:** keep living architecture notes (like this file) in-repo and wire them into CI linting to prevent drift between docs and implementation.

## Suggested Next Moves for `msgr`

1. **Standardize inbound middleware + tracing** – create a Phoenix plug pipeline mirroring Wire’s Servant stack (request IDs, gzip, Prom/OTel exporters) and load it in every endpoint.
2. **Document service & datastore ownership** – write a short ADR mapping each `msgr` OTP app to its primary storage/queue so future code doesn’t mix concerns (`Galley.Env` is a good template).
3. **Wrap internal HTTP calls** – introduce modules (e.g., `Msgr.Bridge.Spar`) that wrap HTTP requests with shared error handling, drawing from `Galley.Intra.Spar` as a pattern.
4. **Define bridge tokens formally** – describe our session tokens the way `zauth` does (fields, signature alg, expiry) and park verification one layer earlier in the request flow.
5. **Keep learnings visible** – treat `WIRE_TEACHINGS.md` as a living doc and hook it into our architecture review checklist so future explorations (Matrix, Signal, etc.) stay discoverable.

