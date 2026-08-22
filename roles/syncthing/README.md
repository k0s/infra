# syncthing

Installs Syncthing and gets it running as a systemd service, and ensures the
folders in `syncthing_folders` (default: `~/movies`, `~/projects`) exist. It
does **not** pair devices or share folders — that's a one-time, interactive,
two-party trust exchange, not something to script blind the first time a mesh
forms.

## Manual pairing (do once, per device pair)

1. On each machine, open the Syncthing GUI: http://127.0.0.1:8384
2. Under **Actions > Show ID**, copy each machine's device ID.
3. On each machine, **Add Remote Device**, paste the other's ID, give it a
   name.
4. Once both machines show the other as connected, **Add Folder** for each of
   `~/movies` and `~/projects`, share it with the paired device, and confirm
   the share on both sides.
5. Confirm sync completes, then update `~/.silvermirror` (`~/web/sync.ini`) to
   drop the `[movies]` resource — Unison should stop touching it once
   Syncthing owns it. `~/projects` was never Unison-managed, so nothing to
   remove there. This is also the point to clean up `~/bin/syn.sh`'s stale
   Mercurial-era lines (see clawdette's `media-server` project discussion,
   2026-08-22) — tracked as clawdette task, not part of this role.

This is the pilot step from clawdette's `sync-backup` project
(`operations/syncthing-pilot.md`) — low-stakes folders first, before trusting
Syncthing with everything Unison currently handles.
