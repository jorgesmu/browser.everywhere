# app-web: terminal and VS Code in Chrome

Runs your terminal ([ttyd](https://github.com/tsl0922/ttyd)) and VS Code (`code serve-web`) as login services on `localhost`, so both open as Chrome tabs.

| Open | Address | From a terminal |
|---|---|---|
| Terminal (new shell per tab) | `http://localhost:7682` | `t [folder]` |
| VS Code | `http://localhost:8000/?tkn=…` | `cw [folder]` |

Bookmark them as **terminal** and **vscode**, then type that word in Chrome's address bar and pick the bookmark.

## Install / remove
```
./install.sh      # safe to re-run; no sudo
./uninstall.sh    # removes services, the t/cw shortcuts and the secrets folder
```
`install.sh` installs ttyd with Homebrew if needed, and prints the terminal login (Chrome asks for it the first time; let it save it) and the VS Code address with its token.

## What it sets up
- `~/Library/LaunchAgents/local.ttyd.plist` and `local.code.plist`: started at login, restarted if they crash.
- `~/Library/Application Support/app-web/` (only you can open it):
  - `ttyd-pass`: the terminal password.
  - `code-token`: the VS Code token.
  - `shell`: starts `$SHELL -l` in the folder from `?arg=`.
  - `logs/`: output from both services.
- A `t`/`cw` block in `~/.zshrc`, between `# >>> app-web >>>` markers.

## Security
- Both services listen on `127.0.0.1` only, so other computers can't connect.
- **Terminal:** needs a password, and other websites are refused (`-O`). The password also blocks DNS-rebinding tricks and other user accounts on the Mac.
- **VS Code:** every request needs its secret token. The sign-in cookie lasts 7 days, so keep `?tkn=` in the bookmark.
- No certificates, no `/etc/hosts` changes, no root.
- Known limitation: the ttyd password is visible in `ps` (ttyd can't read it from a file). That's fine on a single-user Mac.
- Browser extensions with "read all sites" access can see these tabs, so keep your extensions trustworthy.
