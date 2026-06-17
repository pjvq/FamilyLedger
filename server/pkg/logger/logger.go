// Package logger provides a thin, level-aware wrapper around the standard
// library's structured logger (log/slog).
//
// Historically the codebase logged everything through the standard log
// package (log.Printf / log.Println), which the Setup bridge funneled into
// slog at a single Info level — so warnings and errors were indistinguishable
// from routine info. This package exposes printf-style helpers that carry an
// explicit level (Debugf/Infof/Warnf/Errorf) so log output can be filtered and
// triaged properly, while keeping the familiar printf call sites.
package logger

import (
	"context"
	"fmt"
	"log"
	"log/slog"
	"os"
	"runtime"
	"time"
)

// Setup initializes the global structured logger.
// In production, uses JSON output; otherwise uses human-readable text.
// It also redirects the standard log package to slog at Warn level: any code
// still calling the bare log package is doing something unexpected, so it
// should stand out rather than hide among Info lines.
func Setup(appEnv string) {
	var handler slog.Handler
	opts := &slog.HandlerOptions{AddSource: true}
	switch appEnv {
	case "production", "prod":
		opts.Level = slog.LevelInfo
		handler = slog.NewJSONHandler(os.Stdout, opts)
	default:
		opts.Level = slog.LevelDebug
		handler = slog.NewTextHandler(os.Stdout, opts)
	}
	l := slog.New(handler)
	slog.SetDefault(l)

	// Bridge: redirect any remaining standard log output to slog at Warn.
	log.SetFlags(0)
	log.SetOutput(&slogWriter{logger: l})
}

// logf emits a formatted message at the given level with source attribution
// pointing at the original caller (skipping this helper and the exported
// wrapper above it).
func logf(level slog.Level, format string, args ...any) {
	l := slog.Default()
	if !l.Enabled(context.Background(), level) {
		return
	}
	// Skip: runtime.Callers, logf, the exported wrapper (Infof/...). => skip 3.
	var pcs [1]uintptr
	runtime.Callers(3, pcs[:])
	r := slog.NewRecord(time.Now(), level, fmt.Sprintf(format, args...), pcs[0])
	_ = l.Handler().Handle(context.Background(), r)
}

// Debugf logs at Debug level: chatty, per-request tracing useful only when
// diagnosing a problem (e.g. "returning N rows").
func Debugf(format string, args ...any) { logf(slog.LevelDebug, format, args...) }

// Infof logs at Info level: meaningful lifecycle and state changes
// (server started, entity created/deleted, scheduler ticked).
func Infof(format string, args ...any) { logf(slog.LevelInfo, format, args...) }

// Warnf logs at Warn level: recoverable or expected-but-notable conditions
// (fallbacks, skipped/idempotent operations, permission denials, legacy data).
func Warnf(format string, args ...any) { logf(slog.LevelWarn, format, args...) }

// Errorf logs at Error level: unexpected failures, including ones that may
// lose data or abort an operation.
func Errorf(format string, args ...any) { logf(slog.LevelError, format, args...) }

// Fatalf logs at Error level and then exits the process with status 1.
// Use only for unrecoverable startup failures.
func Fatalf(format string, args ...any) {
	logf(slog.LevelError, format, args...)
	os.Exit(1)
}

// Fatal logs the message at Error level and then exits with status 1.
func Fatal(msg string) {
	logf(slog.LevelError, "%s", msg)
	os.Exit(1)
}

// slogWriter bridges leftover standard-library log output to slog at Warn.
type slogWriter struct {
	logger *slog.Logger
}

func (w *slogWriter) Write(p []byte) (n int, err error) {
	msg := string(p)
	if len(msg) > 0 && msg[len(msg)-1] == '\n' {
		msg = msg[:len(msg)-1]
	}
	w.logger.Warn(msg)
	return len(p), nil
}
