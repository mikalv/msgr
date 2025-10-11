# Bridge Hosting Models – Managed vs. Customer-Operated

## Background
Msgrs broarkitektur er bygget rundt StoneMQ-drevne köer, separate connector-daemons per plattform, og en Elixir-fasade som publiserer og lytter på `bridge/<service>/<action>`-topics. Dette muliggjør isolerte utrullinger per workspace, policy-lag mellom klient og eksterne nettverk, og støtte for flere språk i daemon-laget.【F:docs/bridge_architecture.md†L4-L46】【F:docs/bridge_strategy.md†L4-L48】【F:docs/telegram_matrix_integration.md†L1-L46】

## Alternativ 1 – Fullt administrerte broer
- **Opplevelse**: Operatøren leverer og drifter alle bridge-daemons. Brukere knytter kontoene sine via Msgr og får umiddelbar tilgang uten lokal infrastruktur.
- **Fordeler**:
  - Konsistent brukeropplevelse og enklere onboarding, i tråd med selvbetjeningsplanen for identitetslinking i klienten.【F:docs/account_management.md†L1-L48】
  - Sentralisert policy- og audit-lag reduserer risiko for feilkonfigurasjoner og sikrer revisjonsspor.【F:docs/bridge_architecture.md†L23-L36】
  - Operatøren kan overvåke StoneMQ og bridge-daemons for latens, feilhåndtering og kapasitet, og rulle ut sikkerhetsoppdateringer uten kundens involvering.【F:docs/bridge_architecture.md†L38-L62】
- **Ulemper**:
  - Høyere operasjonelle kostnader og krav til bemanning for døgndrift, sikkerhet og plattform-reversering.
  - Juridisk ansvar for hvordan eksterne nettverk brukes (ToS, rate limits), siden operatøren står for infrastrukturen.

## Alternativ 2 – Kundeopererte broer
- **Opplevelse**: Kunder kjører egne bridge-daemons (Docker, Kubernetes, on-prem) og kobler dem til Msgrs StoneMQ, eventuelt med egen nøkkel- og køinfrastruktur.
- **Fordeler**:
  - For virksomheter med strenge krav til datasuverenitet kan de holde protokolltrafikk og legitimasjon innenfor egne miljøer.
  - Reduserer leverandørens driftskostnader og skyforbruk ved at kunden bærer compute- og nettverkskostnaden.
- **Ulemper**:
  - Mer kompleks onboarding; kundene må forstå queue-kontrakter og holde daemonene oppdatert med API-endringer.【F:docs/telegram_matrix_integration.md†L13-L46】
  - Krever veiledning rundt sikkerhet (MTLS/Noise, HSM-integrasjon), noe som ellers er standardisert i den sentrale plattformen.【F:docs/bridge_architecture.md†L23-L36】
  - Support blir vanskeligere: feil kan ligge i kundens miljø, og feilsøking krever tilgang til loggene deres.

## Alternativ 3 – Hybrid modell
- **Opplevelse**: Standard er administrert bridge. For større kunder tilbys “bring your own daemon” med sertifiserte pakker og støtteplan.
- **Fordeler**:
  - Lar oss optimalisere for mainstream-brukere mens enterprise-kunder får fleksibilitet.
  - Feature-flagg i Elixir-laget kan aktivere/deaktivere hvilke connectorer som rutes mot kundens infrastruktur per workspace.【F:docs/bridge_architecture.md†L62-L64】
  - Kan kombinere med dedikerte StoneMQ-namespaces og policykonfigurasjon per tenant.【F:docs/bridge_strategy.md†L15-L32】
- **Ulemper**:
  - Krever ekstra produktflate (UI/API) for å registrere endepunkter, sertifikater og healthchecks.
  - Testing og dokumentasjon må dekke flere distribusjonsveier (managed vs. self-hosted).

## Innsikter fra Beeper Bridge Manager
Bridge Manager (`bbctl`) fra Beeper gir et godt sammenligningsgrunnlag for hva selvdriftede broer krever i praksis. Kort oppsummert:

- **Fokus på CLI-verktøy**: Kunder laster ned en binær, logger inn og starter broer via `bbctl run <navn>`. Oppsettet forutsetter lokal pakkehåndtering (Python, ffmpeg) og kjøring i forgrunnen eller via egne prosessverktøy.
- **Begrenset support**: Beeper reduserer kundestøtten for selvhostede broer og ber brukere om å benytte egne Matrix-rom for hjelp. Dette illustrerer supportbyrden ved å slippe løs selvdriftede broer uten klare grenser.
- **Standardiserte navn og registreringer**: Bridge Manager genererer namespaces (`sh-<navn>`) og appservice-registreringer, og tilbyr proxy for broer som ikke støtter Beepers websocket-protokoll.
- **Fremtidig automatisering**: Prosjektet planlegger service-modus (systemd/launchd) og bedre UI-integrasjon, som viser at en fullgod selvdriftsopplevelse krever investeringer utover bare å publisere containere.

For Msgr betyr dette at en eventuell selvdriftsmodell må komme med tydelige rammer: et offisielt verktøy for registrering/oppsett, avklarte støttekanaler og en plan for hvordan klient- og backend-opplevelsen skal integreres når kunden kjører broene selv. Se også prosjektets README for mer detaljer: <https://github.com/beeper/bridge-manager>.

## Anbefaling
Start med fullt administrerte broer for å sikre sluttbrukeropplevelse, sikkerhet og rask iterasjon. Parallelt bør vi:
1. Dokumentere protokollkontrakten (payload-schema, forventede svar) og publisere Docker-images for bridge-daemons, slik at en begrenset kundebase kan pilotere selv-hosting senere.【F:docs/telegram_matrix_integration.md†L1-L46】
2. Legge inn arkitektoniske kroker (feature-flagg, navnerom i StoneMQ) som gjør det mulig å peke en workspace mot ekstern bridge-infrastruktur uten kodeendringer.【F:docs/bridge_architecture.md†L4-L64】
3. Utforme et «Msgr Bridge Manager»-konsept inspirert av Beeper: et kommandolinjeverktøy med bootstrap, namespace-konvensjoner og eksplisitte supportgrenser for kunder som vil kjøre selv.
4. Evaluere juridiske og supportmessige rammer for en hybridmodell, inkludert SLA-krav og ansvarsdeling når kundene drifter egne konektorer.

Denne tilnærmingen gir rask time-to-value for hovedsegmentene, samtidig som vi beholder fleksibilitet for virksomheter med spesielle krav.
