# samplemark_service

[samplemark](https://github.com/k0s/samplemark) as a systemd **user** service, for
hosts in `samplemark_hosts`. It records the logged-in desktop session's audio
output (PipeWire) during a session started from a phone, so it runs only while
someone is logged in at the host.

- No root. uv is fetched as a pinned, checksum-verified release; the app is cloned
  to `~/src/samplemark` (only if absent) and built with `uv sync --frozen --no-dev`.
- Loopback by default. **samplemark has no authentication**: set
  `samplemark_service_host` per host to serve phones on a trusted LAN.
- `samplemark_service_output` is where clips land; created if missing.

## Deploying a new version

The role installs but never updates, so it can't move a checkout someone is
working in. To deploy:

    cd ~/src/samplemark && git pull --ff-only
    ~/.local/share/samplemark-uv/<version>/uv-x86_64-unknown-linux-gnu/uv sync --frozen --no-dev
    systemctl --user restart samplemark

## Check

    systemctl --user status samplemark
    curl -s http://localhost:8470/ | grep -c samplemark
