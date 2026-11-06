# browser-everywhere: terminal and VS Code in your browser

Runs your terminal ([ttyd](https://github.com/tsl0922/ttyd)) and VS Code (`code serve-web`) as login services on `localhost`, so both open as tabs in your default browser.

| Open | Address | From a terminal |
|---|---|---|
| Terminal (new shell per tab) | `http://localhost:7682` | `t [folder]` |
| VS Code | `http://localhost:8000/?tkn=…` | `cw [folder]` |

Bookmark them as **terminal** and **vscode**, then type that word in the address bar and pick the bookmark.

## Requirements
- **macOS only.** It uses launchd for the services, `~/Library` for its files and `open` to launch your default browser, so it doesn't run on Linux or Windows.
- **[Homebrew](https://brew.sh)**, to install ttyd. ttyd doesn't publish macOS builds, so Homebrew is the way to get it.
- **[VS Code](https://code.visualstudio.com)** and any browser (the `t`/`cw` shortcuts use your default one).

## Install
```
curl -fsSL https://raw.githubusercontent.com/jorgesmu/browser.everywhere/main/install.sh | bash
```
Or, from a clone: `./install.sh`. It's safe to re-run and needs no sudo. Piped like this, the script downloads the repo to a temporary folder, runs from there and then deletes it.

`install.sh` installs ttyd with Homebrew if needed, and prints the terminal login (your browser asks for it the first time; let it save it) and the VS Code address with its token.

## Uninstall
```
curl -fsSL https://raw.githubusercontent.com/jorgesmu/browser.everywhere/main/uninstall.sh | bash
```
Or, from a clone: `./uninstall.sh`. It removes the services, the t/cw shortcuts and the secrets folder, and leaves ttyd and VS Code installed.

## Modules
Each service is a module: one file in `modules/` (`ttyd.sh`, `code.sh`) that registers its label and port and says how to set its service up. Both scripts read `config.sh` (shared paths and markers), which loads the modules listed in `modules/definition`, one name per line, in start order. Changing the list needs a clone: the `curl | bash` install always uses the repo's own `modules/definition`.

### Adding a module
1. Create `modules/<name>.sh`. [modules/README.md](modules/README.md#the-interface) describes what it must define and has an outline to start from.
2. Add `<name>` on its own line in `modules/definition`.
3. Run `./install.sh`.

### Turning a module off
1. If the module is already installed, remove its service first, or it keeps running at every login. [modules/README.md](modules/README.md#turning-a-module-off) shows how.
2. Delete its line from `modules/definition`, or comment it out with `#`. For example, to install only the terminal, remove `code`.
3. Run `./install.sh`.

## What it sets up
- `~/Library/LaunchAgents/local.ttyd.plist` and `local.code.plist`: started at login, restarted if they crash.
- `~/Library/Application Support/browser-everywhere/` (only you can open it):
  - `ttyd-pass`: the terminal password.
  - `code-token`: the VS Code token.
  - `shell`: starts `$SHELL -l` in the folder from `?arg=`.
  - `logs/`: output from both services.
- `~/.local/bin/t` and `~/.local/bin/cw`: plain `sh` scripts, so they work from any shell. If `~/.local/bin` isn't on your `PATH`, `install.sh` prints the line to add for zsh, bash and fish. It never edits your shell config.

## Security
- Both services listen on `127.0.0.1` only, so other computers can't connect.
- **Terminal:** needs a password, and other websites are refused (`-O`). The password also blocks DNS-rebinding tricks and other user accounts on the Mac.
- **VS Code:** every request needs its secret token. The sign-in cookie lasts 7 days, so keep `?tkn=` in the bookmark.
- No certificates, no `/etc/hosts` changes, no root.
- Known limitation: the ttyd password is visible in `ps` (ttyd can't read it from a file). That's fine on a single-user Mac.
- Browser extensions with "read all sites" access can see these tabs, so keep your extensions trustworthy.
