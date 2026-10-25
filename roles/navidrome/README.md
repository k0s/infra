# navidrome

Navidrome music server as a systemd service, for hosts in `media_hosts`.

- Pinned release tarball, SHA-256 verified, under `/opt/navidrome/<version>`.
- Configured only through `ND_*` environment variables in the unit; no config file.
- Listens on `127.0.0.1:4533` by default. Use a browser on the host itself.
- Reads `~/music`; home is read-only to the service (`ProtectHome=read-only`).
- Also installs mpv (jukebox mode, local players) and ffmpeg (transcoding).

Requires `navidrome_user` in the untracked vars file. The first browser visit
creates the admin account.

Upgrade: bump `navidrome_version` and `navidrome_sha256` together, from the
release's `navidrome_checksums.txt`.
