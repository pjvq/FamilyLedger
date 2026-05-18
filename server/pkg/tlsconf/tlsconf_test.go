package tlsconf

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLoadFromEnv_NoConfig(t *testing.T) {
	t.Setenv("TLS_CERT_FILE", "")
	t.Setenv("GRPC_TLS_CERT", "")
	cfg, err := LoadFromEnv()
	assert.NoError(t, err)
	assert.Nil(t, cfg)
}

func TestLoadFromEnv_WithCert(t *testing.T) {
	t.Setenv("TLS_CERT_FILE", "/tmp/cert.pem")
	t.Setenv("TLS_KEY_FILE", "/tmp/key.pem")
	t.Setenv("TLS_MIN_VERSION", "1.3")
	cfg, err := LoadFromEnv()
	require.NoError(t, err)
	require.NotNil(t, cfg)
	assert.Equal(t, "/tmp/cert.pem", cfg.CertFile)
	assert.Equal(t, "/tmp/key.pem", cfg.KeyFile)
	assert.Equal(t, "1.3", cfg.MinVersion)
}

func TestLoadFromEnv_CertWithoutKey(t *testing.T) {
	t.Setenv("TLS_CERT_FILE", "/tmp/cert.pem")
	t.Setenv("TLS_KEY_FILE", "")
	t.Setenv("GRPC_TLS_KEY", "")
	_, err := LoadFromEnv()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "TLS_KEY_FILE")
}

func TestLoadFromEnv_LegacyFallback(t *testing.T) {
	t.Setenv("TLS_CERT_FILE", "")
	t.Setenv("GRPC_TLS_CERT", "/legacy/cert.pem")
	t.Setenv("TLS_KEY_FILE", "")
	t.Setenv("GRPC_TLS_KEY", "/legacy/key.pem")
	cfg, err := LoadFromEnv()
	require.NoError(t, err)
	require.NotNil(t, cfg)
	assert.Equal(t, "/legacy/cert.pem", cfg.CertFile)
	assert.Equal(t, "/legacy/key.pem", cfg.KeyFile)
}

func TestNewProvider_InvalidCert(t *testing.T) {
	cfg := Config{CertFile: "/nonexistent/cert.pem", KeyFile: "/nonexistent/key.pem"}
	_, err := NewProvider(cfg)
	assert.Error(t, err)
}

func TestNewProvider_ValidCert(t *testing.T) {
	certFile, keyFile := generateTestCert(t)
	cfg := Config{CertFile: certFile, KeyFile: keyFile, MinVersion: "1.2"}
	p, err := NewProvider(cfg)
	require.NoError(t, err)

	tlsCfg := p.TLSConfig()
	assert.Equal(t, uint16(tls.VersionTLS12), tlsCfg.MinVersion)
	assert.NotNil(t, tlsCfg.GetCertificate)

	// GetCertificate should return a valid cert
	cert, err := tlsCfg.GetCertificate(nil)
	require.NoError(t, err)
	assert.NotNil(t, cert)
}

func TestProvider_Reload(t *testing.T) {
	certFile, keyFile := generateTestCert(t)
	cfg := Config{CertFile: certFile, KeyFile: keyFile}
	p, err := NewProvider(cfg)
	require.NoError(t, err)

	// Reload with same cert should succeed
	err = p.Reload()
	assert.NoError(t, err)
}

func TestProvider_TLS13(t *testing.T) {
	certFile, keyFile := generateTestCert(t)
	cfg := Config{CertFile: certFile, KeyFile: keyFile, MinVersion: "1.3"}
	p, err := NewProvider(cfg)
	require.NoError(t, err)

	tlsCfg := p.TLSConfig()
	assert.Equal(t, uint16(tls.VersionTLS13), tlsCfg.MinVersion)
}

func TestProvider_mTLS_Required(t *testing.T) {
	certFile, keyFile := generateTestCert(t)
	caFile := certFile // self-signed cert is its own CA for testing

	cfg := Config{CertFile: certFile, KeyFile: keyFile, CAFile: caFile}
	p, err := NewProvider(cfg)
	require.NoError(t, err)

	tlsCfg := p.TLSConfig()
	assert.NotNil(t, tlsCfg.ClientCAs)
	assert.Equal(t, tls.RequireAndVerifyClientCert, tlsCfg.ClientAuth)
}

func TestProvider_mTLS_Optional(t *testing.T) {
	certFile, keyFile := generateTestCert(t)
	caFile := certFile

	cfg := Config{CertFile: certFile, KeyFile: keyFile, CAFile: caFile, MTLSMode: "optional"}
	p, err := NewProvider(cfg)
	require.NoError(t, err)

	tlsCfg := p.TLSConfig()
	assert.NotNil(t, tlsCfg.ClientCAs)
	assert.Equal(t, tls.VerifyClientCertIfGiven, tlsCfg.ClientAuth)
}

func TestProvider_TLSConfig_CachedInstance(t *testing.T) {
	certFile, keyFile := generateTestCert(t)
	cfg := Config{CertFile: certFile, KeyFile: keyFile}
	p, err := NewProvider(cfg)
	require.NoError(t, err)

	// TLSConfig() should return the same pointer every time
	cfg1 := p.TLSConfig()
	cfg2 := p.TLSConfig()
	assert.Same(t, cfg1, cfg2)
}

func TestTLSConfig_CipherSuites(t *testing.T) {
	certFile, keyFile := generateTestCert(t)
	cfg := Config{CertFile: certFile, KeyFile: keyFile}
	p, err := NewProvider(cfg)
	require.NoError(t, err)

	tlsCfg := p.TLSConfig()
	// Should only have GCM and ChaCha20 suites (no CBC)
	for _, suite := range tlsCfg.CipherSuites {
		info := tls.CipherSuiteName(suite)
		assert.NotContains(t, info, "CBC")
		assert.NotContains(t, info, "RC4")
		assert.NotContains(t, info, "3DES")
	}
}

func TestProvider_InvalidCAFile(t *testing.T) {
	certFile, keyFile := generateTestCert(t)
	cfg := Config{CertFile: certFile, KeyFile: keyFile, CAFile: "/nonexistent/ca.pem"}
	_, err := NewProvider(cfg)
	assert.Error(t, err)
}

// generateTestCert creates a self-signed ECDSA certificate for testing.
func generateTestCert(t *testing.T) (certFile, keyFile string) {
	t.Helper()
	dir := t.TempDir()
	certFile = filepath.Join(dir, "cert.pem")
	keyFile = filepath.Join(dir, "key.pem")

	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	require.NoError(t, err)

	template := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{Organization: []string{"Test"}},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(24 * time.Hour),
		KeyUsage:     x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment,
		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		IPAddresses:  []net.IP{net.ParseIP("127.0.0.1")},
		DNSNames:     []string{"localhost"},
	}

	certDER, err := x509.CreateCertificate(rand.Reader, template, template, &priv.PublicKey, priv)
	require.NoError(t, err)

	certPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: certDER})
	keyDER, err := x509.MarshalECPrivateKey(priv)
	require.NoError(t, err)
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: keyDER})

	require.NoError(t, os.WriteFile(certFile, certPEM, 0600))
	require.NoError(t, os.WriteFile(keyFile, keyPEM, 0600))
	return
}
