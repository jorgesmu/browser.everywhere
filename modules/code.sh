# VS Code: code serve-web, behind Caddy. Sourced by config.sh.

CODE_LABEL=local.code
CODE_PORT="${BROWSER_EVERYWHERE_CODE_PORT:-8000}"
module code "$CODE_LABEL" "VS Code"
proxy "$CODE_PORT" code.sock
shortcut cw "http://localhost:$CODE_PORT/?folder=" "VS Code tab on that folder"

# Sets CODE to the VS Code CLI.
code_find() {
  CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  [ -x "$CODE" ] || CODE="$(command -v code || true)"
  [ -n "$CODE" ] && [ -x "$CODE" ] || fail "VS Code not found. Install it from https://code.visualstudio.com"
}

# Writes the launch agent. No token: only Caddy reaches the socket.
code_setup() {
  # VS Code won't start if a crash left code.sock behind, so remove it first.
  write_agent "$CODE_LABEL" code /bin/sh -c 'rm -f code.sock; exec "$0" "$@"' \
    "$CODE" serve-web \
    --socket-path code.sock --without-connection-token \
    --accept-server-license-terms
}

# install's final message.
code_info() {
  echo "  VS Code: http://localhost:$CODE_PORT (bookmark it as \"vscode\")"
}
