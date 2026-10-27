# navidrome_mcp

[Navidrome-MCP](https://github.com/Blakeem/Navidrome-MCP) as a systemd **user**
service, for hosts in `navidrome_mcp_hosts`. It searches a Navidrome library and
plays through mpv in the logged-in desktop session, so it runs only while someone
is logged in at the host.

- apt `nodejs` and `npm` (the only root step); the npm package pinned under
  `~/.local/lib/navidrome-mcp/<version>`, install scripts off.
- Streamable HTTP at `:3000/mcp`, loopback by default. Set `navidrome_mcp_expose`
  and `navidrome_mcp_allowed_hosts` per host to serve the LAN.
- Configured only through the unit's environment; the web player is off.

## Before the first run

1. In Navidrome, create a non-admin user for the server (default name `claude`).
2. Create `~/.config/navidrome-mcp/env`, mode 600, with:

       NAVIDROME_PASSWORD=<that user's password>
       MCP_HTTP_AUTH_TOKEN=<a long random string, e.g. openssl rand -hex 32>

   systemd reads it as an `EnvironmentFile`: one `KEY=value` per line; avoid quotes
   and backslashes in values.

The role fails until that file exists, and if a `settings.json` is present.

Clients send `Authorization: Bearer <token>`. `GET /healthz` needs no token.

Changing the secrets file: `systemctl --user restart navidrome-mcp`.
Upgrade: bump `navidrome_mcp_version`, apply, then remove the old version's
directory.
