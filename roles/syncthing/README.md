# syncthing

Installs Syncthing, gets it running as a systemd service, ensures the folders
in `syncthing_folders` (default: `movies`, `projects`) exist, and **shares
them with every other host in the `syncthing_mesh` inventory group** via the
REST API — a real folder gets configured with the right device list on both
sides, not just installed software (verified 2026-08-23: both hosts converge
to `state: idle`, `needFiles: 0`).

It does **not** pair devices — that's a one-time, interactive, two-party trust
exchange, not something to script blind the first time a mesh forms.

## Folder type (`syncthing_folder_type`)

Syncthing's folder `type` is a **per-device** property: the same folder is
legitimately `sendreceive` on one machine and `receiveonly` on another. This role
defaults to `sendreceive`, which is what it hardcoded previously.

```yaml
syncthing_folder_type: receiveonly      # every folder on this host
syncthing_folder_types:                 # optional per-folder override
  web: receiveonly
```

Valid values: `sendreceive`, `sendonly`, `receiveonly`. Anything else fails the
play with a clear message rather than PUTting a bad folder config.

**Why this is worth having: Syncthing propagates deletions.** A machine that is
still being evaluated — new hardware, a rebuild, a box you might wipe — can
delete data on every peer if its configuration is wrong. `receiveonly` accepts
changes and never sends its own, which makes such a machine safe to add to the
mesh before you trust it.

Note that setting this by hand in the Syncthing GUI does **not** hold: this role
PUTs folder config over the REST API, so the next run reverts it. That is
precisely why it belongs here as a variable.

### It is per host, so it goes in the inventory

This is the first genuinely per-host value in this repo — the untracked
`k0s-infra-vars.yml` is loaded at play level and shared by every host, so it is
the wrong place. Use the inventory instead:

```ini
[syncthing_mesh]
puffin
pop-os
newbox   syncthing_folder_type=receiveonly
```

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

## Extra devices (`syncthing_extra_devices`)

Devices that are not Ansible hosts — a phone, a laptop — are declared in the
vars file with their device ID and the folders they get:

```yaml
syncthing_extra_devices:
  - name: phone
    id: XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX
    folders: [docs]
```

Every `syncthing_mesh` host then:

1. adds the device to its device list, if it isn't there already (an existing
   entry is left alone);
2. includes it in the share list of each folder it names.

The device still has to accept each host ("wants to connect", then the folder
offer) — that half of the handshake stays on the device.

**Share lists are exact.** The folder `PUT` replaces the whole folder object,
so each managed folder is shared with precisely the other mesh hosts plus the
extra devices that name it. A device shared by hand in the GUI is unshared on
the next run; declare it here instead. The same `PUT` resets any other folder
setting changed in the GUI (versioning, rescan interval) to Syncthing's default.

Removing an entry unshares its folders on the next run. The device stays in
each host's device list; delete it in the GUI if it is gone for good.

A possible later change: merge instead of replace (`PATCH` the folder, union
the existing share list with peers and extra devices). Hand-made shares and
GUI settings would then survive, at the cost of removal becoming manual.

Device IDs are not secrets, but they identify a device, so keep the real list
in the untracked vars file, not in this repo. The list is validated before
any API call: a malformed ID or a folder not in `syncthing_folders` fails the
play.

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
