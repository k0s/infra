# asp_service

[asp](https://github.com/k0s/asp) as a systemd **user** service, for hosts in
`asp_hosts`: it watches the directories in its configuration, runs the rules of
its watchers when something changes, and serves its dashboard on loopback.

- asp and its watchers in one virtualenv (`~/.local/lib/asp/venv`), installed
  with [uv](https://docs.astral.sh/uv/), which must already be installed for the
  user. Nothing here needs root, unless `asp_service_linger` is set.
- The configuration is written from `asp_service_config` to `~/.config/asp/asp.json`.
- `asp serve --watch`: a pass a couple of seconds after each change, and every 15
  minutes regardless.

## Configure

`asp_service_config` is required and host-specific, so it goes in the untracked vars
file. It is asp's `asp.json`, as YAML:

```yaml
asp_service_config:
  roots:
    site: "~/site"
    gallery: "~/pictures/gallery"
  db: "~/.local/state/asp/asp.db"
  watchers: [snakewatchers.thumbs]
```

asp does not follow symlinks; a directory reached through one needs its own root.

Per host, in the inventory: `asp_service_port` (default 8765). `asp_service_linger=true` keeps the
service running with nobody logged in; it runs `loginctl enable-linger`, so apply
with `--ask-become-pass`.

## Operate

- Status: `systemctl --user status asp`, or the dashboard at
  `http://127.0.0.1:<asp_service_port>/`.
- New asp or watcher commits: apply with `-e asp_service_upgrade=true`.
- Logs: `journalctl --user -u asp`.
- Changing `asp_service_config` restarts the service.

Applying twice changes nothing. The journal survives reinstalls; deleting it
loses only history.
