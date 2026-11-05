#!/bin/bash
# Installs your terminal (ttyd) and VS Code (code serve-web) as login services
# on localhost, so they open as Chrome tabs. Safe to re-run; no sudo needed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT/config.sh"

# ── 1. tools ────────────────────────────────────────────────────────────────
for m in "${MODULES[@]}"; do "${m}_find"; done

# Stop our own services first (re-runs), then every port must be free.
for label in "${LABELS[@]}"; do
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
for port in "${PORTS[@]}"; do check_port_availability "$port"; done

# ── 2. support folder (secrets are kept across re-runs) ─────────────────────
mkdir -p "$SUPPORT/logs"
chmod 700 "$SUPPORT"

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

mkdir -p "$AGENTS"
for m in "${MODULES[@]}"; do "${m}_setup"; done

for label in "${LABELS[@]}"; do
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
for i in "${!MODULES[@]}"; do wait_port "${PORTS[$i]}" "${TITLES[$i]}"; done

# ── 4. t / cw shortcuts in .zshrc ───────────────────────────────────────────
touch "$ZSHRC"
sed -i '' "/^$ZSHRC_BEGIN\$/,/^$ZSHRC_END\$/d" "$ZSHRC"
cat >> "$ZSHRC" <<EOF
$ZSHRC_BEGIN
# terminal and VS Code in Chrome (installed by app-web; remove with uninstall.sh)
_appweb_dir() { local d="\${1:-\$PWD}"; (cd "\$d" 2>/dev/null && pwd) || { print -u2 "no such folder: \$d"; return 1; } }
_appweb_enc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "\$1"; }
t()  { local d; d="\$(_appweb_dir "\$1")" || return; open -a "Google Chrome" "http://localhost:$TTYD_PORT/?arg=\$(_appweb_enc "\$d")"; }
cw() { local d; d="\$(_appweb_dir "\$1")" || return; open -a "Google Chrome" "http://localhost:$CODE_PORT/?tkn=\$(cat "$SUPPORT/code-token")&folder=\$(_appweb_enc "\$d")"; }
$ZSHRC_END
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
