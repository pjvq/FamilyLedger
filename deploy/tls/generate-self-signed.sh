#!/usr/bin/env bash
# generate-self-signed.sh — Generate self-signed ECDSA certificate for FamilyLedger
#
# Usage:
#   ./generate-self-signed.sh [output_dir] [days] [ip]
#
# Defaults:
#   output_dir = ./certs
#   days       = 3650 (10 years, self-signed doesn't need short-lived)
#   ip         = 124.222.52.10
#
# Generates:
#   ca.pem        — Self-signed CA certificate
#   ca-key.pem    — CA private key (keep secure!)
#   server.pem    — Server certificate (signed by CA)
#   server-key.pem — Server private key
#   client.pem    — Client certificate for mTLS (optional)
#   client-key.pem — Client private key for mTLS (optional)
#
# Why a CA + server cert instead of a bare self-signed cert?
# - Allows issuing client certs for mTLS later
# - Flutter can pin the CA cert (one pin covers cert rotation)
# - Proper chain validation even with self-signed

set -euo pipefail

OUTPUT_DIR="${1:-./certs}"
DAYS="${2:-3650}"
SERVER_IP="${3:-124.222.52.10}"

mkdir -p "$OUTPUT_DIR"

echo "=== Generating self-signed CA ==="
openssl ecparam -genkey -name prime256v1 -out "$OUTPUT_DIR/ca-key.pem" 2>/dev/null
openssl req -new -x509 -sha256 \
    -key "$OUTPUT_DIR/ca-key.pem" \
    -out "$OUTPUT_DIR/ca.pem" \
    -days "$DAYS" \
    -subj "/C=CN/O=FamilyLedger/CN=FamilyLedger CA"

echo "=== Generating server certificate ==="
openssl ecparam -genkey -name prime256v1 -out "$OUTPUT_DIR/server-key.pem" 2>/dev/null

# Create CSR config with SAN (Subject Alternative Name)
cat > "$OUTPUT_DIR/server-csr.conf" <<EOF
[req]
default_bits = 256
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
    -key "$OUTPUT_DIR/server-key.pem" \
    -out "$OUTPUT_DIR/server.csr" \
    -config "$OUTPUT_DIR/server-csr.conf"

# Sign with CA
cat > "$OUTPUT_DIR/server-ext.conf" <<EOF
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
    -in "$OUTPUT_DIR/server.csr" \
    -CA "$OUTPUT_DIR/ca.pem" \
    -CAkey "$OUTPUT_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$OUTPUT_DIR/server.pem" \
    -days "$DAYS" \
    -extfile "$OUTPUT_DIR/server-ext.conf"

echo "=== Generating client certificate (for mTLS, optional) ==="
openssl ecparam -genkey -name prime256v1 -out "$OUTPUT_DIR/client-key.pem" 2>/dev/null
openssl req -new -sha256 \
    -key "$OUTPUT_DIR/client-key.pem" \
    -out "$OUTPUT_DIR/client.csr" \
    -subj "/C=CN/O=FamilyLedger/CN=familyledger-client"

cat > "$OUTPUT_DIR/client-ext.conf" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature
extendedKeyUsage = clientAuth
EOF

openssl x509 -req -sha256 \
    -in "$OUTPUT_DIR/client.csr" \
    -CA "$OUTPUT_DIR/ca.pem" \
    -CAkey "$OUTPUT_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$OUTPUT_DIR/client.pem" \
    -days "$DAYS" \
    -extfile "$OUTPUT_DIR/client-ext.conf"

# Cleanup CSR and intermediate files
rm -f "$OUTPUT_DIR"/*.csr "$OUTPUT_DIR"/*.conf "$OUTPUT_DIR"/*.srl

# Set permissions
chmod 600 "$OUTPUT_DIR"/*-key.pem
chmod 644 "$OUTPUT_DIR"/ca.pem "$OUTPUT_DIR"/server.pem "$OUTPUT_DIR"/client.pem

echo ""
echo "=== Done! ==="
echo ""
echo "Files generated in $OUTPUT_DIR:"
ls -la "$OUTPUT_DIR"
echo ""
echo "Server deployment:"
echo "  export TLS_CERT_FILE=$OUTPUT_DIR/server.pem"
echo "  export TLS_KEY_FILE=$OUTPUT_DIR/server-key.pem"
echo "  export TLS_CA_FILE=$OUTPUT_DIR/ca.pem  # enables mTLS (optional)"
echo ""
echo "Flutter cert pinning (copy ca.pem to app assets):"
echo "  cp $OUTPUT_DIR/ca.pem app/assets/certs/ca.pem"
echo ""
echo "Verify:"
echo "  openssl x509 -in $OUTPUT_DIR/server.pem -text -noout | grep -A2 'Subject Alternative'"
