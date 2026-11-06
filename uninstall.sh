#!/bin/bash
# Removes everything install.sh added. Leaves ttyd and VS Code installed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
