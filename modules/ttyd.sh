# Terminal: ttyd, a new login shell per tab. Sourced by config.sh.

TTYD_LABEL=local.ttyd
TTYD_PORT="${BROWSER_EVERYWHERE_TTYD_PORT:-7682}"
module ttyd "$TTYD_LABEL" "$TTYD_PORT" ttyd
shortcut t "http://localhost:$TTYD_PORT/?arg=" "shell tab in that folder"
TTYD_THEME='{"background":"#1f1e1b","foreground":"#e8e6e1","cursor":"#d97757","cursorAccent":"#1f1e1b","selectionBackground":"#d9775755","black":"#2e2d29","red":"#e06c75","green":"#7bc67e","yellow":"#e5c07b","blue":"#61afef","magenta":"#c678dd","cyan":"#56b6c2","white":"#d7d5cf","brightBlack":"#6e6b63","brightRed":"#ef8a92","brightGreen":"#98d69a","brightYellow":"#f0d199","brightBlue":"#85c1f5","brightMagenta":"#d59ae6","brightCyan":"#7ccad4","brightWhite":"#ffffff"}'

# Sets TTYD, installing ttyd with Homebrew if needed.
ttyd_find() {
  if ! command -v ttyd >/dev/null; then
    command -v brew >/dev/null || fail "ttyd is missing and Homebrew isn't installed (https://brew.sh)"
    say "Installing ttyd with Homebrew…"
    brew install ttyd
  fi
  TTYD="$(command -v ttyd)"
}

# Creates the password and shell script in $SUPPORT, then the launch agent.
# Sets TTYD_USER and TTYD_PASS.
ttyd_setup() {
  [ -s "$SUPPORT/ttyd-pass" ] || (umask 077; openssl rand -hex 16 > "$SUPPORT/ttyd-pass")
  TTYD_USER="$(id -un)"
  TTYD_PASS="$(cat "$SUPPORT/ttyd-pass")"

  # Each terminal tab runs this: start in the folder from ?arg=, else home.
  cat > "$SUPPORT/shell" <<'SH'
#!/bin/sh
cd "${1:-$HOME}" 2>/dev/null || cd "$HOME"
exec "${SHELL:-/bin/zsh}" -l
SH
  chmod 700 "$SUPPORT/shell"

  write_agent "$TTYD_LABEL" ttyd "$TTYD" \
    -i lo0 -p "$TTYD_PORT" -W -O -a \
    -c "$TTYD_USER:$TTYD_PASS" \
    -t "theme=$TTYD_THEME" \
    -t 'fontFamily=Menlo, monospace' \
    -t fontSize=13 \
    -t disableLeaveAlert=true \
    ./shell
}
