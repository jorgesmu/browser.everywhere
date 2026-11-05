# Modules

Each service that app-web runs as a login service (a launch agent) is a module: one file, `modules/<name>.sh`. `config.sh` loads the modules listed in `modules/definition`, in that order. Both `install.sh` and `uninstall.sh` load them.

## Adding a module

1. Create `modules/<name>.sh` (outline below).
2. Add `<name>` on its own line in `modules/definition`. Modules start in the order they're listed. Blank lines and `#` comments are skipped.

## The interface

Every module file has three parts.

### Registration (runs when the file is loaded)

```bash
module NAME LABEL PORT TITLE
```

| Argument | Meaning | Example |
|---|---|---|
| `NAME`  | Must match the file name. It's the prefix for the two functions. | `code` |
| `LABEL` | The launchd label. It's also the plist name: `~/Library/LaunchAgents/<LABEL>.plist`. | `local.code` |
| `PORT`  | The localhost port the service listens on. Install checks that it's free before starting, then waits until something is listening on it. | `8000` |
| `TITLE` | The name shown in messages, such as "VS Code didn't start on port 8000". | `"VS Code"` |

Name module-specific variables with an uppercase `NAME_` prefix (`CODE_LABEL`, `CODE_PORT`). Every module's variables share one namespace, and install's `.zshrc` block reads some of them directly.

### `<name>_find`: check that the program is there

```bash
<name>_find()
```

- **Called by:** `install.sh` only. It runs for every module **before** any running service is stopped.
- **Job:** find the program the service runs, or install it (e.g. with Homebrew). Store its path in a global, usually `NAME` (`CODE`, `TTYD`), for `_setup` to use.
- **On failure:** call `fail "message"`. Install stops before it touches anything, so the services already running keep running.
- **Must not:** write to `$SUPPORT` or `$AGENTS`. They may not exist yet.

### `<name>_setup`: write the files and the launch agent

```bash
<name>_setup()
```

- **Called by:** `install.sh` only, once every `_find` has passed, the old services are stopped, every module's port is free and `$SUPPORT` exists.
- **Job:**
  1. Create any secrets or helper files the service needs in `$SUPPORT`. Keep existing secrets on re-runs (`[ -s file ] || create`), and create them with `umask 077`.
  2. Call `write_agent` exactly once, with the module's `LABEL`.
- **Does not need to:** start the service. Install starts every agent (`launchctl bootstrap`) and then waits for each `PORT`.
- **May set globals** that install's final message uses (as `ttyd_setup` does with `TTYD_USER` and `TTYD_PASS`).

```bash
write_agent LABEL LOGNAME PROGRAM [ARG...]
```

`write_agent` writes `$AGENTS/<LABEL>.plist`, readable only by you. The service:
- starts at login and restarts if it crashes;
- runs `PROGRAM ARG...` with `$SUPPORT` as its working directory, so `./file` means `$SUPPORT/file`;
- logs to `$SUPPORT/logs/<LOGNAME>.log`;
- gets `PATH` (Homebrew first), `SHELL` and `LANG` as its environment.

## What a module can use

| Name | What it is |
|---|---|
| `$SUPPORT` | `~/Library/Application Support/app-web`, readable only by you. Holds secrets, helper files and `logs/`. |
| `$AGENTS`  | `~/Library/LaunchAgents` |
| `$ROOT`    | The repo folder |
| `say MSG`  | Prints a progress line |
| `fail MSG` | Prints an error and exits |
| `write_agent` | Only inside `_setup`; see above |

## Rules

- **Loading a module must have no side effects.** `uninstall.sh` loads every module too, possibly after the program has been removed. At the top level, only set variables, define functions and call `module`. Put anything that runs commands or touches files inside `_find` or `_setup`.
- **Write for macOS's `/bin/bash` 3.2**, with `set -euo pipefail` on. That means no `declare -A`, no `${var^^}`, no `mapfile`, and no unset variables.
- **Listen on `127.0.0.1` only, and require a secret** (a password or token).
- **Uninstalling needs nothing from the module.** `uninstall.sh` stops each `LABEL`, deletes its plist and deletes all of `$SUPPORT`.

## Outline

```bash
# Foo: what it serves, and how it's protected. Sourced by config.sh.

FOO_LABEL=local.foo
FOO_PORT="${APPWEB_FOO_PORT:-9000}"
module foo "$FOO_LABEL" "$FOO_PORT" "Foo"

# Sets FOO to the foo binary.
foo_find() {
  FOO="$(command -v foo || true)"
  [ -n "$FOO" ] || fail "foo not found. Install it with: brew install foo"
}

# Creates the token in $SUPPORT, then the launch agent.
foo_setup() {
  [ -s "$SUPPORT/foo-token" ] || (umask 077; openssl rand -hex 24 > "$SUPPORT/foo-token")

  write_agent "$FOO_LABEL" foo "$FOO" \
    --host 127.0.0.1 --port "$FOO_PORT" \
    --token-file "$SUPPORT/foo-token"
}
```
