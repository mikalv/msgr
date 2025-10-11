# LlmGateway

`LlmGateway` er en OTP-applikasjon under umbrella-prosjektet som gir et felles grensesnitt mot ulike LLM-leverandører. Andre apper i umbrellaen kan bruke `LlmGateway.chat_completion/3` for å gjøre forespørsler uten å måtte kjenne detaljene til hver enkelt API.

## Viktige egenskaper

- Støtte for flere leverandører (OpenAI, Azure OpenAI, Google Vertex/Gemini og OpenAI-kompatible endepunkter).
- System-nivå API-nøkler via vanlig `config/*.exs`.
- Team-spesifikke nøkler via en pluggbar `LlmGateway.TeamKeyResolver`-implementasjon.
- Mox-baserte testhjelpere for å stubbe HTTP-kall.

## Hurtigstart

```elixir
messages = [
  %{role: "system", content: "You are a helpful assistant"},
  %{role: "user", content: "Hvilket vær er det i dag?"}
]

{:ok, response} = LlmGateway.chat_completion(team_id, messages)
```

### Velge leverandør

```elixir
LlmGateway.chat_completion(team_id, messages, provider: :google_vertex)
```

### Overstyre konfigurasjon eller nøkler

```elixir
LlmGateway.chat_completion(team_id, messages,
  provider: :openai,
  credentials: [api_key: "team-specific"],
  config: [base_url: "https://self-hosted.example.com/v1"]
)
```

## Team-nøkler

Standardoppsettet bruker `LlmGateway.TeamKeyResolver.Noop` som alltid returnerer `:error`. For å koble mot Teams-applikasjonen kan man lage en modul som implementerer `LlmGateway.TeamKeyResolver`-behaviouren og konfigurere den i `config/releases.exs` eller miljøspesifikke config-filer.

```elixir
config :llm_gateway,
  team_resolver: {MyApp.TeamsLlmResolver, []}
```

Resolveren mottar `team_id`, `provider` og valgfri opsjonsliste og skal returnere `{:ok, %{api_key: "..."}}` eller `:error`.

## Telemetri

Gatewayen emitterer følgende telemetry-events:

- `[:llm_gateway, :request_build_started]`
- `[:llm_gateway, :request_build_finished]`
- `[:llm_gateway, :provider_call_started]`
- `[:llm_gateway, :provider_call_finished]`

Disse kan abonneres på for metrikk eller logging.
