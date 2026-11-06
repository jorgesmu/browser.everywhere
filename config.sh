# Shared settings for install.sh and uninstall.sh. Sourced, not run.

SUPPORT="$HOME/Library/Application Support/browser-everywhere"
AGENTS="$HOME/Library/LaunchAgents"
BIN="$HOME/.local/bin"
UID_NUM="$(id -u)"

# Shortcut scripts in $BIN carry this line, so we never touch anyone else's.
SHORTCUT_MARK='# installed by browser-everywhere'

say()  { printf '\033[38;2;217;119;87m✻\033[0m %s\n' "$*"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Each module registers itself with `module`, and defines <name>_find (check or
# install its program) and <name>_setup (write its files and launch agent).
# It can also add a terminal command with `shortcut`.
MODULES=() LABELS=() PORTS=() TITLES=()
module() { MODULES+=("$1"); LABELS+=("$2"); PORTS+=("$3"); TITLES+=("$4"); }
SHORTCUTS=() SHORTCUT_URLS=() SHORTCUT_HELP=()
shortcut() { SHORTCUTS+=("$1"); SHORTCUT_URLS+=("$2"); SHORTCUT_HELP+=("$3"); }

# Load the modules listed in modules/definition.
while read -r name || [ -n "$name" ]; do
  case "$name" in ''|'#'*) continue ;; esac
  [ -f "$ROOT/modules/$name.sh" ] || fail "modules/definition lists $name, but modules/$name.sh doesn't exist"
  . "$ROOT/modules/$name.sh"
done < "$ROOT/modules/definition"
