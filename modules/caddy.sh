# Caddy: the only service on a port. It forwards each `proxy` port to its
# module's socket, and only for pages on localhost. Sourced by config.sh.

CADDY_LABEL=local.caddy
module caddy "$CADDY_LABEL" Caddy

# Sets CADDY, installing Caddy with Homebrew if needed.
caddy_find() {
  if ! command -v caddy >/dev/null; then
    command -v brew >/dev/null || fail "Caddy is missing and Homebrew isn't installed (https://brew.sh)"
    say "Installing Caddy with Homebrew…"
    brew install caddy
  fi
  CADDY="$(command -v caddy)"
}

# Writes the Caddyfile in $SUPPORT, then the launch agent.
caddy_setup() {
  local i port
  {
    printf '{\n\tadmin off\n\tauto_https off\n\tpersist_config off\n}\n'
    for i in "${!PROXY_PORTS[@]}"; do
      port="${PROXY_PORTS[$i]}"
      # Refuse other host names (DNS rebinding) and requests from other
      # sites (Origin), and don't let other sites frame the page.
      cat <<CADDY

http://:$port {
	bind 127.0.0.1
	@badhost not host localhost 127.0.0.1
	respond @badhost 403
	@badorigin {
		header Origin *
		not header Origin http://localhost:$port
		not header Origin http://127.0.0.1:$port
	}
	respond @badorigin 403
	header ?X-Frame-Options SAMEORIGIN
	reverse_proxy unix/${PROXY_SOCKETS[$i]}
}
CADDY
    done
  } > "$SUPPORT/Caddyfile"

  # XDG_DATA_HOME keeps Caddy's own files in $SUPPORT.
  write_agent "$CADDY_LABEL" caddy /usr/bin/env "XDG_DATA_HOME=$SUPPORT/caddy" \
    "$CADDY" run --config Caddyfile
}
