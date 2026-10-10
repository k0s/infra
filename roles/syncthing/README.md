# syncthing

Installs Syncthing, gets it running as a systemd service, ensures the folders
in `syncthing_folders` (default: `movies`, `projects`) exist, and **shares
them with every other host in the `syncthing_mesh` inventory group** via the
REST API — a real folder gets configured with the right device list on both
sides, not just installed software (verified 2026-08-23: both hosts converge
to `state: idle`, `needFiles: 0`).

It also **pairs** them, from IDs you pin in the inventory: the one manual trust
step per device is recording its ID, after which runs reconcile devices and
shares with no GUI dialogs on either side. See [Pairing](#pairing-pin-the-id-once).

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

## Pairing: pin the ID once

A device ID is the SHA-256 fingerprint of the device's TLS certificate, so
"accept this device" means "this ID is that machine". This role makes that
decision once, in the inventory, instead of in a GUI on both sides:

1. On the new host, read its ID — `syncthing --device-id` (v1) or
   `syncthing device-id` (v2). Over SSH is fine: SSH already authenticates
   the host, so this is at least as strong as reading it off its screen.
2. Pin it on the host's inventory line and add the host to `syncthing_mesh`:

   ```ini
   [syncthing_mesh]
   localhost syncthing_pinned_device_id=XXXXXXX-...  syncthing_device_name=puffin
   newbox    syncthing_pinned_device_id=XXXXXXX-...  syncthing_folder_type=receiveonly
   ```

3. Run `highstate.yml` against the whole group. Every member adds every other
   member (and the declared extra devices) and sets folder shares; both sides
   change in the same run, so nothing is offered for anyone to accept.

Every run checks the host's live ID against its pin and **fails on a
mismatch** — a reinstall, cloned disk or regenerated certificate is a new
identity, and trusting it is an inventory edit, not something a run does by
itself. Every mesh member must have a pin; a missing or malformed one fails
the play before any API call.

A host **outside** `syncthing_mesh` gets Syncthing installed and running, and
nothing else: no devices added, no folders shared. A new machine's first local
run therefore offers itself to no one.

Pending devices and folder offers (`/rest/cluster/pending/...`) are
**reported, never accepted**: with every device declared, anything pending is
unexpected. So are devices configured on the host but declared nowhere —
removing those is left manual for now.

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

## Introducer and auto-accept: turned off

Both are implicit trust paths — an introducer adds devices on your behalf,
and auto-accept takes any folder a device offers. With every device and share
declared they are redundant, and an introducer fights reconciliation
(introduced devices come back). The role sets `introducer: false` and
`autoAcceptFolders: false` on every declared device, and adds new ones that
way. Devices it doesn't manage (a phone's own device list) are out of reach;
there, auto-accepting folders from one trusted mesh host is a reasonable
one-time choice.

This is the pilot step from clawdette's `sync-backup` project
(`operations/syncthing-pilot.md`) — low-stakes folders first, before trusting
Syncthing with everything Unison currently handles.
