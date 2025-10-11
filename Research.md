# Research – chat-opplevelse, identitet og markedsfokus

## 1. Hvorfor en norsk chat-app nå
- **Regulatorisk medvind**: Digital Markets Act krever interoperabilitet fra gatekeepere (WhatsApp, Messenger, iMessage) → lavere nettverkseffekt-barrierer.
- **Etterspørsel etter lokalt personvern**: Eksempler som Hudd viser at norske brukere velger tjenester med data i Norge og uten reklameprofilering.
- **Konkurransebildet**: WhatsApp, iMessage og Messenger dominerer globalt, men europeiske alternativer (Threema, Olvid) vokser i nisjer. Differensiering må komme gjennom UX, identitet og tillit.

## 2. Identitet: én konto, flere profiler/moduser
- **Brukerjobb**: Folk hater å hoppe mellom Slack/Teams/privat-apper. En global konto med profiler (Jobb, Privat, Familie) gir klar separasjon uten flere innlogginger.
- **Implementasjon**: Kombiner UUID/ULID som konto-id med profiler som egen tabell knyttet til konto. Policy-felt for krav (PIN, skjerming, notif-regler). Fargetema og UI-banner for tydelig kontekst.
- **Autentisering**: Start enkelt (magiske lenker / SMS). Planlegg for BankID/Vipps/Passkey som valgfritt nivå 2. Sørg for at API alltid tar både konto-id og aktiv profil-id.

## 3. Chat-opplevelse “som føles awesome”
- **Composer**: Moderne chat-apper investerer i inputfeltet. Viktige elementer:
  - Reaksjoner, emoji-picker, hurtigkommandoer (`/giphy`-stil), opplastingsknapp.
  - Preview av filer/lenker før sending.
  - Mulighet for å skrive flere linjer med auto-grow, men lett å sende (Enter = send, Shift+Enter = ny linje).
  - Typing-indikator og “draft saved”-feedback.
- **Visuell design**:
  - Bobler med tydelig kontrast, runde hjørner, diskret tidsstempel.
  - Sticky dag-separatorer og “nytt siden sist”-markør.
  - “Floating” send-status (sender → levert → lest) med animasjoner.
- **Respons og ytelse**: P95 tid fra send til visning under 500 ms nasjonalt. Optimér for lave rebuilds i Flutter (`ListView.builder`, `AnimatedList`, `ValueListenableBuilder`).

## 4. Teknologivalg
- **Backend**: Phoenix + Postgres gir rask produktivitet, innebygd PubSub/WebSockets. Channels for sanntid, Ecto for migrations/testbarhet. Alternativ (Go + NATS) vurderes senere for spesialiserte tjenester.
- **Frontend**: Flutter gir samme kodebase for mobil/web/desktop. For chat bør vi bruke:
  - `ChangeNotifier` + `provider` for UI-nær state (snappere iterasjon enn Redux).
  - `scrollable_positioned_list` eller `ScrollablePositionedList` for store historikker.
  - CustomPainter for tastatureffekter hvis vi lager “floating composer”.

## 5. Markedssegmenter å angripe først
1. **Familier og foreldregrupper**: Fortsett Hudd-case – privat, reklamefri kommunikasjon, barns trygghet.
2. **Frilansere og små team**: Ønsker å separere jobb/privat. Selg på personvern + alt-i-ett.
3. **Communities/skapere**: Kanaler med moderering, deling til andre nettverk, mulighet til å ta betalt.

## 6. Risiko og tiltak
- **Kompleksitet**: Funksjonsoverflod = dårlig UX. Tiltak: modulær leveranse, “progressive disclosure”, test med brukere hver sprint.
- **Interoperabilitet**: Avhengig av DMA-implementasjon. Fokusér først på egen verdi (chat, profiler) og legg inn modulært “gateway”-lag.
- **Sikkerhet**: Høy profil gir press (myndigheter, ondsinnede). Bygg åpen sikkerhetsarkitektur, plan for tredjepartsrevisjon og bug bounty.
- **Kostnader**: Media og real-time er dyrt. Start i EU-sky med mulighet for MinIO og kaldlagring. Overvåk båndbredde/buffer.

## 7. Designprinsipper for produktet
1. **Tillitsbasert**: Forklar hva som skjer med data, open source kritiske komponenter når mulig.
2. **Modus-først**: UI skal alltid fortelle deg hvor du er (Privat/Jobb osv.).
3. **Hurtig interaksjon**: Alt vanlig chat-bruk krever maks to trykk.
4. **Skalerbar arkitektur**: Tenkt for senere E2EE, multi-device, bridging.
5. **Kvalitetsbarometer**: Crash-rate <1 %, P95 send<500 ms, onboarding < 2 min.

## 8. Neste forskningsoppgaver
- Kartlegg beste praksis for Flutter chat-performance (f.eks. `flutter_chat_ui`, Matrix, Slack clones).
- Evaluer existing open-source Double Ratchet implementasjoner i Elixir (f.eks. `pigeon` vs bindinger til libolm).
- Finn norske/EU hostingleverandører med datasuverenitet + backup.
