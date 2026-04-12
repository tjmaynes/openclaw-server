#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/configuration"
EXAMPLE_DIR="$PROJECT_ROOT/configuration.example"

# --- Guard ---
if [ -d "$CONFIG_DIR" ]; then
  echo "Error: configuration/ already exists."
  echo "Remove it first to reinitialize: rm -rf configuration/"
  exit 1
fi

if [ ! -d "$EXAMPLE_DIR" ]; then
  echo "Error: configuration.example/ not found. Is this the project root?"
  exit 1
fi

echo ""
echo "Agent Playbooks — Project Setup"
echo "================================"
echo ""

# --- SSH / Ansible settings ---
printf "Remote SSH user [%s]: " "$USER"
read -r remote_user
remote_user="${remote_user:-$USER}"

printf "SSH private key path [~/.ssh/id_ed25519]: "
read -r ssh_key_path
ssh_key_path="${ssh_key_path:-~/.ssh/id_ed25519}"

# --- Vault password ---
echo ""
while true; do
  printf "Vault password: "
  read -r -s vault_password
  echo ""
  printf "Confirm vault password: "
  read -r -s vault_password_confirm
  echo ""
  if [ "$vault_password" = "$vault_password_confirm" ]; then
    break
  fi
  echo "Passwords do not match. Try again."
  echo ""
done

# --- Host settings ---
echo ""
while true; do
  printf "Host name: "
  read -r host_name
  if echo "$host_name" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    break
  fi
  echo "Invalid name. Use only letters, numbers, hyphens, and underscores."
done

printf "Host IP: "
read -r host_ip

# --- Scaffold configuration/ ---
echo ""
echo "Generating configuration/..."

cp -r "$EXAMPLE_DIR" "$CONFIG_DIR"

# Patch ansible.cfg
sed -i '' "s|CHANGEME_REMOTE_USER|${remote_user}|g" "$CONFIG_DIR/ansible.cfg"
sed -i '' "s|CHANGEME_SSH_KEY_PATH|${ssh_key_path}|g" "$CONFIG_DIR/ansible.cfg"

# Patch hosts.yml — replace placeholder with actual host name
sed -i '' "s|CHANGEME_HOST_NAME|${host_name}|g" "$CONFIG_DIR/hosts.yml"

# Patch vault.yml — replace placeholder with actual host name and IP
sed -i '' "s|CHANGEME_HOST_NAME|${host_name}|g" "$CONFIG_DIR/vault.yml"
sed -i '' "s|${host_name}_ip: \"CHANGEME\"|${host_name}_ip: \"${host_ip}\"|g" "$CONFIG_DIR/vault.yml"

# Patch deploy.yml — set host name
sed -i '' "s|hosts:.*|hosts: ${host_name}|" "$CONFIG_DIR/deploy.yml"

# Write vault password
printf '%s' "$vault_password" > "$CONFIG_DIR/.vault_pass"
chmod 600 "$CONFIG_DIR/.vault_pass"

echo ""
echo "Created configuration/"
echo "  ansible.cfg       — remote_user: ${remote_user}"
echo "  deploy.yml        — hermes stack targeting ${host_name}"
echo "  hosts.yml         — host: ${host_name} (${host_ip})"
echo "  vault.yml         — secrets placeholder (edit before encrypting)"
echo "  requirements.yml  — collection dependencies"
echo "  .vault_pass       — vault password"
echo ""
echo "Next steps:"
echo "  1. Edit configuration/vault.yml with your real secrets"
echo "  2. make encrypt"
echo "  3. make setup HOST=${host_name}"
echo "  4. make deploy HOST=${host_name}"
echo ""
