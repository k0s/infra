# base

Packages every k0s machine has, independent of whether it is a server, a
desktop, or a box being evaluated.

```sh
ansible-playbook -i localhost.ini highstate.yml --tags base --ask-become-pass
```

Override the set with `base_packages`.

## Why this exists

`zero-to-k0s-computer.md` installs these by hand during bootstrap. This role does
not replace that step and cannot: Ansible cannot install the package that runs
Ansible, and it cannot bootstrap the SSH it would need to reach a remote host at all.
The bootstrap remains irreducibly manual.

`openssh-server` is deliberately excluded. Puffin accepts no inbound SSH by
design, and a base role must never change a host's network exposure as a side
effect — a `--check` run caught exactly that before this merged.

What it does buy is that the set is **explicit and identical everywhere**, rather
than depending on whoever built each machine having remembered. `python-is-python3`
is here because its absence broke shell login on a new machine (2026-09-06) while
every older host had it — the exact drift a base role exists to catch.
