#!/bin/bash
# Removes everything install.sh added. Leaves ttyd and VS Code installed.
set -euo pipefail

SUPPORT="$HOME/Library/Application Support/app-web"
AGENTS="$HOME/Library/LaunchAgents"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
UID_NUM="$(id -u)"

for label in local.ttyd local.code; do
  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || true
  rm -f "$AGENTS/$label.plist"
done

if [ -f "$ZSHRC" ]; then
  sed -i '' '/^# >>> app-web >>>$/,/^# <<< app-web <<<$/d' "$ZSHRC"
fi

rm -rf "$SUPPORT"

echo "✻ Removed the services, the t/cw shortcuts and $SUPPORT."
echo "  Open terminals keep t/cw until you run: source $ZSHRC"
echo "  You can delete the \"terminal\" and \"vscode\" bookmarks in Chrome."
