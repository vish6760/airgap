#!/usr/bin/env bash
# ==========================================================
# generate-selfsigned-cert.sh
# ----------------------------------------------------------
# Create a self-signed certificate with multiple DNS SANs.
# Prompts user for CN, SANs, validity, and where to store
# the key/certificate.
# ==========================================================

set -euo pipefail

# ---------- Defaults ----------
DEFAULT_CN="*.td2.com"
DEFAULT_DAYS=365
DEFAULT_SANS=(
  "*.td2.com"
  "pypi.td2.com"
  "harbor.td2.com"
  "trident.td2.com"
  "repo-server.td2.com"
)
DEFAULT_CERT="/etc/ssl/certs/rootCA.crt"
DEFAULT_KEY="/etc/ssl/private/rootCA.key"

# ---------- Ask for values ----------
read -rp "Enter Common Name (CN) [${DEFAULT_CN}]: " CN
CN="${CN:-$DEFAULT_CN}"

read -rp "Validity in days [${DEFAULT_DAYS}]: " DAYS
DAYS="${DAYS:-$DEFAULT_DAYS}"

echo "Default SANs:"
for s in "${DEFAULT_SANS[@]}"; do echo "  - $s"; done
read -rp "Use defaults as starting list? [Y/n]: " use_defaults
use_defaults="${use_defaults:-Y}"

SAN_LIST=()
if [[ "$use_defaults" =~ ^[Yy]$ ]]; then
  SAN_LIST=("${DEFAULT_SANS[@]}")
fi

while true; do
  read -rp "Add SAN DNS entry (leave empty to finish): " new_san
  [[ -z "$new_san" ]] && break
  SAN_LIST+=("$new_san")
done

read -rp "Path to save certificate [${DEFAULT_CERT}]: " CERT_PATH
CERT_PATH="${CERT_PATH:-$DEFAULT_CERT}"

read -rp "Path to save key [${DEFAULT_KEY}]: " KEY_PATH
KEY_PATH="${KEY_PATH:-$DEFAULT_KEY}"

# ---------- Build OpenSSL config ----------
TMPDIR="$(mktemp -d)"
CONF_FILE="${TMPDIR}/san.cnf"

{
  cat <<EOF
[ req ]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = req_ext

[ dn ]
CN = ${CN}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
EOF

  idx=1
  for san in "${SAN_LIST[@]}"; do
    echo "DNS.${idx} = ${san}"
    ((idx++))
  done
} > "${CONF_FILE}"

echo -e "\n➡️  Generated OpenSSL config at ${CONF_FILE}:"
cat "${CONF_FILE}"

# ---------- Generate key + cert ----------
mkdir -p "$(dirname "$CERT_PATH")" "$(dirname "$KEY_PATH")"
openssl req -x509 -nodes -days "${DAYS}" -newkey rsa:4096 \
  -keyout "${KEY_PATH}" \
  -out "${CERT_PATH}" \
  -config "${CONF_FILE}" -extensions req_ext

echo -e "\n✅ Certificate created:"
echo "  Key : ${KEY_PATH}"
echo "  Cert: ${CERT_PATH}"

# ---------- Verify SANs ----------
echo -e "\nVerifying SAN entries:"
openssl x509 -in "${CERT_PATH}" -noout -text | grep -A1 "Subject Alternative Name"

# ---------- Optional: install to trust store ----------
read -rp "Install certificate into system trust store? [y/N]: " install
if [[ "$install" =~ ^[Yy]$ ]]; then
  cp "${CERT_PATH}" "/usr/local/share/ca-certificates/$(basename "$CERT_PATH")"
  update-ca-certificates
fi
