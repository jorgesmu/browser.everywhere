# Modules

Each service that browser-everywhere runs as a login service (a launch agent) is a module: one file, `modules/<name>.sh`. `config.sh` loads the modules listed in `modules/definition`, in that order. Both `install.sh` and `uninstall.sh` load them.

## Turning a module off

Delete its line from `modules/definition`, or comment it out with `#` (put the name back to turn it on again). This needs a clone: the `curl | bash` install always uses the repo's own `modules/definition`.

Install and uninstall only manage the modules listed there. So if the module is already installed, remove its service **before** taking it out of the list, or uninstall won't know about it and it keeps running at every login. Either:

- **Reinstall everything:** run `./uninstall.sh`, edit `modules/definition`, then run `./install.sh`.
- **Remove just that one by hand**, with the `LABEL` and shortcut `COMMAND` from its file (`local.code` and `cw` for `code.sh`), after editing `modules/definition`:
  ```bash
  launchctl bootout gui/$(id -u)/LABEL
  rm ~/Library/LaunchAgents/LABEL.plist ~/.local/bin/COMMAND
  ```
  Then run `./install.sh` again, so Caddy stops serving its port.

`modules/definition` must list `caddy` and at least one service.

## Adding a module

1. Create `modules/<name>.sh` (outline below).
2. Add `<name>` on its own line in `modules/definition`. Modules start in the order they're listed. Blank lines and `#` comments are skipped.

## The interface

Every module file has three parts, plus an optional `proxy`, shortcut and `_info`. A service module (`ttyd`, `code`) has a `proxy`; `caddy` is the one module without it.

### Registration (runs when the file is loaded)

```bash
module NAME LABEL TITLE
```

| Argument | Meaning | Example |
|---|---|---|
| `NAME`  | Must match the file name. It's the prefix for the two functions. | `code` |
| `LABEL` | The launchd label. It's also the plist name: `~/Library/LaunchAgents/<LABEL>.plist`. | `local.code` |
| `TITLE` | The name shown in messages, such as "VS Code didn't start (no code.sock)". | `"VS Code"` |

Name module-specific variables with an uppercase `NAME_` prefix (`CODE_LABEL`, `CODE_PORT`). Every module's variables share one namespace.

### Proxy (service modules, also at load time)

```bash
proxy PORT SOCKET
```

Asks Caddy to serve `http://localhost:PORT` from the service's socket. Call it right after `module`.

| Argument | Meaning | Example |
|---|---|---|
| `PORT`   | The localhost port Caddy listens on. Install checks that it's free before starting. | `8000` |
| `SOCKET` | The socket file the service listens on, relative to `$SUPPORT` (macOS limits socket paths to about 100 characters, so they stay short). Install deletes it before starting, then waits until the service creates it and Caddy listens on `PORT`. | `code.sock` |

Caddy only forwards requests for `localhost` or `127.0.0.1` that come from the same page, so the service needs no password or token of its own.

### Shortcut (optional, also at load time)

```bash
shortcut COMMAND URL HELP
```

Adds a terminal command, `~/.local/bin/COMMAND [folder]`, that opens `URL` followed by the folder's URL-encoded absolute path (the current folder by default) in your default browser.

| Argument | Meaning | Example |
|---|---|---|
| `COMMAND` | The command's name. Install refuses to overwrite a file of that name it didn't create. | `cw` |
| `URL`     | Everything before the folder. It's written inside double quotes in an `sh` script, so `\$(...)` runs each time the command does. | `"http://localhost:$CODE_PORT/?folder="` |
| `HELP`    | One line for install's final message. | `"VS Code tab on that folder"` |

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

- **Called by:** `install.sh` only, once every `_find` has passed, the old services are stopped, every `proxy` port is free and `$SUPPORT` exists. `caddy_setup` can read every module's `proxy` entries, whatever the order.
- **Job:**
  1. Create any helper files the service needs in `$SUPPORT`.
  2. Call `write_agent` exactly once, with the module's `LABEL`. Make the service listen on its `SOCKET` only. If it won't start when a crash left the socket behind, remove it first, as `code.sh` does.
- **Does not need to:** start the service. Install starts every agent (`launchctl bootstrap`) and then waits for each socket and port.

```bash
write_agent LABEL LOGNAME PROGRAM [ARG...]
```

`write_agent` writes `$AGENTS/<LABEL>.plist`, readable only by you. The service:
- starts at login and restarts if it crashes;
- runs `PROGRAM ARG...` with `$SUPPORT` as its working directory, so `./file` means `$SUPPORT/file`;
- logs to `$SUPPORT/logs/<LOGNAME>.log`;
- gets `PATH` (Homebrew first), `SHELL` and `LANG` as its environment.

### `<name>_info`: its part of install's final message (optional)

```bash
<name>_info()
```

- **Called by:** `install.sh` only, at the end, once every service is listening. Modules print in `modules/definition` order.
- **Job:** `echo` what the user needs to open the service, indented two spaces. `ttyd_info` and `code_info` print the address and a bookmark name.
- **If it's missing:** install prints `  TITLE: http://localhost:PORT` for each of its `proxy` ports.

## What a module can use

| Name | What it is |
|---|---|
| `$SUPPORT` | `~/Library/Application Support/browser-everywhere`, readable only by you. Holds the sockets, helper files and `logs/`. Every service runs with it as its working directory. |
| `$AGENTS`  | `~/Library/LaunchAgents` |
| `$ROOT`    | The repo folder |
| `say MSG`  | Prints a progress line |
| `fail MSG` | Prints an error and exits |
| `write_agent` | Only inside `_setup`; see above |

## Rules

- **Loading a module must have no side effects.** `uninstall.sh` loads every module too, possibly after the program has been removed. At the top level, only set variables, define functions and call `module`, `proxy` and `shortcut`. Put anything that runs commands or touches files inside `_find` or `_setup`.
- **Write for macOS's `/bin/bash` 3.2**, with `set -euo pipefail` on. That means no `declare -A`, no `${var^^}`, no `mapfile`, and no unset variables.
- **Listen on a socket in `$SUPPORT`, never on a port.** Caddy is the only thing on a port, and it does the checks.
- **Uninstalling needs nothing from the module.** `uninstall.sh` stops each `LABEL`, deletes its plist and its shortcut, and deletes all of `$SUPPORT`.

## Outline

```bash
# Foo: what it serves, behind Caddy. Sourced by config.sh.

FOO_LABEL=local.foo
FOO_PORT="${BROWSER_EVERYWHERE_FOO_PORT:-9000}"
module foo "$FOO_LABEL" "Foo"
proxy "$FOO_PORT" foo.sock

# Sets FOO to the foo binary.
foo_find() {
  FOO="$(command -v foo || true)"
  [ -n "$FOO" ] || fail "foo not found. Install it with: brew install foo"
}

# Writes the launch agent.
foo_setup() {
  write_agent "$FOO_LABEL" foo "$FOO" --socket foo.sock
}

# Optional: install's final message.
foo_info() {
  echo "  Foo: http://localhost:$FOO_PORT (bookmark it as \"foo\")"
}
```
