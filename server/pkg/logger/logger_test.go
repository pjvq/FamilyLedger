package logger

import (
	"bytes"
	"log"
	"log/slog"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestSetup_Production(t *testing.T) {
	// Setup should not panic for production env
	assert.NotPanics(t, func() {
		Setup("production")
	})
}

func TestSetup_Development(t *testing.T) {
	assert.NotPanics(t, func() {
		Setup("development")
	})
}

func TestSetup_Prod(t *testing.T) {
	assert.NotPanics(t, func() {
		Setup("prod")
	})
}

func TestSlogWriter_Write(t *testing.T) {
	Setup("development")
	// Exercise the Write bridge by using standard log
	defaultLog := log.Default()
	assert.NotPanics(t, func() {
		defaultLog.Println("test log message via slog bridge")
	})
}

// withCapture redirects the default slog logger to an in-memory buffer at
// Debug level so tests can assert on emitted level and message.
func withCapture(t *testing.T) *bytes.Buffer {
	t.Helper()
	prev := slog.Default()
	t.Cleanup(func() { slog.SetDefault(prev) })
	buf := &bytes.Buffer{}
	slog.SetDefault(slog.New(slog.NewTextHandler(buf, &slog.HandlerOptions{
		AddSource: true,
		Level:     slog.LevelDebug,
	})))
	return buf
}

func TestLeveledHelpers_EmitCorrectLevels(t *testing.T) {
	cases := []struct {
		name  string
		fn    func(string, ...any)
		level string
	}{
		{"Debugf", Debugf, "DEBUG"},
		{"Infof", Infof, "INFO"},
		{"Warnf", Warnf, "WARN"},
		{"Errorf", Errorf, "ERROR"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			buf := withCapture(t)
			tc.fn("hello %s=%d", "n", 42)
			out := buf.String()
			assert.Contains(t, out, "level="+tc.level)
			assert.Contains(t, out, "hello n=42")
			// Source attribution should point at this test file, not logger.go.
			assert.Contains(t, out, "logger_test.go")
		})
	}
}

func TestLevelFiltering(t *testing.T) {
	prev := slog.Default()
	t.Cleanup(func() { slog.SetDefault(prev) })
	buf := &bytes.Buffer{}
	slog.SetDefault(slog.New(slog.NewTextHandler(buf, &slog.HandlerOptions{
		Level: slog.LevelWarn,
	})))
	Debugf("debug-should-be-dropped")
	Infof("info-should-be-dropped")
	Warnf("warn-should-appear")
	out := buf.String()
	assert.NotContains(t, out, "should-be-dropped")
	assert.Contains(t, out, "warn-should-appear")
	assert.Equal(t, 1, strings.Count(out, "\n"))
}
