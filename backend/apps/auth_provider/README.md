# Auth Provider (IDP)

This Phoenix application now hosts the Messngr Identity Provider (IDP).
It exposes device onboarding, passwordless login and an OAuth 2.0/OpenID
Connect surface powered by [Boruta](https://github.com/dwyl/boruta).

The IDP is fully multi-tenant aware. Each tenant gets a dedicated session
configuration and a default identity provider strategy. By default a tenant
uses the native Messngr flow, but you can also register upstream OpenID
Connect providers when customers bring their own identity platform—our IDP then
acts as the service provider.

## Local development

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Identity tenants

- Create tenants with `AuthProvider.Idp.create_tenant/1`. A native provider is
  created automatically, or you can supply an `external_oidc` configuration to
  make Messngr behave as a service provider against a third-party IDP.
- `AuthProvider.Idp.issue_tokens/3` issues Guardian-backed JWT tokens scoped to
  a tenant and handles refresh tokens.
- `AuthProvider.Idp.Session` centralises Phoenix session management so we can
  safely store tenant, provider and user metadata for the browser flows.
- `AuthProvider.Idp.build_service_provider_client/1` turns an upstream OIDC
  configuration into a ready-to-use `OAuth2.Client` instance.

See `docs/idp.md` for more architectural details and future plans.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
