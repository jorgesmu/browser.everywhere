#!/bin/bash
# Removes everything install.sh added. Leaves the programs the modules run installed.
set -euo pipefail

# Piped from curl (no checkout next to us): fetch the repo and run from there.
# Braces make bash read the whole block before running it, so a cut-off
# download can't run half of it.
{
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent/x}")" 2>/dev/null && pwd || true)"
  if [ ! -f "$ROOT/config.sh" ]; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL https://github.com/jorgesmu/browser.everywhere/archive/refs/heads/main.tar.gz |
      tar -xz --strip-components 1 -C "$tmp"
    bash "$tmp/uninstall.sh" "$@" </dev/null
    exit
  fi
}
. "$ROOT/config.sh"

for label in "${LABELS[@]}"; do
  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || true
  rm -f "$AGENTS/$label.plist"
done

for i in "${!SHORTCUTS[@]}"; do
  s="$BIN/${SHORTCUTS[$i]}"
  if grep -qF "$SHORTCUT_MARK" "$s" 2>/dev/null; then rm -f "$s"; fi
done

rm -rf "$SUPPORT"

echo "✻ Removed the services, the shortcuts and $SUPPORT."
echo "  If you added ~/.local/bin to your PATH only for these shortcuts, you can remove that line."
echo "  You can delete bookmarks in your browser."
