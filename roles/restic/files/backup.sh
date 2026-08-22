#!/bin/bash
# restic backup wrapper — reads the directory list from a file rather than
# baking it into the systemd unit, so what gets backed up can change without
# editing/regenerating a unit file (see /etc/restic/sync-dirs.txt, rendered
# by the restic role from restic_sync_dirs).
#
# Generic and host-independent by design: no paths are hardcoded here.

set -euo pipefail

mapfile -t dirs < /etc/restic/sync-dirs.txt

exec restic backup "${dirs[@]}" \
  --exclude-caches \
  --exclude-file=/etc/restic/excludes.txt \
  --tag mesh
