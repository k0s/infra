# syncthing

Installs Syncthing, gets it running as a systemd service, ensures the folders
in `syncthing_folders` (default: `movies`, `projects`) exist, and **shares
them with every other host in the `syncthing_mesh` inventory group** via the
REST API — a real folder gets configured with the right device list on both
sides, not just installed software (verified 2026-08-23: both hosts converge
to `state: idle`, `needFiles: 0`).

It does **not** pair devices — that's a one-time, interactive, two-party trust
exchange, not something to script blind the first time a mesh forms.

## One-time manual step: pairing (do once, per device pair)

1. On each machine, open the Syncthing GUI: http://127.0.0.1:8384
2. Under **Actions > Show ID**, copy each machine's device ID.
3. On each machine, **Add Remote Device**, paste the other's ID, give it a
   name.
4. Once both machines show the other as connected, run `highstate.yml`
   against the whole `syncthing_mesh` group (not `--limit` to a single host —
   folder-sharing needs every member's Device ID via `hostvars`, see
   `tasks/main.yml`'s header). Folder sharing happens automatically from here.
5. Confirm sync completes (`state: idle`, `needFiles: 0` via
   `/rest/db/status?folder=<id>`), then update `~/.silvermirror`
   (`~/web/sync.ini`) to drop the `[movies]` resource — Unison should stop
   touching it once Syncthing owns it. `~/projects` was never Unison-managed,
   so nothing to remove there. This is also the point to clean up
   `~/bin/syn.sh`'s stale Mercurial-era lines (see clawdette's `media-server`
   project discussion, 2026-08-22) — tracked as a clawdette task, not part of
   this role.

## Introducer (optional, one-time, also manual)

Flagging one device as an Introducer on a peer's side means any *future*
device that pairs with the introducer gets automatically introduced to that
peer too — no manual re-pairing with every existing device. Not scripted here
(same reasoning as device pairing itself — a trust decision, not a
config value): set via the REST API,
`PATCH /rest/config/devices/<id>` with `{"introducer": true}` on the peer that
should trust the introducer.

This is the pilot step from clawdette's `sync-backup` project
(`operations/syncthing-pilot.md`) — low-stakes folders first, before trusting
Syncthing with everything Unison currently handles.
