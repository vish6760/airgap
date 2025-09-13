#!/bin/bash
set -euo pipefail

# ================================
# Ubuntu Mirror Nginx Setup Script
# ================================

echo "🖥️  Enter the server hostname (FQDN) or IP for this repo:"
read -rp "Server Name (e.g., repo-server.td2.com): " SERVER_NAME

echo "📂 Enter the path where the Ubuntu mirror files should be stored:"
read -rp "Mirror Root (e.g., /srv/mirror/ubuntu): " MIRROR_ROOT

SITE_NAME="ubuntu-mirror"
NGINX_AVAILABLE="/etc/nginx/sites-available/$SITE_NAME"
NGINX_ENABLED="/etc/nginx/sites-enabled/$SITE_NAME"

echo "🔄 Updating system packages..."
sudo apt update
sudo apt upgrade -y

echo "📦 Installing Nginx..."
sudo apt install -y nginx

echo "✅ Ensuring Nginx is running and enabled on boot..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "📂 Creating mirror root directory: $MIRROR_ROOT"
sudo mkdir -p "$MIRROR_ROOT"
sudo chown -R www-data:www-data "$MIRROR_ROOT"
sudo chmod -R 755 "$MIRROR_ROOT"

echo "📝 Creating Nginx site config..."
sudo tee "$NGINX_AVAILABLE" > /dev/null <<EOF
server {
    listen 80;
    server_name $SERVER_NAME;

    root $MIRROR_ROOT;
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    location / {
        try_files \$uri \$uri/ =404;
        client_max_body_size 2G;
    }

    access_log /var/log/nginx/${SITE_NAME}_access.log;
    error_log /var/log/nginx/${SITE_NAME}_error.log;
}
EOF

echo "🔗 Enabling site..."
sudo ln -sf "$NGINX_AVAILABLE" "$NGINX_ENABLED"

echo "🔍 Testing Nginx config..."
sudo nginx -t

echo "🔄 Reloading Nginx..."
sudo systemctl reload nginx

echo "📝 Generating sources.list templates inside $MIRROR_ROOT"

# Jammy template
cat > "$HOME/sources.list.jammy" <<EOF
# Jammy archive
deb [arch=amd64] http://$SERVER_NAME/jammy/archive jammy main restricted universe multiverse
deb [arch=amd64] http://$SERVER_NAME/jammy/archive jammy-updates main restricted universe multiverse
deb [arch=amd64] http://$SERVER_NAME/jammy/archive jammy-backports main restricted universe multiverse

# Jammy security
deb [arch=amd64] http://$SERVER_NAME/jammy/security jammy-security main restricted universe multiverse
EOF

# Noble template
cat > "$HOME/sources.list.noble" <<EOF
# Noble archive
deb [arch=amd64] http://$SERVER_NAME/noble/archive noble main restricted universe multiverse
deb [arch=amd64] http://$SERVER_NAME/noble/archive noble-updates main restricted universe multiverse
deb [arch=amd64] http://$SERVER_NAME/noble/archive noble-backports main restricted universe multiverse

# Noble security
deb [arch=amd64] http://$SERVER_NAME/noble/security noble-security main restricted universe multiverse
EOF

echo "🎉 Setup complete!"
echo "Your repo should now be accessible at: http://$SERVER_NAME/"
echo "📂 Mirror root: $MIRROR_ROOT"
echo "📑 Client sources.list templates generated:"
echo "   - $MIRROR_ROOT/sources.list.jammy"
echo "   - $MIRROR_ROOT/sources.list.noble"
