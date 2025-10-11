Konge idé med “modus” (Jobb/Privat) over én konto + flere profiler. Her er en konkret utviklingsplan med milepæler, leveranser og anbefalte “bets” – fokusert på det som mest sannsynlig gir verdi og differensiering.

Veikart (sekvensielle faser med klare milepæler)

Fase 0 – Fundament og risikonedsettelse

Mål: Bekreft kjernearkitektur, sikkerhet og UX før vi bygger “alt”.
	•	Arkitektur/rammeverk
	•	Klient: Flutter (mobiler + desktop/web).
	•	Backend: Elixir/Phoenix Channels (+ Go-mikroservice der ytelse/medieprosess trengs).
	•	Lagring: PostgreSQL (start enkel, design for shard/arkiv; Citus senere).
	•	Kø/stream: NATS/Redis Streams/Kafka (velg én).
	•	Sikkerhet
	•	Transport: Noise (klient–server og P2P).
	•	Meldinger: Double Ratchet (Signal-kompat. bibliotek).
	•	Nøkkelhvelv pr enhet + E2EE-synk-design.
	•	Identitet
	•	Én global konto (ULID/UUID), flere profiler (Jobb/Privat) med egne policyer/temaer og tilganger.
	•	OIDC inngang: BankID/Vipps/Passkey, men valgfritt (lav terskel = tlf/e-post også).
	•	UX-ramme
	•	Navigasjonsmodell for moduser (Jobb/Privat) + profilbytter, tydelig fargetema og “context banner”.
	•	Milestone (Go/No-Go)
	•	Kryptert 1:1-chat (tekst) mellom to testbrukere (to enheter).
	•	Profil-bytter fungerer (UI + policy-skillegjerde).
	•	Lokal “seed” nøkkel + sikker backupfrø testet.

Fase 1 – MVP (Privat modus) — “Norsk, trygg, enkel chat”

Mål: Slippbar privat-app med norsk/EU personvern som USP.
	•	Kjernefunksjoner
	•	E2EE 1:1 og små grupper (≤32).
	•	Historikksynk mellom egne enheter (device-to-device bootstrap med QR/nearby, ikke serverde-kryptert).
	•	Media (foto/video/fil) med pre-signed S3/MinIO (EU/Norge).
	•	Gjestetoken (midlertidig invitasjon uten full konto).
	•	“Chat med meg selv”.
	•	Hemmelig modus (skjult profil+låst visning).
	•	Temasystem (bruker-/profilnivå; “Privat” preset).
	•	Personvern
	•	All lagring i Norge/EU, ingen sporing/annonser.
	•	Transparent Privacy Whitepaper (kort, tydelig).
	•	Milestone
	•	Lukked beta i Norge (familier/venner/klasser).
	•	Telemetri: bare anonymt aggregat, opt-in.

Fase 2 – Moduser & Profiler, Notifikasjons-AI (lett), Kanaler

Mål: Spisse differensiering: Modus-systemet + smartere varsler.
	•	Profiler/Modus
	•	“Jobb”-modus innføres i klienten (UI, temapreset, filter: jobb-varsler kun i jobb-vindu/tidsrom).
	•	Strenge profil-policyer (f.eks. jobb-profil krever PIN/biometri).
	•	Kanaler (enveis)
	•	E2EE-kanaler for offentlig/privat kringkasting (moderert, signerte poster).
	•	Deling til eksterne (kryptert link) + enkel cross-post (X/FB/IG) med watermark.
	•	Notifikasjoner (AI-lite, on-device)
	•	Enkle heuristikker + on-device ML for “relevant vs. støy”.
	•	Milestone
	•	Påviselig reduksjon i “mute rate” + høyere åpningsrate for “viktige” varsler.
	•	3–5 pilot-kanaler (podcast, lokalavis, skole).

Fase 3 – Interop & Gateways (DMA-ready), Bedrift Light

Mål: Senk nettverkseffekten; første steg mot SMB/Teams/Slack-nytte.
	•	Interop (der mulig)
	•	Slack innkommende webhooks + enkel bot-kompat.
	•	Telegram bot/kanal-speiling (les/skriv der API tillater).
	•	DMA-ready design: modul for WhatsApp/Messenger bridge når offisielt åpnet.
	•	“Bedrift Light”
	•	Team/workspace med kanaler, rolle/tilgang, gjestebruker.
	•	Import: Slack (JSON/ZIP) → mapping til vår modell.
	•	Enkle admin-paneler (SaaS).
	•	Milestone
	•	Første betalende SMB-team (20–100 brukere).
	•	En “bridge” i produksjon (lovlig API) med målbar bruk.

Fase 4 – P2P-grupper og P2P-kanaler (Premium), SRTP-kall

Mål: “Moonshot”-differensiering for avanserte brukere og ytringsfrihet.
	•	P2P-grupper/kanaler
	•	DHT-basert history replay (chunket, E2EE), krav om diskbidrag.
	•	Premium: opprette P2P-kanaler; gratis kan følge/lese.
	•	Sanntid media
	•	WebRTC lyd/video (SRTP) for 1:1 + smårom; TURN-infrastruktur i EU.
	•	“View-once” media + skjermforheng-motor (opt-in).
	•	Milestone
	•	Stabil P2P-kanal med hundrevis av abonnenter.
	•	1:1 video med god QoE (packet loss resilience).

Fase 5 – Bedrift Pro & On-Prem

Mål: Enterprise pipeline uten å kompromittere personvern.
	•	Bedrift Pro
	•	Full RBAC, SSO (AzureAD/Google), arkivpolicy, hold/legal.
	•	On-prem/dedikert instans (helm chart, terraform moduler).
	•	AI-sammendrag/Q&A on-prem (lokale modeller, RAG over godkjente kanaler).
	•	Milestone
	•	Første on-prem kontrakt (offentlig/helse/jus).
	•	Security review/pen-test rapport offentliggjort.

⸻

Epics og leveransekrav (DoD)

Epic	Nøkkelleveranser (DoD)
E2EE-kjerne	Double Ratchet lib integrert; kryptert 1:1 & gruppe; nøkkelrotasjon; device bind/unbind med QR; testvektor-suite; fuzzing.
Historikksynk	Kryptert device-to-device over nærhet/QR; progress-resume; integritet (per-blob merklerøtter).
Profiler & Moduser	Én konto, flere profiler; modus-banner/tema; policy-motor (PIN/biometri, notif-regler, DND-vindu).
Media & Lagring	Pre-signed upload/download; thumbnailer server-side; E2EE-fildeling med nøkkelwrapping pr mottaker.
Kanaler	Signerte posts; moderatorverktøy; offentlig/privat; feed-API; cross-post (rate-limit, retry, audit-log).
Notifikasjon-ML	On-device scoring; “viktig nå” vs “samle senere”; opt-in; eval-metrics (precision/recall).
Gateways	Slack webhooks + Telegram bot; modulært bro-API; queue + retry + idempotens; audit & ToS-kompat.
P2P / DHT	Keyspace, announce/discovery; chunked CRDT/append-only log; NAT-traversal; disk-kvote; abuse-kontroll.
SRTP/WebRTC	TURN (EU); kodekvalg; jitter buffer; E2EE-innen SRTP/SFrame; nettverkstest diag.
Admin/Team	Workspace, roller, gjester, import; enkel fakturering; aktivitets- og sikkerhetslogg.
On-Prem	Helm/ArgoCD; SSO/SAML; secrets-rotasjon; observability; drift-runbooks.


⸻

Satsingsområder (de 5 viktigste “bets”)
	1.	Én konto, flere profiler/moduser (jobb/privat)
– Skiller oss i hverdagsbruk; løser “to apper”-problemet uten forvirring.
	2.	Historikksynk E2EE mellom egne enheter
– Praktisk smertepunkts-løsning som selv Signal/WhatsApp sliter med i praksis.
	3.	Norsk/EU personvern som kjerne
– Dataplacering Norge/EU, null sporing, klare garantier/whitepaper.
	4.	Interop/DMA readiness
– Broer og API-modularitet så vi raskt kan “snakke” med de store lovlig.
	5.	P2P-kanaler (premium)
– Sensur-robust, unik posisjonering; betalt for skapere/avanserte brukere.

⸻

Produktpakker og prising (skisse)
	•	Gratis (Privat): E2EE 1:1/gruppe, media, én ekstra enhet, “chat med meg selv”.
	•	Premium (Privat): Flere enheter, historikksynk uten friksjon, AI-varsler, view-once, temaer, opprette P2P-kanal.
	•	Team (SMB): Workspace, gjester, import, grunnleggende admin. Pris per bruker/mnd.
	•	Pro/Enterprise: RBAC, SSO, arkiv/hold, on-prem, SLA, lokal AI. Forhandles.

⸻

Mål/KPIer per fase
	•	Fase 1 (MVP):
	•	30-dagers retention > 35% i pilotkohort.
	•	Crash rate < 1%, P99 send→mottak < 600 ms (nasjonalt).
	•	Fase 2:
	•	50% færre “mute”-handlinger pga AI-varsler; ≥5 offentlige kanaler med >1k følgere.
	•	Fase 3:
	•	≥5 betalende SMB’er; ≥20% av aktive brukere bruker minst én gateway.
	•	Fase 4:
	•	P2P-kanal uptime > 99% (målt som tilgjengelighet av ferske chunks); 1:1 video MOS ≥ 4.0.
	•	Fase 5:
	•	1 on-prem kunde; bestått ekstern pen-test uten kritiske funn.

⸻

Risiko & mitigasjon (kort)
	•	Interop juridikk drøyer → bygg verdi uten, prioriter Slack/Telegram først (lovlige APIer).
	•	Kompleks UX → modus/profil “progressive disclosure”; brukertesting hver sprint.
	•	Skaleringskost → EU-Edge + MinIO/Cold storage; medie TTL; dedup; båndbredde budsjett.
	•	Sikkerhet/press → offentlig sikkerhetsark, bug bounty, norsk tilsynsdialog, tydelig anti-CSA scanning-standpunkt (opt-in familieprofiler som alternativ).

⸻

Neste steg (konkret 4–6 ukers byggesett uten tidsløfter)
	1.	Teknisk “spike”: Double Ratchet + Noise-kanal + Flutter prototype (1:1 tekst).
	2.	Profil/Modus UX: interaktiv Figma + Flutter theme system + policy motor.
	3.	Historikksynk PoC: QR bootstrap, lokal tunnel, chunked kryptert overføring.
	4.	EU-lagring: MinIO/S3 oppsett, pre-signed flows, media pipeline.
	5.	Pilotkohort: 20–50 norske testere (familier/klasse/lag) med enkel feedbacksløyfe.

Hvis du vil, kan jeg også lage en “architecture.md” + “product-spec.md” med sekvensdiagrammer (nøkkelstrømmer: nøkkelutveksling, historikksynk, profilbytte) og en første issue backlog i tabellform klar til å klistre inn i GitHub.
