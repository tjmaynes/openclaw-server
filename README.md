# agent-playbooks

> Ansible playbooks for provisioning agent servers — including [Hermes Agent](https://hermes-agent.nousresearch.com/), [OpenClaw](https://openclaw.org/), and [Claude Code](https://claude.ai/code) — on ARM64 Ubuntu Server VMs managed by [lume](https://github.com/trycua/lume).

## Requirements

- [Python 3](https://www.python.org/)
- [Homebrew](https://brew.sh/) (macOS — used to install [lume](https://github.com/trycua/lume) via the bundled `Brewfile`)
- [Ubuntu Server ARM64 ISO](https://ubuntu.com/download/server/arm)

## Getting Started

### 1. Create VMs

```bash
make setup_rosie     # Create rosie VM (4GB RAM, 60GB disk)
make setup_athena    # Create athena VM (8GB RAM, 110GB disk)
```

This runs `scripts/setup-vm.sh` which creates the lume VM and boots the Ubuntu installer. The script is idempotent — it skips creation if the VM already exists.

### 2. Install Ansible and dependencies

```bash
make install
```

This runs `brew bundle` (installing `lume` from the `Brewfile`), creates a Python virtualenv, and installs the Ansible collections listed in `collections/requirements.yml`.

### 3. Configure secrets

```bash
make decrypt
# Edit vars/vault.yml with real values (IPs, bot tokens)
make encrypt
```

### 4. Deploy

```bash
make deploy HOST=rosie    # Deploy to rosie
make deploy HOST=athena   # Deploy to athena
```

### 5. Post-deploy setup

On first deploy, the hermes role generates an SSH key and prints the public key. Add it to the appropriate GitHub account under Settings > SSH and GPG keys.

Then SSH in and complete interactive setup:

```bash
make connect_hermes HOST=rosie
# Inside the tmux session:
hermes setup          # Authenticate with Nous Portal (OAuth)
hermes model          # Select AI model
hermes memory setup   # Configure Honcho memory backend
```

Start the gateway (systemd service is installed during deploy):

```bash
hermes gateway start
```

Tail the gateway logs:

```bash
hermes-logs
```

### 6. Discord bot setup

Each host needs its own Discord bot. For each host:

**a. Create a Discord application and bot**

Go to the [Discord Developer Portal](https://discord.com/developers/applications) and click **New Application**. Navigate to **Bot**, give it a username, then scroll to **Privileged Gateway Intents** and enable **Message Content Intent**.

**b. Generate a bot token**

On the **Bot** page, click **Reset Token** and copy it. Store it in `vars/vault.yml` as `<host>_bot_token` (e.g., `rosie_bot_token`), then run `make encrypt`.

**c. Invite the bot to a server**

Navigate to **OAuth2** > **URL Generator**. Select the `bot` scope and enable these permissions:
- View Channels
- Send Messages
- Send Messages in Threads
- Read Message History
- Attach Files
- Add Reactions

Set integration type to **Guild Install**, copy the generated URL, and add the bot to your server.

**d. Deploy and configure**

```bash
make deploy HOST=rosie
make connect_hermes HOST=rosie
# Inside the tmux session:
hermes gateway setup   # Configure Discord platform
hermes gateway start
```

## Available Commands

| Command | Purpose |
|---|---|
| `make install` | Install Ansible, ansible-lint, and collections |
| `make setup_rosie` | Create rosie VM (4GB RAM, 60GB disk) |
| `make setup_athena` | Create athena VM (8GB RAM, 110GB disk) |
| `make setup HOST=<name>` | Create a custom VM (8GB RAM, 110GB disk) |
| `make deploy HOST=<name>` | Deploy to a host |
| `make check HOST=<name>` | Dry-run to preview changes |
| `make lint` | Lint playbooks and roles |
| `make encrypt` | Encrypt the vault file |
| `make decrypt` | Decrypt the vault file |
| `make start HOST=<name>` | Start a VM |
| `make connect HOST=<name>` | SSH into a host as hermes user in tmux |

## Architecture

A single playbook (`playbooks/deploy.yml`) provisions all hosts with the same role chain:

1. **`debian`** — base packages (including `gh`), SSH server, service user creation, timezone, unattended-upgrades, custom DNS (optional, via `systemd-resolved` split DNS), git config
2. **`security`** — SSH hardening (key-only, no root login), UFW firewall (rate-limited SSH, deny-by-default), fail2ban (24h progressive bans), custom CA certificate management (system trust store + Chromium NSS database)
3. **`docker`** — rootless Docker running under the service user (no docker group escalation), Honcho memory backend via docker-compose
4. **`mise`** — installs runtimes (Node, Python, Go, direnv, just)
5. **`hermes`** — scoped sudoers, Hermes Agent install (official curl installer), Playwright browser install, Discord gateway config, systemd service via `hermes gateway install`, environment file (`.env`) with per-host config, mise/env activation in bashrc, `hermes-logs` helper, and SSH-based GitHub access

Hosts are defined flat in `inventory/hosts.yml` with per-host variables. Shared configuration lives in play-level vars in the playbook. Per-host secrets come from vault. Deploy one host at a time with `--limit`.

### Optional per-host features

Some features are conditionally enabled based on whether the host defines certain variables:

| Variable | Effect |
|---|---|
| `custom_ca_certificate_path` | Installs CA cert to system trust store and Chromium NSS database |
| `custom_dns_server` / `custom_dns_domain` | Configures split DNS via `systemd-resolved` |
| `github_token` | Adds `GITHUB_TOKEN` and `GH_TOKEN` to hermes `.env` |
| `home_assistant_url` / `home_assistant_token` | Adds `HASS_URL` and `HASS_TOKEN` to hermes `.env` |
| `git_user_name` / `git_user_email` | Configures git identity for the service user |
