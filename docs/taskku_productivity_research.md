# Research – Taskku Productivity App for Msgr Business Mode

## Overview
- **Repository**: [`KratosOfficial/Taskku-Productivity-Mobile-App-`](https://github.com/KratosOfficial/Taskku-Productivity-Mobile-App-) provides a polished Flutter UI targeting productivity workflows with tabs for Home, Calendar, Task Detail, and Settings.
- **Design language**: Clean monochrome palette with green accents, rounded cards, and icon-forward navigation that matches the mockups the team referenced.
- **Technology**: Built with Flutter (`sdk >=2.17.5 <3.0.0`) and packages like `nb_utils` (UI helpers) and `percent_indicator` (progress widgets); data is currently static demo content defined directly in the widgets.

## Feature Breakdown
### Home (Dashboard)
- Horizontal carousel of "ongoing" projects with deadline, summary, and description blocks suitable for surfacing team assignments.
- Daily activity list that mixes completed and upcoming sub-tasks, implying support for per-task status badges and checkmarks.
- Quick search affordance in the header alongside avatar, title, and overflow actions that can map to Msgr profiles/personas.

### Calendar View
- Weekly strip calendar with highlighted current day, floating action button for new events, and schedule list showing time slots, descriptions, and circular completion indicator (e.g., 50% done).
- Layout uses progress meters to combine timeboxing with completion state, matching the need for team stand-ups or shared agenda tracking.

### Task Detail
- Hero section with task title, assignee avatar, and parent project category, followed by description text and a "Files & Links" block (two tile placeholders today).
- Checklist rendering supports completed (strikethrough + green check) and pending (outlined circle) subtasks, ready to connect to Msgr todo endpoints.

## Fit with Msgr Platform
- Msgr already models shared spaces with calendar, shopping, notes, and todo APIs (including assignees and status updates), so the Taskku UI can be powered without new backend endpoints by binding to those resources.【F:docs/api_contract.md†L176-L377】
- Persona/modus separation (one account, multiple profiles like Jobb/Privat) lets us scope the Taskku-inspired productivity surface to business mode while keeping personal chats uncluttered.【F:Research.md†L8-L33】
- Bridge strategy leverages queue-driven daemons and persona impersonation for Slack/Discord, meaning Taskku-style panels can later surface bridged data without changing the UI shell.【F:docs/bridge_strategy.md†L1-L44】

## Separation from Core Chat
- **UI guardrails**: Keep chat as the primary landing experience (per produktplanens "Chat-opplevelse først" prinsipp) and expose productivity views through an explicit "Productivity" entry in the space switcher or a secondary tab. That makes it trivial to hide the module in spaces hvor den ikke er aktivert without disturbing conversational flows.【F:PLAN.md†L41-L53】
- **Feature modularity**: Ship the Taskku-inspired widgets as a distinct Flutter feature package with its own navigation route, view models og providers, aligned with forskningsanbefalingen om modulær leveranse for å begrense funksjonsoverflod. Dette gjør det mulig å koble hele flaten ut via feature-flag eller build-time toggles når vi evaluerer bedriftsmodusen.【F:PLAN.md†L27-L34】【F:Research.md†L35-L40】
- **Backend toggles**: Modellér produktivitetsfunksjoner som valgfrie kapabiliteter knyttet til `spaces`, f.eks. gjennom en `space_features`-tabell som henter `space_id` og beskriver hvilke moduler som er på. Det matcher dagens datastruktur der kalender, handleliste og todo allerede lever som egne tabeller under en space, så chat-tjenesten kan leve uforstyrret dersom modulene deaktiveres.【F:backend/apps/msgr/priv/repo/migrations/20241004123000_create_families_and_events.exs†L1-L83】

## Implementation Notes
- Replace Taskku's hard-coded demo data with Msgr GraphQL/REST fetches; consider a `ProductivityController` that hydrates cards from `/spaces/{id}/todo_lists`, `/calendars`, and `/notes` once those endpoints land in the Flutter client.
- The Flutter code relies on asset-based icons and static layout; porting the visuals means extracting them into reusable widgets aligned with our design system (theme-aware colors, typography tokens, responsive layout rules). Reference `frontend_responsive.md` while doing this.
- Calendar progress indicator can connect to Msgr task completion percentages by aggregating todo status fields, enabling the same circular progress visuals.
- Ensure moduskontekst banners and guardrails from the main app remain visible so users always know they are in "Jobb" space when productivity widgets show.

## Suggested Next Steps
1. Build a prototype "Productivity" tab in business spaces using Msgr's existing REST contract for todo lists and events, matching Taskku's card layout.
2. Define data mappers to translate Msgr task models into the visual building blocks (project card, daily agenda item, subtask checklist).
3. Audit asset licensing or recreate icons to avoid shipping Taskku's proprietary artwork; drop replacements into our shared icon set.
4. Validate responsive behavior on tablet/desktop using the guidelines in `frontend_responsive.md` to ensure the layout scales beyond mobile.
5. Plan integration tests that load sample productivity data and verify rendering, so the module ships with coverage from day one.
