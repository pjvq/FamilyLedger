// Package tlsconf provides unified TLS configuration for all server listeners
// (gRPC, WebSocket/HTTP). It supports:
//
//   - File-based certificates (TLS_CERT_FILE/TLS_KEY_FILE)
//   - Automatic certificate reload on SIGHUP (zero-downtime rotation)
//   - Minimum TLS 1.2 with strong cipher suites
//   - Client certificate verification (mTLS) when CA cert is provided
//
// Environment variables:
//
//	TLS_CERT_FILE     — path to PEM-encoded certificate (or chain)
//	TLS_KEY_FILE      — path to PEM-encoded private key
//	TLS_CA_FILE       — path to CA cert for client verification (optional, enables mTLS)
//	TLS_MIN_VERSION   — minimum TLS version: "1.2" (default) or "1.3"
//	TLS_MTLS_MODE     — "required" (default when CA set) or "optional"
//
// Legacy aliases (backwards compatible):
//
//	GRPC_TLS_CERT → TLS_CERT_FILE
//	GRPC_TLS_KEY  → TLS_KEY_FILE
package tlsconf

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"
	"sync/atomic"
)

// Config holds TLS configuration parameters.
type Config struct {
	CertFile   string // Path to PEM certificate file
	KeyFile    string // Path to PEM private key file
	CAFile     string // Path to CA certificate for mTLS (optional)
	MinVersion string // "1.2" or "1.3" (default "1.2")
	MTLSMode   string // "required" (default) or "optional"
}

// LoadFromEnv reads TLS configuration from environment variables.
// Returns (nil, nil) if no TLS cert is configured (TLS disabled).
// Returns non-nil error if configuration is inconsistent (e.g. cert without key).
func LoadFromEnv() (*Config, error) {
	certFile := envWithFallback("TLS_CERT_FILE", "GRPC_TLS_CERT")
	if certFile == "" {
		return nil, nil
	}

	keyFile := envWithFallback("TLS_KEY_FILE", "GRPC_TLS_KEY")
	if keyFile == "" {
		return nil, fmt.Errorf("TLS_CERT_FILE set but TLS_KEY_FILE (or GRPC_TLS_KEY) missing")
	}

	return &Config{
		CertFile:   certFile,
		KeyFile:    keyFile,
		CAFile:     os.Getenv("TLS_CA_FILE"),
		MinVersion: getEnvDefault("TLS_MIN_VERSION", "1.2"),
		MTLSMode:   getEnvDefault("TLS_MTLS_MODE", "required"),
	}, nil
}

// Provider manages TLS credentials with hot-reload support.
// It is safe for concurrent use.
type Provider struct {
	config    Config
	cert      atomic.Pointer[tls.Certificate]
	caPool    *x509.CertPool // immutable after construction
	mu        sync.Mutex     // guards reload
	tlsConfig *tls.Config    // cached, built once
}

// NewProvider creates a TLS provider and loads the initial certificate.
// Returns error if the certificate cannot be loaded.
func NewProvider(cfg Config) (*Provider, error) {
	p := &Provider{config: cfg}

	// Load initial certificate
	if err := p.loadCert(); err != nil {
		return nil, fmt.Errorf("initial cert load: %w", err)
	}

	// Load CA pool if mTLS is configured
	if cfg.CAFile != "" {
		pool, err := loadCAPool(cfg.CAFile)
		if err != nil {
			return nil, fmt.Errorf("load CA file: %w", err)
		}
		p.caPool = pool
		log.Printf("tls: mTLS enabled with CA from %s (mode=%s)", cfg.CAFile, cfg.MTLSMode)
	}

	// Build and cache TLS config once — GetCertificate uses atomic.Pointer
	// so the cached config remains valid across cert reloads.
	p.tlsConfig = p.buildTLSConfig()

	log.Printf("tls: certificate loaded from %s", cfg.CertFile)
	return p, nil
}

// Reload reloads the certificate from disk. Safe to call concurrently.
// Typically connected to SIGHUP handler for zero-downtime cert rotation.
func (p *Provider) Reload() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if err := p.loadCert(); err != nil {
		return fmt.Errorf("cert reload: %w", err)
	}
	log.Printf("tls: certificate reloaded from %s", p.config.CertFile)
	return nil
}

// TLSConfig returns the shared *tls.Config instance.
// The config uses GetCertificate backed by atomic.Pointer, so certificate
// hot-reload is transparent. Both gRPC and WebSocket should use this same
// instance to avoid configuration drift.
func (p *Provider) TLSConfig() *tls.Config {
	return p.tlsConfig
}

// CertFile returns the path to the certificate file.
func (p *Provider) CertFile() string { return p.config.CertFile }

// KeyFile returns the path to the key file.
func (p *Provider) KeyFile() string { return p.config.KeyFile }

func (p *Provider) buildTLSConfig() *tls.Config {
	cfg := &tls.Config{
		GetCertificate: func(_ *tls.ClientHelloInfo) (*tls.Certificate, error) {
			cert := p.cert.Load()
			if cert == nil {
				return nil, fmt.Errorf("no certificate loaded")
			}
			return cert, nil
		},
		MinVersion: p.minVersion(),
		CipherSuites: []uint16{
			// TLS 1.3 ciphers are automatically included and cannot be controlled.
			// These are for TLS 1.2 fallback:
			tls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
			tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
			tls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,
			tls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
		},
		CurvePreferences: []tls.CurveID{
			tls.X25519,
			tls.CurveP256,
		},
	}

	if p.caPool != nil {
		cfg.ClientCAs = p.caPool
		if strings.EqualFold(p.config.MTLSMode, "optional") {
			cfg.ClientAuth = tls.VerifyClientCertIfGiven
		} else {
			cfg.ClientAuth = tls.RequireAndVerifyClientCert
		}
	}

	return cfg
}

func (p *Provider) loadCert() error {
	cert, err := tls.LoadX509KeyPair(p.config.CertFile, p.config.KeyFile)
	if err != nil {
		return err
	}
	p.cert.Store(&cert)
	return nil
}

func (p *Provider) minVersion() uint16 {
	switch strings.TrimSpace(p.config.MinVersion) {
	case "1.3":
		return tls.VersionTLS13
	default:
		return tls.VersionTLS12
	}
}

func loadCAPool(path string) (*x509.CertPool, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(data) {
		return nil, fmt.Errorf("no valid CA certificates found in %s", path)
	}
	return pool, nil
}

func envWithFallback(primary, fallback string) string {
	if v := os.Getenv(primary); v != "" {
		return v
	}
	return os.Getenv(fallback)
}

func getEnvDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
