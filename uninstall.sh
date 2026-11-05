#!/bin/bash
# Removes everything install.sh added. Leaves ttyd and VS Code installed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT/config.sh"

for label in "${LABELS[@]}"; do
  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || true
  rm -f "$AGENTS/$label.plist"
done

if [ -f "$ZSHRC" ]; then
  sed -i '' "/^$ZSHRC_BEGIN\$/,/^$ZSHRC_END\$/d" "$ZSHRC"
fi

rm -rf "$SUPPORT"

echo "✻ Removed the services, the t/cw shortcuts and $SUPPORT."
echo "  Open terminals keep t/cw until you run: source $ZSHRC"
echo "  You can delete the \"terminal\" and \"vscode\" bookmarks in Chrome."
