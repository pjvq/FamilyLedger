#!/usr/bin/env bash
# rotate-cert.sh — Rotate TLS certificates with zero downtime (SIGHUP reload)
#
# Usage:
#   ./rotate-cert.sh [certs_dir] [ssh_host]
#
# This script:
#   1. Generates new certificates (same CA, new server cert)
#   2. Deploys to remote server (overwrite)
#   3. Sends SIGHUP to the running process (hot-reload, no restart)
#
# The server uses GetCertificate callback with atomic.Pointer,
# so existing connections continue with old cert, new connections get new cert.

set -euo pipefail

CERTS_DIR="${1:-./certs}"
SSH_HOST="${2:-root@124.222.52.10}"
REMOTE_CERT_DIR="/etc/familyledger/tls"
PROCESS_NAME="familyledger-server"

echo "=== Generating new server certificate (keeping same CA) ==="

# Keep existing CA, only regenerate server cert
SERVER_IP="124.222.52.10"

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
IP.1 = ${SERVER_IP}
IP.2 = 127.0.0.1
DNS.1 = localhost
DNS.2 = familyledger.local
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
IP.1 = ${SERVER_IP}
IP.2 = 127.0.0.1
DNS.1 = localhost
DNS.2 = familyledger.local
EOF

openssl x509 -req -sha256 \
    -in "/tmp/fl-server.csr" \
    -CA "$CERTS_DIR/ca.pem" \
    -CAkey "$CERTS_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$CERTS_DIR/server.pem" \
    -days 3650 \
    -extfile "/tmp/fl-server-ext.conf"

rm -f /tmp/fl-server.csr /tmp/fl-server-csr.conf /tmp/fl-server-ext.conf "$CERTS_DIR/ca.srl"
chmod 600 "$CERTS_DIR/server-key.pem"

echo "=== Deploying new certificate ==="
scp "$CERTS_DIR/server.pem" "$SSH_HOST:$REMOTE_CERT_DIR/server.pem"
scp "$CERTS_DIR/server-key.pem" "$SSH_HOST:$REMOTE_CERT_DIR/server-key.pem"
ssh "$SSH_HOST" "chmod 600 $REMOTE_CERT_DIR/server-key.pem && chmod 644 $REMOTE_CERT_DIR/server.pem"

echo "=== Sending SIGHUP for hot-reload (zero downtime) ==="
ssh "$SSH_HOST" "pkill -HUP -f '$PROCESS_NAME' || true"

echo ""
echo "=== Certificate rotated! ==="
echo "Verify: openssl s_client -connect ${SSH_HOST#*@}:50051 -brief 2>/dev/null | head -3"
