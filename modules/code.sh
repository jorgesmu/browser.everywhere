# VS Code: code serve-web, gated by a secret token. Sourced by config.sh.

CODE_LABEL=local.code
CODE_PORT="${BROWSER_EVERYWHERE_CODE_PORT:-8000}"
module code "$CODE_LABEL" "$CODE_PORT" "VS Code"
shortcut cw "http://localhost:$CODE_PORT/?tkn=\$(cat '$SUPPORT/code-token')&folder=" "VS Code tab on that folder"

# Sets CODE to the VS Code CLI.
code_find() {
  CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  [ -x "$CODE" ] || CODE="$(command -v code || true)"
  [ -n "$CODE" ] && [ -x "$CODE" ] || fail "VS Code not found. Install it from https://code.visualstudio.com"
}

# Creates the token in $SUPPORT, then the launch agent.
code_setup() {
  [ -s "$SUPPORT/code-token" ] || (umask 077; openssl rand -hex 24 > "$SUPPORT/code-token")

  write_agent "$CODE_LABEL" code "$CODE" serve-web \
    --host 127.0.0.1 --port "$CODE_PORT" \
    --connection-token-file "$SUPPORT/code-token" \
    --accept-server-license-terms
}

# install's final message.
code_info() {
  echo "  VS Code: http://localhost:$CODE_PORT/?tkn=$(cat "$SUPPORT/code-token") (bookmark it as \"vscode\")"
  echo "    Keep the ?tkn= part: VS Code's sign-in cookie only lasts 7 days."
}
