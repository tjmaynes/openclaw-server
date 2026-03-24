# Agents

## Project overview

Ansible project that provisions and deploys an OpenClaw personal assistant on an ARM64 Ubuntu Server VM managed by [lume](https://github.com/trycua/lume).

## Structure

```
playbooks/deploy.yml    # Single playbook — runs all roles
roles/
  openclaw/             # Daemon setup, env vars, additional packages
  tailscale/            # Tailnet join, firewall rules, binary permissions
  mise/                 # Runtime installer (Python, etc.)
vars/
  common.yml            # Shared variables
  vault.yml             # Encrypted secrets (ansible-vault)
inventory/hosts.yml     # Host definitions with per-host variables
```

## Key conventions

- One playbook (`deploy.yml`) handles both initial setup and updates
- System-level tasks run as root (`become: true` at play level)
- OpenClaw-specific tasks use `become_user: openclaw` at the task level
- Secrets are stored in `vars/vault.yml` and encrypted with `ansible-vault`
- Host-specific variables (e.g. `openclaw_name`) go in `inventory/hosts.yml`, not in roles
- Environment variables for the openclaw user are managed via `~/.config/environment.d/*.conf` files
- SSH key for GitHub access is generated on-server (never committed), linked to the `bewoogiebot` GitHub account
- All tasks must be idempotent — safe to re-run without side effects

## Secrets

Sensitive values use `no_log: true` and file mode `0600`. Always run `make encrypt` after editing `vars/vault.yml`.

This repo is public — never commit plaintext secrets. Host IPs, tokens, and auth keys go in the encrypted vault.
