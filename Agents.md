# Agent Notes

- **Key norms:**
  - Prefer `rg`/`ripgrep` for search; always set `workdir` on shell commands.
  - Use `apply_patch` for single-file edits (no parallel tool use).
  - Avoid non-ASCII unless file already uses it; keep comments concise.
  - Never revert user changes or run destructive git commands unless instructed.
  - Skip plan tool for trivial work; otherwise keep multi-step plans updated.
  - Every meaningful change must be reflected in `CHANGELOG.md`.
  - Keep files small: refactor if any file approaches 2 000 lines (ideally <1 000 lines / 1 000 characters per file); split logic rather than letting files grow. Use subdirectories if needed.
  - Aim for “medium” documentation density: brief but useful doc comments on non-trivial functions, modules, and public APIs.
  - Application code and public documentation must remain in English, even if the request comes in Norwegian (translate as needed).
  - Keep agents.md updated with information considered critical to know
  - It's better with big changes rather than "should I continue?" for each little detail.
  - Always check for syntax error / compile errors
  - Tests when possible
  - Source code files should have a top comment explaining what the file does, this should be kept updated
  - Be very careful to delete or remove files and directories

Use this file as a quick refresher before diving back into the repo.

## All programming languages

* Indent is defaulted to 2 spaces. Use this unless file use other indent from before. New files is always 2 spaces.
* CamelCase over underscore_functions.

## Python

* Indent is defaulted to 2 spaces.
* `uv` er dependency mgmt verktøyet vi skal bruke

## Rust

* Use `dbg!` for debugging
* When you really have to mark a TODO, don't do it as a comment but as `todo!("Whaterver")`

## Dart

* Always check code with analyze

## TODOs

OM du MÅ lage TODOs, dokumenter også alle til `TODO.md` så vi ikke glemmer av de. Men prøv å unngå de i det store og hele. vi liker å gjøre alt skikkelig med en gang.

## AI skeptisism

Do not place or leave AI traces in this repository. I would lovely give you credit, but the software wouldn't be trusted by the public then.

## Windows

Use powershell for commands, never cmd.exe.

