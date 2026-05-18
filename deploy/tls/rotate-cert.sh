#!/usr/bin/env bash
# rotate-cert.sh — Rotate TLS certificates with zero downtime (SIGHUP reload)
#
# Usage:
#   ./rotate-cert.sh [certs_dir] [ssh_host]
#
# All configuration (IPs, DNS names, validity) is read from san.conf.
#
# This script:
#   1. Generates new server cert (same CA, fresh key)
#   2. Deploys to remote server (overwrite)
#   3. Sends SIGHUP to the running container (hot-reload, no restart)
#
# The server uses GetCertificate callback with atomic.Pointer,
# so existing connections continue with old cert, new connections get new cert.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERTS_DIR="${1:-./certs}"
SSH_HOST="${2:-ubuntu@124.222.52.10}"
REMOTE_CERT_DIR="/etc/familyledger/tls"
CONTAINER_NAME="familyledger-server"

# Load shared configuration and helpers
# shellcheck source=san.conf
source "$SCRIPT_DIR/san.conf"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ALT_NAMES=$(build_alt_names)

echo "=== Generating new server certificate (keeping same CA, ${SERVER_DAYS} days) ==="

openssl ecparam -genkey -name prime256v1 -out "$CERTS_DIR/server-key.pem" 2>/dev/null

cat > "/tmp/fl-server-csr.conf" <<EOF
[req]
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C = CN
O = FamilyLedger
CN = familyledger-server

[v3_req]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
${ALT_NAMES}
EOF

openssl req -new -sha256 \
    -key "$CERTS_DIR/server-key.pem" \
    -out "/tmp/fl-server.csr" \
    -config "/tmp/fl-server-csr.conf"

cat > "/tmp/fl-server-ext.conf" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
${ALT_NAMES}
EOF

openssl x509 -req -sha256 \
    -in "/tmp/fl-server.csr" \
    -CA "$CERTS_DIR/ca.pem" \
    -CAkey "$CERTS_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$CERTS_DIR/server.pem" \
    -days "$SERVER_DAYS" \
    -extfile "/tmp/fl-server-ext.conf"

rm -f /tmp/fl-server.csr /tmp/fl-server-csr.conf /tmp/fl-server-ext.conf "$CERTS_DIR/ca.srl"
chmod 600 "$CERTS_DIR/server-key.pem"

echo "=== Deploying new certificate ==="
scp "$CERTS_DIR/server.pem" "$SSH_HOST:$REMOTE_CERT_DIR/server.pem"
scp "$CERTS_DIR/server-key.pem" "$SSH_HOST:$REMOTE_CERT_DIR/server-key.pem"
ssh "$SSH_HOST" "sudo chmod 600 $REMOTE_CERT_DIR/server-key.pem && sudo chmod 644 $REMOTE_CERT_DIR/server.pem"

echo "=== Sending SIGHUP for hot-reload (zero downtime) ==="
ssh "$SSH_HOST" "sudo docker kill --signal=HUP $CONTAINER_NAME"

echo ""
echo "=== Certificate rotated! ==="
echo "Verify: openssl s_client -connect ${SSH_HOST#*@}:50051 -brief 2>/dev/null | head -3"
