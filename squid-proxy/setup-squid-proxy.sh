#!/usr/bin/env bash
# =====================================
# Squid Proxy Setup Script
# Automates configuration, whitelist, cache initialization
# Supports Ubuntu 22.04 & 24.04
# =====================================

set -euo pipefail

SQUID_CONF="/etc/squid/squid.conf"
WHITELIST="/etc/squid/whitelist.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Helper Functions ---
error_exit() {
    echo "❌ ERROR: $1" >&2
    exit 1
}

check_command() {
    command -v "$1" >/dev/null 2>&1 || error_exit "$1 command not found. Please install it first."
}

# --- Pre-checks ---
check_command sudo
check_command apt
check_command systemctl

if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root (or with sudo)."
fi

# Check required files
if [[ ! -f "$SCRIPT_DIR/squid.conf" ]]; then
    error_exit "squid.conf not found in $SCRIPT_DIR"
fi

if [[ ! -f "$SCRIPT_DIR/whitelist.txt" ]]; then
    error_exit "whitelist.txt not found in $SCRIPT_DIR"
fi

echo "=== Installing Squid ==="
sudo apt update -y || error_exit "apt update failed"
sudo apt install -y squid || error_exit "Failed to install squid"

# --- Backup existing configuration ---
echo "=== Backing up existing squid.conf ==="
if [ -f "$SQUID_CONF" ]; then
    BACKUP="${SQUID_CONF}.$(date +%F-%H%M%S).bak"
    sudo cp "$SQUID_CONF" "$BACKUP" || error_exit "Failed to backup existing squid.conf"
    echo "Backup saved as $BACKUP"
fi

# --- Deploy configuration ---
echo "=== Deploying squid.conf ==="
sudo cp "$SCRIPT_DIR/squid.conf" "$SQUID_CONF" || error_exit "Failed to copy squid.conf"
sudo chown root:root "$SQUID_CONF"
sudo chmod 644 "$SQUID_CONF"

echo "=== Deploying whitelist.txt ==="
sudo cp "$SCRIPT_DIR/whitelist.txt" "$WHITELIST" || error_exit "Failed to copy whitelist.txt"
sudo chown root:root "$WHITELIST"
sudo chmod 644 "$WHITELIST"

# --- Stop Squid before initializing cache ---
echo "=== Stopping Squid (if running) ==="
sudo systemctl stop squid || true

# --- Initialize cache directories (ignore non-fatal warnings) ---
echo "=== Initializing cache directories ==="
sudo squid -z || echo "⚠️ Cache initialization completed with warnings, continuing..."

# --- Start Squid service ---
echo "=== Starting and enabling Squid service ==="
sudo systemctl start squid || error_exit "Failed to start Squid"
sudo systemctl enable squid || error_exit "Failed to enable Squid on boot"

echo "✅ Squid setup completed successfully"
echo "Whitelist applied from: $WHITELIST"
echo "Squid is listening on port 3128"
echo "Check logs with: sudo tail -f /var/log/squid/access.log"
