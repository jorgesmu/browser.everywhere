# Shared settings for install.sh and uninstall.sh. Sourced, not run.

SUPPORT="$HOME/Library/Application Support/app-web"
AGENTS="$HOME/Library/LaunchAgents"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
UID_NUM="$(id -u)"

# Marks the t/cw block in .zshrc.
ZSHRC_BEGIN='# >>> app-web >>>'
ZSHRC_END='# <<< app-web <<<'

say()  { printf '\033[38;2;217;119;87m✻\033[0m %s\n' "$*"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Each module registers itself with `module`, and defines <name>_find (check or
# install its program) and <name>_setup (write its files and launch agent).
MODULES=() LABELS=() PORTS=() TITLES=()
module() { MODULES+=("$1"); LABELS+=("$2"); PORTS+=("$3"); TITLES+=("$4"); }

# Load the modules listed in modules/definition.
while read -r name || [ -n "$name" ]; do
  case "$name" in ''|'#'*) continue ;; esac
  [ -f "$ROOT/modules/$name.sh" ] || fail "modules/definition lists $name, but modules/$name.sh doesn't exist"
  . "$ROOT/modules/$name.sh"
done < "$ROOT/modules/definition"
