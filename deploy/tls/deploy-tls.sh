#!/usr/bin/env bash
# deploy-tls.sh — Deploy TLS certificates to remote server and restart service
#
# Usage:
#   ./deploy-tls.sh [certs_dir] [ssh_host]
#
# Defaults:
#   certs_dir = ./certs
#   ssh_host  = root@124.222.52.10
#
# Prerequisites:
#   - SSH key access to the server
#   - Certificates generated via generate-self-signed.sh
#   - Server binary compiled with tlsconf package

set -euo pipefail

CERTS_DIR="${1:-./certs}"
SSH_HOST="${2:-root@124.222.52.10}"
REMOTE_CERT_DIR="/etc/familyledger/tls"
SERVICE_NAME="familyledger"

echo "=== Deploying TLS certificates to $SSH_HOST ==="

# Verify local cert files exist
for f in ca.pem server.pem server-key.pem; do
    if [[ ! -f "$CERTS_DIR/$f" ]]; then
        echo "ERROR: $CERTS_DIR/$f not found. Run generate-self-signed.sh first."
        exit 1
    fi
done

# Create remote directory
ssh "$SSH_HOST" "mkdir -p $REMOTE_CERT_DIR && chmod 700 $REMOTE_CERT_DIR"

# Upload certificates
scp "$CERTS_DIR/ca.pem" "$SSH_HOST:$REMOTE_CERT_DIR/ca.pem"
scp "$CERTS_DIR/server.pem" "$SSH_HOST:$REMOTE_CERT_DIR/server.pem"
scp "$CERTS_DIR/server-key.pem" "$SSH_HOST:$REMOTE_CERT_DIR/server-key.pem"

# Set permissions on remote
ssh "$SSH_HOST" "chmod 644 $REMOTE_CERT_DIR/ca.pem $REMOTE_CERT_DIR/server.pem && chmod 600 $REMOTE_CERT_DIR/server-key.pem"

echo "=== Certificates deployed to $REMOTE_CERT_DIR ==="

# Update environment (systemd override or .env file)
echo ""
echo "=== Configuring environment ==="
ssh "$SSH_HOST" "cat > /etc/familyledger/tls.env <<EOF
TLS_CERT_FILE=$REMOTE_CERT_DIR/server.pem
TLS_KEY_FILE=$REMOTE_CERT_DIR/server-key.pem
# Uncomment to enable mTLS (client certificate verification):
# TLS_CA_FILE=$REMOTE_CERT_DIR/ca.pem
EOF
chmod 600 /etc/familyledger/tls.env"

echo "=== Environment configured ==="

# Check if systemd service exists
if ssh "$SSH_HOST" "systemctl is-active --quiet $SERVICE_NAME 2>/dev/null"; then
    echo ""
    echo "=== Restarting $SERVICE_NAME service ==="
    ssh "$SSH_HOST" "systemctl restart $SERVICE_NAME"
    sleep 2
    ssh "$SSH_HOST" "systemctl status $SERVICE_NAME --no-pager -l | head -20"
else
    echo ""
    echo "NOTE: No systemd service '$SERVICE_NAME' found."
    echo "Add to your server startup script:"
    echo "  source /etc/familyledger/tls.env"
    echo ""
    echo "Or if using docker-compose, add to environment:"
    echo "  - TLS_CERT_FILE=$REMOTE_CERT_DIR/server.pem"
    echo "  - TLS_KEY_FILE=$REMOTE_CERT_DIR/server-key.pem"
fi

echo ""
echo "=== Verifying TLS ==="
echo "Testing gRPC TLS (port 50051):"
echo "  openssl s_client -connect ${SSH_HOST#*@}:50051 -brief 2>/dev/null | head -5"
echo ""
echo "Testing WebSocket TLS (port 8080):"
echo "  openssl s_client -connect ${SSH_HOST#*@}:8080 -brief 2>/dev/null | head -5"
echo ""
echo "Done! Set AppConstants.useTls = true in Flutter and release."
