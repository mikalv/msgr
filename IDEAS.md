# IDEAs

## Eksperimentstatus

| Idé | Scope | Status | Frontend? | Backend? | Notater |
| --- | --- | --- | --- | --- | --- |
| Pay-per-feature aktivering | Økosystem/prising | Discovery (2025-05-09) | Nei | Ja | Krever abonnementshåndtering, feature-flags og fakturering via backend. |
| Passkeys for pålogging | Autentisering | Discovery (2025-05-09) | Ja | Ja | Avhenger av WebAuthn-planen, Flutter-passkey-SDK og nye autentiseringsendepunkt. |
| QR-koder for familie/workspace-invitasjoner | Onboarding/deling | Backlog | Ja | Ja | Trenger QR-rendering i klienten og signerte invite-tokens i backend. |
| Quiz/Vote meldingsformat | Meldinger/engasjement | Discovery (2025-05-09) | Ja | Ja | Frontend trenger komponenter for stemmegivning, backend må samle stemmer og emitte resultater. |

Statusfeltet skal oppdateres når eksperimenter starter eller ferdigstilles. Se `CHANGELOG.md` for historikk.

## General

* Hva med pay per feature?
  * altså, f.eks for calendar
  * for quiz melding
  * etc..
  * health check (for it bedrifter, deres space)
* webrtc video
* public annonser? (finn.no)
* shared expenses? https://flutterawesome.com/shared-expenses-management-system-built-on-top-of-nestjs-and-flutter/

* [ ] - News (nyhetskanaler o.l. basert på RSS etc) for å skape liv i et ellers dødt sted i starten.
* [ ] - Ekstra apps:
  * [ ] - https://github.com/Devitplps/Daily-Task-Manager
  * [x] - Calendar
  * [ ] - Notes
  * [ ] - Handlesliste/TODO liste ( https://flutterawesome.com/snoozed-app-a-focus-oriented-to-do-list-with-skippable-tasks/ )

## Frontend

* Her er hvordan vi kan få passkeys til å funke i flutter: https://github.com/corbado/flutter-passkeys.git

* Workspaces burde ha noe ala; https://github.com/AppFlowy-IO/appflowy?tab=readme-ov-file

* Image cropping https://flutterawesome.com/an-image-cropper-widget-for-flutter/
* payment https://flutterawesome.com/flutter-nhn-payment-plugin-widget/

https://flutterawesome.com/an-open-source-cross-platform-alternative-to-airdrop/
https://flutterawesome.com/a-flutter-project-which-can-display-beautiful-graph-data-structure/
https://flutterawesome.com/a-modern-task-app-design-with-flutter/
https://flutterawesome.com/a-flutter-package-that-lets-you-notify-users-of-a-new-feature-in-your-flutter-app/
https://flutterawesome.com/one-to-one-video-call-using-callkit-and-pushkit-with-flutter-ios-app/
https://flutterawesome.com/application-to-extract-personal-information-from-id-card/

* [ ] - Image editor messsage "drafting" https://flutterawesome.com/image-editor-app-built-with-flutter/
* [ ] - Tegnebrett https://flutterawesome.com/a-simple-drawing-app-made-with-flutter/
* [ ] - Familie space - notes!! https://flutterawesome.com/note-app-both-frontend-and-backend-created-with-flutter-and-firebase/
* [ ] https://flutterawesome.com/a-flutter-package-that-let-you-draw-a-flow-chart-diagram-with-different-kind-of-customizable-elements/

* [ ] - Latex support in markdown messages
  * [ ] - Pick a library
https://flutterawesome.com/a-lightweight-tex-plugin-for-flutter-based-on-katex/
https://flutterawesome.com/a-tiny-tex-math-engine-written-in-dart/

* [ ] - Scan or Generate QR code for familie og work spaces. https://flutterawesome.com/a-simple-use-case-approach-to-scan-and-generate-qr-codes-using-flutter/

* [ ] - Recording av lydmelding burde kunne gjøre dette: https://flutterawesome.com/a-flutter-package-for-trimming-audio/
* [ ] - Onboarding https://flutterawesome.com/awesome-onboarding-screen-with-flutter/

* [ ] - Local network, GPS etc to suggest new contacts
* [ ] - Quiz / vote / choise message
* [ ] - Kanskje en bottom bar noe ala dette? https://github.com/thisiskhan/thebrioflashynavbar
* [ ] - Og kanskje noe ala slik sidebar i workspace mode? https://github.com/BenjaminMahmic/collapsible_drawer

## Backend


* [ ] - Vi må forvente at av og til skal en pålogging skje via nettleser (f.eks google IDP, logge på med webauthn)
  * [ ] - Så et system hvor server kan pushe OK du er innlogget til client etter at en nettleser påloggingsøkt er fullført i en "uavhengig nettleser" i forhold til appen.
