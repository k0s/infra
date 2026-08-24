# k0s/infra

Ansible playbooks for bringing a k0s.org-family machine to a known state —
backup, hosting, sync, desktop tooling. Public by design (see
[Privacy](#privacy) below); this repo replaces the previously-unversioned
`~/web/ansible/` on Puffin.

Design history and the broader "zero to k0s.org clone" plan live in the
[clawdette](https://github.com/k0s/clawdette) repo's `projects/infra/` — this
repo is the *execution* artifact; clawdette is the *brain* that decided its
shape. See clawdette's `how-k0s-computers-work.md` for the full picture of how
this fits with dotfiles (`k0s/config`) and sync/backup.

## Layout

```
highstate.yml            # applies everything — the single entry point
inventory.ini             # remote/server host(s)
localhost.ini              # ansible_connection=local, for running against the box itself
k0s-infra-vars.yml.example # template for the untracked ~/web/k0s-infra-vars.yml
links.json.example         # template for the untracked ~/web/links.json
k0s-infra-hosts.ini.example # template for the untracked ~/web/k0s-infra-hosts.ini
roles/
  restic/             # versioned local + off-site backup (server role)
  forge/               # GNOME tiling extension (desktop role)
  k0sngin_service/     # k0sNgin systemd service + website hosting (server role)
  links/               # website content symlinks (server role)
  syncthing/           # install + enable Syncthing (any role)
```

**Scope boundary worth knowing:** this repo does not install the k0sNgin
*application* — that playbook (`install_k0sNgin.yaml`, clone + `uv sync`)
lives in the [k0sNgin](https://github.com/k0s/k0sNgin) repo's own
`infra/ansible/`, since a project's deployment playbook belongs with the
project. `roles/k0sngin_service` here only wires up the *host-level* systemd
service once the app is already installed.

## Host-specific / private config

Directory layout, peer hostnames, and account names aren't secrets, but
they're personal/topology data with no business sitting in a public repo
permanently. Three untracked files on the control host hold that data:

- **`~/web/k0s-infra-vars.yml`** — role variables (`restic_user`,
  `restic_sync_dirs`, `restic_offsite_host`, `restic_offsite_path`,
  `k0sngin_service_user`, `links_file`), loaded via `highstate.yml`'s
  `vars_files`. Copy [`k0s-infra-vars.yml.example`](k0s-infra-vars.yml.example)
  there and fill it in first. None of these have role defaults — missing the
  file fails fast rather than silently running with a wrong value.
- **`~/web/links.json`** (path given by `links_file` above) — the real website
  content-symlink mappings (real paths under your `$HOME`), read by both
  `roles/links` and the live k0sNgin service (`K0SNGIN_LINKS`) — one variable,
  not a path duplicated in two places. Copy
  [`links.json.example`](links.json.example) there and fill it in.
- **`~/web/k0s-infra-hosts.ini`** — real internal hostnames (an off-site
  backup peer, other LAN machines), passed as a second `-i` alongside
  `inventory.ini` rather than folded into it. `inventory.ini`'s `k0s.org` is
  already a public domain name and stays tracked; internal topology doesn't,
  even though it's just inventory syntax rather than a role variable. Copy
  [`k0s-infra-hosts.ini.example`](k0s-infra-hosts.ini.example) there and fill
  it in. Usage:
  `ansible-playbook -i inventory.ini -i ~/web/k0s-infra-hosts.ini highstate.yml --limit <host> ...`

`~/web` specifically because it's the established home for this kind of
config already (`~/.silvermirror` → `~/web/sync.ini` follows the same
pattern), and because `~/web` is itself synced+backed-up, so all three files
propagate to every machine in the mesh automatically. Missing a vars file
fails fast with a clear undefined-variable error — verified 2026-08-22 for
`k0s-infra-vars.yml`, intentional, not a bug. The hosts file (added
2026-08-23, first needed when targeting `pop-os`) is additive instead —
omit `-i ~/web/k0s-infra-hosts.ini` and you simply can't `--limit` to a host
it names, no error.

**Audited 2026-08-22** for any remaining hardcoded personal paths/usernames
(`grep -rn "/home/jhammel\|jhammel"`, repo-wide) after this pattern was
introduced — `User=jhammel` in the three `restic-*.service` files and
`k0sngin_service_user: jhammel` in a role default were the last holdouts,
now fixed (templated / externalized). Re-run that grep after adding new
roles; it's cheap and catches this class of leak early.

## Usage

Always dry-run first — see exactly what would change before anything does:

```sh
ansible-playbook -i localhost.ini highstate.yml --check --diff
```

Then apply for real. Root actions are never unattended: every role that needs
`become` will prompt interactively — there's no stored become secret, ever.

```sh
ansible-playbook -i localhost.ini highstate.yml --ask-become-pass
```

Select a subset with `--tags` (e.g. bringing up a fresh box that isn't the
backup/hosting server):

```sh
ansible-playbook -i localhost.ini highstate.yml --tags syncthing,links --ask-become-pass
```

`syncthing` specifically also shares folders with every other host in the
`syncthing_mesh` inventory group (see `k0s-infra-hosts.ini.example`) — run it
against the whole group in one invocation, not `--limit` to a single host:

```sh
ansible-playbook -i inventory.ini -i ~/web/k0s-infra-hosts.ini highstate.yml \
  --limit syncthing_mesh --tags syncthing --ask-become-pass
```

**`--check` has real blind spots** — it can't see through raw `command`/`shell`
tasks (forge's build steps, restic's `restic init`) or reliably predict some
conditional-on-registered-result tasks. Read the task names in the diff
output, not just the pass/fail summary, for those.

It also can't chain a hypothetical change forward: on a from-scratch dry run,
`syncthing`'s package-install step reports a *hypothetical* change, but the
very next task really queries systemd for that package's `syncthing@.service`
unit — which genuinely doesn't exist yet, since nothing was actually
installed. That surfaces as a real `ERROR` on a clean first dry run (confirmed
2026-08-23), even though a real apply installs the package first and then
succeeds normally. Not a bug — a dry-run-of-a-fresh-install limitation.

## Rollback / restore

No role in here does anything destructive by default (restic backups
accumulate, they aren't overwritten; symlinks are additive; package installs
don't remove other packages) — but if a run needs undoing:

1. **Config/code:** this repo is git — `git revert` the offending commit and
   re-run `highstate.yml --check --diff` to confirm the revert converges back
   cleanly.
2. **Per-role specifics:** `roles/forge` documents its own rollback in its
   task output (restore the `.bak` extension directory it creates before
   installing). Other roles are new/thin enough that "remove what it added"
   is the whole story — see each role's tasks.
3. **Not yet exercised for real.** This repo is newly populated
   (2026-08-22) and hasn't been run against live infrastructure yet — treat
   the above as the intended strategy, not a tested one, until it has.

## CI

GitHub Actions runs `yamllint`, `ansible-lint` (`basic` profile), and an
Ansible syntax-check on every push/PR — static checks only. Real functional
testing happens against real hosts (Puffin, pop-os), not CI runners.

## Privacy

This repo is **public**. Every playbook here follows clawdette's
secrets-from-environment rule: no literal passwords, tokens, or keys — ever.
Anything that needs a secret reads it from the host's environment/secret
store at run time (see e.g. `roles/restic`, which generates and stores its
repo password locally on the target host, never in this repo).
