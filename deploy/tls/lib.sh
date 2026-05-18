#!/usr/bin/env bash
# lib.sh — Shared helper functions for TLS scripts.
# Source this from generate-self-signed.sh and rotate-cert.sh.

# Build OpenSSL [alt_names] block from san.conf variables.
# Expects: SERVER_IP, EXTRA_IPS, EXTRA_DNS to be set (via san.conf).
build_alt_names() {
    local ip_idx=1
    local dns_idx=1
    local block=""
    block+="IP.${ip_idx} = ${SERVER_IP}\n"
    ip_idx=$((ip_idx + 1))
    for ip in $EXTRA_IPS; do
        block+="IP.${ip_idx} = ${ip}\n"
        ip_idx=$((ip_idx + 1))
    done
    for dns in $EXTRA_DNS; do
        block+="DNS.${dns_idx} = ${dns}\n"
        dns_idx=$((dns_idx + 1))
    done
    echo -e "$block"
}
