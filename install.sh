#!/bin/bash
# Installs your terminal (ttyd) and VS Code (code serve-web) as login services
# on localhost, so they open as Chrome tabs. Safe to re-run; no sudo needed.
set -euo pipefail

TTYD_PORT="${APPWEB_TTYD_PORT:-7682}"
CODE_PORT="${APPWEB_CODE_PORT:-8000}"
SUPPORT="$HOME/Library/Application Support/app-web"
AGENTS="$HOME/Library/LaunchAgents"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
UID_NUM="$(id -u)"

say()  { printf '\033[38;2;217;119;87m✻\033[0m %s\n' "$*"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ── 1. tools ────────────────────────────────────────────────────────────────
if ! command -v ttyd >/dev/null; then
  command -v brew >/dev/null || fail "ttyd is missing and Homebrew isn't installed (https://brew.sh)"
  say "Installing ttyd with Homebrew…"
  brew install ttyd
fi
TTYD="$(command -v ttyd)"

CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
[ -x "$CODE" ] || CODE="$(command -v code || true)"
[ -n "$CODE" ] && [ -x "$CODE" ] || fail "VS Code not found. Install it from https://code.visualstudio.com"

# Stop our own services first (re-runs), then every port must be free.
for label in local.ttyd local.code; do
  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || true
done
check_port_availability() {
  local port=$1 pid
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pid="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -1 || true)"
    [ -z "$pid" ] && return 0
    sleep 0.5
  done
  fail "Port $port is already used by: $(ps -o command= -p "$pid" | cut -c1-80) (PID $pid). Stop it (kill $pid) and run this again."
}
check_port_availability "$TTYD_PORT"
check_port_availability "$CODE_PORT"

# ── 2. support folder and secrets (kept across re-runs) ─────────────────────
mkdir -p "$SUPPORT/logs"
chmod 700 "$SUPPORT"
[ -s "$SUPPORT/ttyd-pass" ]  || (umask 077; openssl rand -hex 16 > "$SUPPORT/ttyd-pass")
[ -s "$SUPPORT/code-token" ] || (umask 077; openssl rand -hex 24 > "$SUPPORT/code-token")
TTYD_USER="$(id -un)"
TTYD_PASS="$(cat "$SUPPORT/ttyd-pass")"

# Each terminal tab runs this: start in the folder from ?arg=, else home.
cat > "$SUPPORT/shell" <<'EOF'
#!/bin/sh
cd "${1:-$HOME}" 2>/dev/null || cd "$HOME"
exec "${SHELL:-/bin/zsh}" -l
EOF
chmod 700 "$SUPPORT/shell"

# ── 3. launch agents ────────────────────────────────────────────────────────
xml() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' <<<"$1"; }

# write_agent LABEL LOGNAME ARG...
write_agent() {
  local label=$1 log=$2; shift 2
  local args="" a
  for a in "$@"; do args+="    <string>$(xml "$a")</string>"$'\n'; done
  cat > "$AGENTS/$label.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
$args  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>SHELL</key><string>$(xml "${SHELL:-/bin/zsh}")</string>
    <key>LANG</key><string>en_US.UTF-8</string>
  </dict>
  <key>WorkingDirectory</key><string>$(xml "$SUPPORT")</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$(xml "$SUPPORT/logs/$log.log")</string>
  <key>StandardErrorPath</key><string>$(xml "$SUPPORT/logs/$log.log")</string>
</dict>
</plist>
EOF
  chmod 600 "$AGENTS/$label.plist" # holds the ttyd password
}

THEME='{"background":"#1f1e1b","foreground":"#e8e6e1","cursor":"#d97757","cursorAccent":"#1f1e1b","selectionBackground":"#d9775755","black":"#2e2d29","red":"#e06c75","green":"#7bc67e","yellow":"#e5c07b","blue":"#61afef","magenta":"#c678dd","cyan":"#56b6c2","white":"#d7d5cf","brightBlack":"#6e6b63","brightRed":"#ef8a92","brightGreen":"#98d69a","brightYellow":"#f0d199","brightBlue":"#85c1f5","brightMagenta":"#d59ae6","brightCyan":"#7ccad4","brightWhite":"#ffffff"}'

mkdir -p "$AGENTS"
write_agent local.ttyd ttyd "$TTYD" \
  -i lo0 -p "$TTYD_PORT" -W -O -a \
  -c "$TTYD_USER:$TTYD_PASS" \
  -t "theme=$THEME" \
  -t 'fontFamily=Menlo, monospace' \
  -t fontSize=13 \
  -t disableLeaveAlert=true \
  ./shell
write_agent local.code code "$CODE" serve-web \
  --host 127.0.0.1 --port "$CODE_PORT" \
  --connection-token-file "$SUPPORT/code-token" \
  --accept-server-license-terms

for label in local.ttyd local.code; do
  launchctl bootstrap "gui/$UID_NUM" "$AGENTS/$label.plist"
done

wait_port() {
  local port=$1 name=$2 _
  for _ in $(seq 1 90); do
    lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1 && return 0
    sleep 1
  done
  fail "$name didn't start on port $port. See $SUPPORT/logs/"
}
say "Starting services (VS Code may take a minute the first time)…"
wait_port "$TTYD_PORT" ttyd
wait_port "$CODE_PORT" "VS Code"

# ── 4. t / cw shortcuts in .zshrc ───────────────────────────────────────────
BEGIN='# >>> app-web >>>'
END='# <<< app-web <<<'
touch "$ZSHRC"
sed -i '' "/^$BEGIN\$/,/^$END\$/d" "$ZSHRC"
cat >> "$ZSHRC" <<EOF
$BEGIN
# terminal and VS Code in Chrome (installed by app-web; remove with uninstall.sh)
_appweb_dir() { local d="\${1:-\$PWD}"; (cd "\$d" 2>/dev/null && pwd) || { print -u2 "no such folder: \$d"; return 1; } }
_appweb_enc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "\$1"; }
t()  { local d; d="\$(_appweb_dir "\$1")" || return; open -a "Google Chrome" "http://localhost:$TTYD_PORT/?arg=\$(_appweb_enc "\$d")"; }
cw() { local d; d="\$(_appweb_dir "\$1")" || return; open -a "Google Chrome" "http://localhost:$CODE_PORT/?tkn=\$(cat "$SUPPORT/code-token")&folder=\$(_appweb_enc "\$d")"; }
$END
EOF

# ── 5. first visit + instructions ───────────────────────────────────────────
echo
say "Installed. Terminal: http://localhost:$TTYD_PORT   VS Code: http://localhost:$CODE_PORT"
echo
echo "  Terminal login (Chrome asks once, let it save it):"
echo "    user:     $TTYD_USER"
echo "    password: $TTYD_PASS"
echo
echo "  Make the shortcuts: in Chrome, bookmark each tab and name it"
echo "    \"terminal\" → http://localhost:$TTYD_PORT"
echo "    \"vscode\"   → http://localhost:$CODE_PORT/?tkn=$(cat "$SUPPORT/code-token")"
echo "      (keep the ?tkn= part: VS Code's sign-in cookie only lasts 7 days)"
echo "  Then type terminal or vscode in the address bar and pick the bookmark."
echo
echo "  In any terminal (after: source $ZSHRC):"
echo "    t [folder]    shell tab in that folder"
echo "    cw [folder]   VS Code tab on that folder"
echo
