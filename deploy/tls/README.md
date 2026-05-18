# TLS Deployment Guide

## Quick Start

```bash
cd deploy/tls

# 1. Generate certificates (one-time)
chmod +x generate-self-signed.sh
./generate-self-signed.sh ./certs

# 2. Deploy to server
chmod +x deploy-tls.sh
./deploy-tls.sh ./certs root@124.222.52.10

# 3. Verify
openssl s_client -connect 124.222.52.10:50051 -brief

# 4. Update Flutter client
# Set AppConstants.useTls = true, release new version
```

## Certificate Rotation (Zero Downtime)

```bash
chmod +x rotate-cert.sh
./rotate-cert.sh ./certs root@124.222.52.10
```

This regenerates the server cert (same CA), deploys it, and sends SIGHUP.
The server hot-reloads the new cert without restarting.

## Architecture

```
┌─────────────┐     TLS 1.2+      ┌─────────────────────┐
│ Flutter App  │ ◄──────────────► │ Go Server            │
│             │                    │                     │
│ CA pinned   │     gRPC :50051   │ TLS_CERT_FILE       │
│ in assets   │     WSS  :8080    │ TLS_KEY_FILE        │
└─────────────┘                    └─────────────────────┘
                                          │
                                   ┌──────┴──────┐
                                   │ SIGHUP      │
                                   │ hot-reload  │
                                   └─────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `generate-self-signed.sh` | Generate CA + server + client certs |
| `deploy-tls.sh` | Upload certs to server + configure env |
| `rotate-cert.sh` | Rotate server cert with zero downtime |
| `certs/` | Generated certificates (gitignored) |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TLS_CERT_FILE` | Yes | Path to server certificate PEM |
| `TLS_KEY_FILE` | Yes | Path to server private key PEM |
| `TLS_CA_FILE` | No | CA cert for mTLS (client verification) |
| `TLS_MIN_VERSION` | No | "1.2" (default) or "1.3" |

## Security Notes

- **CA key** (`ca-key.pem`) must be kept offline/secure — it can sign new certs
- **Server key** (`server-key.pem`) has 600 permissions on remote
- Self-signed CA is pinned in the Flutter app — no public CA compromise risk
- mTLS is optional: set `TLS_CA_FILE` to require client certificates

## Flutter Cert Pinning

After generating certs, copy CA to app assets:
```bash
mkdir -p app/assets/certs
cp deploy/tls/certs/ca.pem app/assets/certs/ca.pem
```

Then update `grpc_clients.dart` to use pinned CA (see Phase 5).
