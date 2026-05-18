#!/usr/bin/env bash
# generate-self-signed.sh — Generate self-signed ECDSA certificate for FamilyLedger
#
# Usage:
#   ./generate-self-signed.sh [output_dir]
#
# All configuration (IPs, DNS names, validity) is read from san.conf.
#
# Generates:
#   ca.pem         — Self-signed CA certificate
#   ca-key.pem     — CA private key (keep secure!)
#   server.pem     — Server certificate (signed by CA)
#   server-key.pem — Server private key
#   client.pem     — Client certificate for mTLS (optional)
#   client-key.pem — Client private key for mTLS (optional)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${1:-./certs}"

# Load shared configuration and helpers
# shellcheck source=san.conf
source "$SCRIPT_DIR/san.conf"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

mkdir -p "$OUTPUT_DIR"

ALT_NAMES=$(build_alt_names)

echo "=== Generating self-signed CA (${CA_DAYS} days) ==="
openssl ecparam -genkey -name prime256v1 -out "$OUTPUT_DIR/ca-key.pem" 2>/dev/null
openssl req -new -x509 -sha256 \
    -key "$OUTPUT_DIR/ca-key.pem" \
    -out "$OUTPUT_DIR/ca.pem" \
    -days "$CA_DAYS" \
    -subj "/C=CN/O=FamilyLedger/CN=FamilyLedger CA"

echo "=== Generating server certificate (${SERVER_DAYS} days) ==="
openssl ecparam -genkey -name prime256v1 -out "$OUTPUT_DIR/server-key.pem" 2>/dev/null

cat > "$OUTPUT_DIR/_server-csr.conf" <<EOF
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
${ALT_NAMES}
EOF

openssl req -new -sha256 \
    -key "$OUTPUT_DIR/server-key.pem" \
    -out "$OUTPUT_DIR/server.csr" \
    -config "$OUTPUT_DIR/_server-csr.conf"

cat > "$OUTPUT_DIR/_server-ext.conf" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
${ALT_NAMES}
EOF

openssl x509 -req -sha256 \
    -in "$OUTPUT_DIR/server.csr" \
    -CA "$OUTPUT_DIR/ca.pem" \
    -CAkey "$OUTPUT_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$OUTPUT_DIR/server.pem" \
    -days "$SERVER_DAYS" \
    -extfile "$OUTPUT_DIR/_server-ext.conf"

echo "=== Generating client certificate (for mTLS, optional) ==="
openssl ecparam -genkey -name prime256v1 -out "$OUTPUT_DIR/client-key.pem" 2>/dev/null
openssl req -new -sha256 \
    -key "$OUTPUT_DIR/client-key.pem" \
    -out "$OUTPUT_DIR/client.csr" \
    -subj "/C=CN/O=FamilyLedger/CN=familyledger-client"

cat > "$OUTPUT_DIR/_client-ext.conf" <<EOF
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
    -days "$SERVER_DAYS" \
    -extfile "$OUTPUT_DIR/_client-ext.conf"

# Cleanup intermediate files
rm -f "$OUTPUT_DIR"/*.csr "$OUTPUT_DIR"/_*.conf "$OUTPUT_DIR"/*.srl

# Set permissions
chmod 600 "$OUTPUT_DIR"/*-key.pem
chmod 644 "$OUTPUT_DIR"/ca.pem "$OUTPUT_DIR"/server.pem "$OUTPUT_DIR"/client.pem

echo ""
echo "=== Done! ==="
echo ""
echo "Files generated in $OUTPUT_DIR:"
ls -la "$OUTPUT_DIR"
echo ""
echo "CA valid:     ${CA_DAYS} days"
echo "Server valid: ${SERVER_DAYS} days"
echo ""
echo "Server deployment:"
echo "  export TLS_CERT_FILE=$OUTPUT_DIR/server.pem"
echo "  export TLS_KEY_FILE=$OUTPUT_DIR/server-key.pem"
echo "  export TLS_CA_FILE=$OUTPUT_DIR/ca.pem  # enables mTLS (optional)"
echo ""
echo "Verify:"
echo "  openssl x509 -in $OUTPUT_DIR/server.pem -text -noout | grep -A2 'Subject Alternative'"
