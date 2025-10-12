# Snapchat Recorder Detection Notes

## Hva skjedde?
Før vi la til stealth/camouflage i `official_client_recorder` ble Puppeteer kjørt «rett fra boksen». Snapchat-klienten har flere mekanismer for å avsløre automatisering, og kombinert utløste disse et app‑crash idet recorderen åpnet webklienten. Etter at vi hardet recorderen fungerte sesjonene igjen, noe som stemmer med at det var fingerprinting – ikke selve nettverkstrafikken – som ble oppdaget.

## Sannsynlige deteksjonsvektorer
- **`navigator.webdriver = true`**  
  Standard Puppeteer setter alltid `webdriver`‑flagget. Snapchat kan sjekke dette tidlig og avslutte appen når den oppdager automatisering.
- **Manglende `window.chrome` og plugin‑liste**  
  I «ekte» Chrome finnes `window.chrome` samt minimum tre plugins (Chrome PDF, PDF Viewer, NaCl). Puppeteer eksponerte ingen plugins og `window.chrome` var `undefined`.
- **Urealistisk fingerprint (språk, timezone, CPU, touch)**  
  Vi meldte alltid `en-US`/`HeadlessChrome` kombinasjoner uten å variere maskinprofil. For en norsk konto med tidligere profiler lagret server‑side, blir avvik i `navigator.languages`, `navigator.platform`, `hardwareConcurrency` osv. mistenkelige.
- **Tilgang til DevTools‑spesifikke API-er**  
  Uten stealth plugin er flere `permission.query`, WebGL- og WebRTC‑felter i «blank» eller Puppeteer-spesifikke tilstander. Snapchat bruker slike sonder for å bygge en «bot score».
- **Chrome‑flagg**  
  Recorderen startet med Puppeteers default‑flagg: `--disable-features=IsolateOrigins,site-per-process`, `--enable-logging`, `--disable-web-security`. Kombinasjonen er svært sjelden i sluttbrukerprofiler og kan trigge heuristikk på server/klientside.

## Endringene som løste problemet
- Vi byttet til `puppeteer-extra` med **stealth plugin** slik at `navigator.webdriver`, `permissions.query`, WebGL mm. ser legit ut.
- Vi introduserte **camouflage-profiler** som setter konsistente user agent, språk, timezone, viewport og maskinvareparametere.
- Chrome startes nå uten ekstra flagg med mindre de eksplisitt oppgis, og standard user agent beholdes (ingen `HeadlessChrome`).

Sammen gjør dette fingerprintet nesten identisk med vanlige skrivebords-sesjoner, og Snapchat sluttet å terminere appen under opptak. Skulle Snapchat stramme inn ytterligere anbefales det å kjøre via en ekte Chrome‑brukerprofil (`--user-data-dir`) for å gjenbruke cookies, service workers og eksakt modul‑sett.***
