# Plan for å forbedre Flutter-arkitekturen

Dette dokumentet beskriver et foreslått veikart for å modernisere Flutter-klienten i `flutter_frontend`.
Planen tar utgangspunkt i dagens kodebase (Redux-drevet monolitt med blandet ansvar) og skisserer
et målbildet der vi går over til en modulær, feature-basert struktur med tydelig lagdeling og mer
forutsigbar state-håndtering.

## 1. Målbilder og prinsipper

* **Feature-first struktur:** Samle UI, presentasjonslogikk og tilhørende data-/domeneabstraksjoner
  under hver feature (f.eks. `chat`, `profile`, `spaces`). Delte komponenter flyttes til
  `shared/`.
* **Lagdeling:** Skille mellom *presentation* (widgets og state), *application/domain* (use cases,
  businessregler) og *data/infrastructure* (API-klienter, lagring). Hver feature får en
  `presentation/`, `domain/` og `data/` mappe.
* **Dependency flow innover:** Presentasjonslaget refererer til domain/use cases, domain avhenger av
  abstrakte repositorier, og data-laget implementerer disse. Delte services (krypto, logging,
  lokale caches) eksponeres via grensesnitt og injiseres.
* **Testbarhet:** Alle use cases og repositorier skal ha egne enhetstester; widgettester for viktige
  skjermbilder. Skriv golden-tester for kritiske komponenter (eks. meldingsbobler).
* **Plattformparitet:** Desktop-/web-/mobil-entrypoints skal kun boote DI + root widget; alt annet
  ligger i feature-modulene.

## 2. Nå-situasjon (observasjoner)

* `lib/main.dart` tar ansvar for logging, dependency init og platform branching direkte.
* `lib/redux/` inneholder både *actions*, *reducers*, presentasjons-helpers og persistens.
* `lib/services/` og `lib/utils/` brukes bredt uten DI, noe som gjør koden vanskelig å teste.
* `features/chat` er den eneste tydelige feature-mappen; andre konsepter (profil, navigasjon,
  autentisering) ligger i `redux/` eller `ui/`.
* Kode fra `libmsgr` eksponeres direkte inn i widgets uten en tydelig adapter.

Dette gjør det krevende å legge til nye features, fordi alt kobles mot global Redux-state og
services. Migreringen bør redusere global coupling og gjøre det enklere å teste.

## 3. Foreslått mappe- og modulstruktur

```
lib/
  app/
    bootstrap/        # main(), konfig, DI, theming
    router/           # Navigator 2.0 / GoRouter config
    env/              # miljøspesifikk konfig
  core/
    analytics/
    crypto/
    error/
    http/
    storage/
    utils/
  shared/
    widgets/
    theme/
    localization/
    extensions/
  features/
    chat/
      data/
        models/
        dtos/
        mappers/
        repositories/
      domain/
        entities/
        value_objects/
        usecases/
      presentation/
        controllers/   # Riverpod/StateNotifier/BLoC
        widgets/
        pages/
        routing.dart
    profile/
    auth/
    spaces/
    notifications/
```

*Flytt eksisterende `redux`-mappe til `features/` + `app/` gradvis.*

## 4. State management-strategi

1. **Kort sikt:** Trekk ut Redux-store til et «legacy»-lag (`legacy/redux/`) og bygg nye features med
   Riverpod (`hooks_riverpod` eller `riverpod_annotation`). Bruk `StateNotifier` for kompleks state
   og `AsyncValue` for async-håndtering.
2. **Mellomlang sikt:** Erstatt Redux-actions/reducers med Riverpod-providers og use cases per
   feature. Lag adaptere som lar ny state lese/skrive til gammelt store under migreringen.
3. **Lang sikt:** Fjern Redux og bruk modul-spesifikke Riverpod-skop. For desktop/web kan vi bruke
   `ProviderScope(overrides: [...])` for å injisere alternative repo-implementasjoner.

## 5. Data- og nettverkslag

* Opprett `core/http` med HTTP-klient abstrahert over `libmsgr`/gRPC/REST.
* Definer `Repository`-interfaces i domain-laget (f.eks. `ChatRepository`). Implementasjonene i
  `data/` bruker `libmsgr` og mapper DTO ↔ domain-objekter via `freezed` + `json_serializable`.
* Introducer cachinglag (lokal DB via `drift` eller `isar`) bak repositoriene for offline-støtte.
* Sørg for at alle nettverkskall går via interceptors som legger på logging, auth og retry-policy.

## 6. Navigasjon og routing

* Flytt `AppNavigation` til `app/router/` og bygg en deklarativ router (GoRouter/Beamer). Hver
  feature eksponerer egne `RouteConfig`-objekter som plugges inn i root-router.
* Definer typed arguments og deeplinks via `RoutePath`-klasser. Test routing med
  `router.neglect()` + widgettester.

## 7. Dependency Injection

* Bruk `riverpod` for DI og `ProviderContainer` i tester.
* Alternativ: `get_it` + `injectable` dersom Riverpod ikke ønskes til alt; men Riverpod løser både
  state og DI.
* Lag `app/bootstrap/bootstrapper.dart` som registrerer base-repositorier, services og logger.
  `main_*.dart` kaller kun `Bootstrap.run(environment: ...)` og `runApp(const App());`.

## 8. Migrasjonsveikart

1. **Forberedelse**
   * Opprett `app/`, `core/`, `shared/` mapper og flytt eksisterende helpers.
   * Lag `legacy/` mappe for Redux og referer midlertidig.
   * Sette opp `riverpod` og `freezed` i `pubspec.yaml`.
2. **Feature-by-feature**
   * Chat: modeller domain entities (`Conversation`, `Message`, `Participant`). Lag repositorier og
     use cases (send message, load history). Re-implement UI med Riverpod providers.
   * Auth/Profile: Skil ut login-flow, profilbytte, moduser med egen state + navigation guard.
   * Notifications: modul for push/overlay, isolert logikk for in-app notifikasjoner.
3. **Felles concerns**
   * Logging: Flytt OpenObserve-klient til `core/logging`. Lag adapter for structured logs.
   * Config: Saml environment-variabler i `app/env` med `EnvConfig`-modell.
   * Error handling: Lag global `Failure`-hierarki og `Either`/`Result`-typer med `sealed` klasser.
4. **Redux avvikling**
   * Lag bridging-lag slik at `legacy`-widgets kan lese Riverpod data.
   * Fjern reducers etter hvert som features migreres.
5. **Testing og kvalitetsgates**
   * Sett opp `melos` eller `very_good_workflows` for monorepo multi-package testing.
   * Krev minst én widgettest + én use case-test per nye feature modul.

## 9. Infrastruktur og tooling

* **Melos:** Ta i bruk `melos` for å orkestrere packages i `flutter_frontend/packages` og nye
  modulære pakker (f.eks. `packages/chat_domain`).
* **Linting:** Oppdater `analysis_options.yaml` til å inkludere `riverpod_lint`, `lint`, `pedantic`.
* **CI:** Oppdater Jenkins/pipeline til å kjøre `flutter analyze`, `dart test`, `flutter test` og
  format-sjekk (`dart format --output=none --set-exit-if-changed`).
* **Codegen:** Standardiser på `build_runner` for `freezed`/`json_serializable`. Legg til `make`-
  target for `dart run build_runner watch --delete-conflicting-outputs`.

## 10. Milepæler og estimert effekt

| Milepæl | Beskrivelse | Effekt |
| ------- | ----------- | ------ |
| M1 | Opprett basisstruktur + Riverpod integrert | Modulær bootstrap, lettere testing |
| M2 | Chat migrert til feature-modul | Redusert Redux-avhengighet, bedre ytelse |
| M3 | Auth/Profile modul ferdig, navigasjon oppdatert | Konsistent login/modusflyt |
| M4 | Legacy Redux fjernet | Lavere kompleksitet, enklere on-boarding |

Med denne planen får vi en Flutter-klient som er enklere å teste, vedlikeholde og utvide, og som
matcher moderne Flutter-praksis.
