# LLM Gateway

`llm_gateway` er backend-komponenten som kapsler inn all kommunikasjon med eksterne Large Language Models. Målet er å tilby et stabilt API mot resten av systemet slik at hver enkelt app slipper å implementere leverandørspesifikke integrasjoner.

## Funksjonalitet

- **Felles API** – `LlmGateway.chat_completion/3` normaliserer meldingsstrukturer og returnerer dekodede JSON-svar.
- **Fleksible leverandører** – leverandører defineres i config og kan utvides ved å implementere `LlmGateway.Provider`.
- **System- og team-nøkler** – `LlmGateway.Config` kombinerer nøkler fra `config/*.exs`, miljøvariabler og en `TeamKeyResolver` for kundespesifikke nøkler.
- **Telemetry** – alle kall emiterer telemetry events som kan kobles til observability-verktøy.

## Konfigurasjon

Standardkonfigurasjon finner du i `backend/config/config.exs`. Viktige nøkler:

```elixir
config :llm_gateway,
  default_provider: :openai,
  default_model: "gpt-4o-mini",
  providers: %{
    openai: [
      module: LlmGateway.Provider.OpenAI,
      base_url: "https://api.openai.com/v1",
      required_credentials: [:api_key]
    ],
    azure_openai: [
      module: LlmGateway.Provider.AzureOpenAI,
      endpoint: System.get_env("AZURE_OPENAI_ENDPOINT"),
      deployment: System.get_env("AZURE_OPENAI_DEPLOYMENT"),
      api_version: System.get_env("AZURE_OPENAI_API_VERSION"),
      required_credentials: [:api_key]
    ],
    google_vertex: [
      module: LlmGateway.Provider.GoogleVertex,
      endpoint: "https://generativelanguage.googleapis.com",
      required_credentials: [:api_key]
    ],
    openai_compatible: [
      module: LlmGateway.Provider.OpenAI,
      base_url: System.get_env("SELF_HOSTED_OPENAI_URL"),
      required_credentials: [:api_key]
    ]
  }
```

`system_credentials` angir standard API-nøkler. Team-spesifikke nøkler hentes via `team_resolver`, som peker på en modul som implementerer `LlmGateway.TeamKeyResolver`.

## Bruk i andre apper

```elixir
messages = [
  %{role: "user", content: "Lag en hyggelig velkomstmelding"}
]

{:ok, reply} = LlmGateway.chat_completion(team.id, messages,
  provider: :azure_openai,
  credentials: [api_key: team.azure_key]
)
```

For avansert bruk kan du sende `config: [base_url: ...]` for å overstyre leverandørkonfigurasjonen.

## Testing

Modulen bruker `Mox` for å kunne stubbe HTTP-klienten. Se `apps/llm_gateway/test/llm_gateway/provider/*_test.exs` for eksempler på forventninger som sikrer at riktige headere og payloads sendes.

## Videre arbeid

- Utrede strømming av svar (`stream: true`).
- Lage en `Teams`-integrasjon som persisterer og roterer API-nøkler pr. lag.
- Legge til støtte for flere operasjoner (for eksempel embeddings og moderering).
