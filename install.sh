#!/bin/bash
# Installs your terminal (ttyd) and VS Code (code serve-web) as login services
# on localhost, so they open as Chrome tabs. Safe to re-run; no sudo needed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT/config.sh"

# ── 1. tools ────────────────────────────────────────────────────────────────
for m in "${MODULES[@]}"; do "${m}_find"; done

# Never overwrite a shortcut that someone else put in $BIN.
for i in "${!SHORTCUTS[@]}"; do
  s="${SHORTCUTS[$i]}"
  if [ -e "$BIN/$s" ] && ! grep -qF "$SHORTCUT_MARK" "$BIN/$s" 2>/dev/null; then
    fail "$BIN/$s already exists and wasn't installed by browser-everywhere. Move it away and run this again."
  fi
done

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

# ── 4. shortcuts in ~/.local/bin ────────────────────────────────────────────
# write_shortcut NAME URL: opens URL plus the URL-encoded folder (default: here).
# URL is pasted inside double quotes, so it can hold $(...) to run at call time.
write_shortcut() {
  {
    printf '#!/bin/sh\n%s\nurl="%s"\n' "$SHORTCUT_MARK" "$2"
    cat <<'EOF'
dir="$(cd "${1:-.}" 2>/dev/null && pwd)" || { echo "no such folder: ${1:-.}" >&2; exit 1; }

# Percent-encode $dir byte by byte (& 255: bash reads bytes over 127 as negative).
LC_ALL=C
s=$dir enc=
while [ -n "$s" ]; do
  c=${s%"${s#?}"} s=${s#?}
  case $c in
    [A-Za-z0-9/._~-]) enc=$enc$c ;;
    *) enc=$enc$(printf '%%%02X' $(( $(printf '%d' "'$c") & 255 ))) ;;
  esac
done

open -a "Google Chrome" "$url$enc"
EOF
  } > "$BIN/$1"
  chmod 700 "$BIN/$1"
}

mkdir -p "$BIN"
for i in "${!SHORTCUTS[@]}"; do write_shortcut "${SHORTCUTS[$i]}" "${SHORTCUT_URLS[$i]}"; done

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
echo "  From a terminal:"
for i in "${!SHORTCUTS[@]}"; do
  printf '    %-13s %s\n' "${SHORTCUTS[$i]} [folder]" "${SHORTCUT_HELP[$i]}"
done
echo
case ":$PATH:" in
  *":$BIN:"*)
    echo "  ~/.local/bin is already on your PATH, so the shortcuts are ready."
    echo "  (Terminals that were already open: open a new one first.)"
    ;;
  *)
    echo "  ~/.local/bin isn't on your PATH yet. Add it for your shell ($(basename "${SHELL:-sh}")), then open a new terminal:"
    echo "    zsh:   echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
    echo "    bash:  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bash_profile"
    echo "    fish:  fish_add_path ~/.local/bin"
    ;;
esac
echo
