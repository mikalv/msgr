# Produktbacklogg

Denne backloggen grupperer de mest etterspurte satsingene slik at integrasjoner og kjernefunksjoner kan planlegges koordinert.

## Integrasjoner

| Initiativ | Mål | Status | Avhengigheter |
| --- | --- | --- | --- |
| Slack bridge alfa | Fullføre resterende «remaining work»-liste og pilotere sanntidsflyt | Pågående | `docs/slack_bridge_remaining_work.md`, bridge-daemons |
| Microsoft Teams bridge | Levere webhook-/poller-paritet og admin-opplevelser | Pågående | `docs/teams_bridge_remaining_work.md`, Graph API |
| WhatsApp utforskning | Kartlegge uoffisielle API-er og kostnadsprofil | Backlog | Reverse engineering, potensielle tredjeparts-SDK-er |

## Kanaler

| Initiativ | Mål | Status | Avhengigheter |
| --- | --- | --- | --- |
| Nyhetskanaler (RSS) | Automatisk innhold for å aktivere tomme spaces | Backlog | Feed-aggregator, kanal-administrasjon |
| Familie/vennekanaler | Kuratere standardmaler og invitasjonsflyt | Backlog | QR-/invitasjonsflyt, workspace-tema |

## Admin og Workspace

| Initiativ | Mål | Status | Avhengigheter |
| --- | --- | --- | --- |
| Pay-per-feature modell | Utforske modulbasert fakturering og feature gating | Discovery | Billing backends, feature toggles |
| Workspace onboarding | Forenkle oppsett for nye admins inkl. maler | Backlog | Admin UI, dokumentasjon |
| Passkey-styrt innlogging | Aktivere WebAuthn i alle klienter | Discovery | Se `docs/webauthn_login_plan.md` |

## P2P / SRTP

| Initiativ | Mål | Status | Avhengigheter |
| --- | --- | --- | --- |
| WebRTC-video | P2P-samtaler med fallback til relé | Backlog | TURN-infrastruktur, klientkode |
| SRTP-hardening | Definere nøkkelbytte og codecs for sikre samtaler | Backlog | Noise/DTLS integrasjon, medieservere |

Backloggen bør revideres når nye eksperimenter startes eller ferdigstilles slik at statuslinjene reflekterer den delte forståelsen.
