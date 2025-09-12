#!/usr/bin/env bash
set -euo pipefail

LOGFILE="/var/log/setup-devpi.log"
exec > >(tee -a "$LOGFILE") 2>&1

# --- Prompt for user input with defaults ---
read -rp "Enter FQDN [pypi.td2.com]: " FQDN
FQDN=${FQDN:-pypi.td2.com}

read -rp "Enter devpi system user [devpi]: " DEVPI_USER
DEVPI_USER=${DEVPI_USER:-devpi}

read -rp "Enter Devpi data directory [/srv/devpi]: " DEVPI_DIR
DEVPI_DIR=${DEVPI_DIR:-/srv/devpi}

read -rp "Enter Python virtualenv directory [/srv/venv]: " VENV_DIR
VENV_DIR=${VENV_DIR:-/srv/venv}

SYSTEMD_UNIT="/etc/systemd/system/devpi.service"
NGINX_SITE="/etc/nginx/sites-available/devpi"

# --- Error handling ---
error_exit() {
    echo "[ERROR] $1"
    exit 1
}
trap 'error_exit "Line $LINENO: command failed."' ERR

echo "[1/7] Checking prerequisites..."
command -v python3 >/dev/null || error_exit "python3 not installed"
command -v nginx >/dev/null || sudo apt install -y nginx

echo "[2/7] Installing required packages..."
sudo apt update -qq
sudo apt install -y python3 python3-venv python3-pip

echo "[3/7] Creating user and directories..."
if ! id -u "$DEVPI_USER" >/dev/null 2>&1; then
    sudo useradd -r -s /usr/sbin/nologin "$DEVPI_USER"
else
    echo "User $DEVPI_USER already exists, skipping."
fi
sudo mkdir -p "$DEVPI_DIR"
sudo chown -R "$DEVPI_USER:$DEVPI_USER" "$DEVPI_DIR"

echo "[4/7] Creating/updating virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "Created virtualenv at $VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install --upgrade devpi-server devpi-client

echo "[5/7] Initializing devpi (idempotent)..."
if [ ! -f "$DEVPI_DIR/.serverversion" ]; then
    sudo -u "$DEVPI_USER" "$VENV_DIR/bin/devpi-init" --serverdir "$DEVPI_DIR"
else
    echo "Devpi already initialized, skipping."
fi

echo "[6/7] Configuring systemd..."
SYSTEMD_CONTENT=$(cat <<EOF
[Unit]
Description=Devpi PyPI server
After=network.target

[Service]
Type=simple
User=$DEVPI_USER
Group=$DEVPI_USER
ExecStart=$VENV_DIR/bin/devpi-server --serverdir $DEVPI_DIR --host 127.0.0.1 --port 3141 --outside-url https://$FQDN
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
)
if [ ! -f "$SYSTEMD_UNIT" ] || ! diff -q <(echo "$SYSTEMD_CONTENT") "$SYSTEMD_UNIT" >/dev/null; then
    echo "$SYSTEMD_CONTENT" | sudo tee "$SYSTEMD_UNIT" >/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable --now devpi
else
    echo "Systemd config unchanged."
fi

echo "[7/7] Configuring nginx..."
if [ ! -f "$NGINX_SITE" ]; then
    sudo tee "$NGINX_SITE" > /dev/null <<EOF
server {
    listen 80;
    server_name $FQDN;
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $FQDN;
    ssl_certificate     /etc/ssl/certs/rootCA.crt;
    ssl_certificate_key /etc/ssl/private/rootCA.key;

    location / {
        proxy_pass http://127.0.0.1:3141;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    sudo ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
else
    echo "Nginx config already exists, skipping."
fi

echo "✅ Devpi setup complete at https://$FQDN/"

