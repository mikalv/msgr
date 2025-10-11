# Messngr Identity Provider (IDP)

The `auth_provider` Phoenix app now encapsulates the Messngr identity layer. It
exposes a REST and OAuth/OIDC interface for clients, manages Guardian JWTs and
coordinates Phoenix sessions for browser flows.

## Goals

- **Unified auth surface** – the IDP issues all tokens used across Messngr and
  provides a single source for passwordless login, device registration and
  OAuth 2.0/OpenID Connect.
- **Multi-tenant** – companies can be onboarded as tenants. Each tenant carries
  configuration for session cookies, locales and its preferred identity
  provider strategy.
- **Bring-your-own-IDP** – tenants can register external OpenID Connect
  providers. Messngr will act as the service provider (SP) and exchange tokens
  with the upstream IDP.

## Architecture overview

```
┌────────────────────┐        ┌────────────────────┐
│   Messngr client    │        │   External IDP      │
│ (web/mobile/daemon) │        │  (tenant provided)  │
└──────────┬─────────┘        └──────────┬─────────┘
           │                               ▲
           │ OAuth/OIDC, device login      │
           ▼                               │
┌───────────────────────────────────────────────────┐
│                  AuthProvider.Idp                  │
│                                                   │
│  • Tenants & identity providers (Ecto schemas)     │
│  • Guardian token issuance & refresh               │
│  • Phoenix session orchestration                   │
│  • Service provider helpers (OAuth2 client)        │
└───────────────────────────────────────────────────┘
```

The IDP context (`AuthProvider.Idp`) stores tenants in the `idp_tenants` table
and identity provider definitions in `idp_identity_providers`. Each tenant gets
exactly one default provider – either `:native` (the built-in passwordless flow)
or `:external_oidc` for bring-your-own-IDP scenarios.

## Key modules

- `AuthProvider.Idp` – public API for managing tenants, issuing tokens,
  handling Phoenix sessions and building OAuth2 clients when acting as an SP.
- `AuthProvider.Idp.Tenant` – schema and helpers for slug generation and session
  configuration (cookie key, domain, TTL).
- `AuthProvider.Idp.IdentityProvider` – schema describing both native and
  external providers, including mandatory fields for OIDC integrations.
- `AuthProvider.Idp.Session` – utilities to store tenant/provider/user metadata
  inside the Phoenix session safely.

## Acting as a service provider

When a tenant registers an `external_oidc` provider, we store issuer metadata,
client credentials and endpoints. `AuthProvider.Idp.build_service_provider_client/1`
creates a ready-to-use `OAuth2.Client` configured for the Authorization Code
flow so downstream code can redirect users, exchange authorization codes and
retrieve userinfo/JWKS data.

## Next steps

- Tenant-specific JWKS rotation and signing keys so each tenant can publish its
  own metadata.
- Admin UI for managing tenants and upstream provider credentials.
- Federation adapters (SAML, SCIM) building on top of the existing structures.

