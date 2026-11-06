# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

browser-everywhere: macOS-only bash scripts that run ttyd (terminal) and VS Code (`code serve-web`) as launchd login services, served on `localhost` through Caddy, so they open as browser tabs. No build step, no tests, no dependencies beyond Homebrew (ttyd, Caddy) and VS Code.

## Commands

- `./install.sh` — install or reinstall (idempotent, no sudo). Re-running restarts ttyd, which kills any browser terminal tabs, so don't run it from one.
- `./uninstall.sh` — remove services, shortcuts and `~/Library/Application Support/browser-everywhere/`.
- `bash -n <file>` — syntax check; there is no test suite.
- Service logs: `~/Library/Application Support/browser-everywhere/logs/<name>.log`.
- Ports can be overridden with `BROWSER_EVERYWHERE_TTYD_PORT` / `BROWSER_EVERYWHERE_CODE_PORT`.

## Architecture

- `install.sh` / `uninstall.sh` both source `config.sh`, which defines helpers (`say`, `fail`) and the registration functions `module`, `proxy`, `shortcut`, then sources each module listed in `modules/definition` (in order). Registration fills parallel arrays (`MODULES`/`LABELS`/`TITLES`, `PROXY_PORTS`/`PROXY_SOCKETS`/`PROXY_OWNERS`, `SHORTCUTS`/...) that the scripts iterate over.
- When piped from `curl | bash` (no `config.sh` beside the script), each script downloads the repo tarball to a temp dir and re-execs itself from there. That path always uses the repo's own `modules/definition`.
- `install.sh` phases: every `<name>_find` runs first (before anything running is stopped) → shortcut-collision check → `launchctl bootout` own services → verify proxy ports free → create `$SUPPORT` (chmod 700) → every `<name>_setup` (each calls `write_agent` once) → `launchctl bootstrap` all → wait for each socket and port → write `~/.local/bin` shortcuts → print `<name>_info` (or a default line).
- Security model: Caddy (`modules/caddy.sh`) is the only thing on a TCP port, bound to `127.0.0.1`. It rejects non-localhost `Host` (DNS rebinding) and foreign `Origin` (CSRF / cross-site WebSocket) with 403, sets `X-Frame-Options`, and reverse-proxies to unix sockets in `$SUPPORT`. Services never listen on ports and use no passwords/tokens; the 700 support folder is what keeps other local users off the sockets. Keep this invariant when changing things.
- Shortcut scripts carry `SHORTCUT_MARK`; install/uninstall only overwrite or delete files containing it.

## Module rules (full interface in `modules/README.md`)

- A module is `modules/<name>.sh`: calls `module NAME LABEL TITLE`, optionally `proxy PORT SOCKET` and `shortcut COMMAND URL HELP`, and defines `<name>_find`, `<name>_setup`, optionally `<name>_info`.
- Loading a module must have no side effects (uninstall loads them too, possibly after the program is gone). Only set vars, define functions and call the registration functions at top level.
- Target macOS `/bin/bash` 3.2 under `set -euo pipefail`: no `declare -A`, `${var^^}`, `mapfile`, or unset variables.
- Prefix module variables with uppercase `NAME_`; all modules share one namespace.
- Socket paths are relative to `$SUPPORT` and must stay short (~100-char macOS limit). Services run with `$SUPPORT` as working directory.
- `modules/definition` must list `caddy` plus at least one service. Removing an installed module from it requires booting out its service first, or it keeps running (see `modules/README.md`).
- Module-specific text belongs in the module (e.g. `_info`), not in `install.sh`.
