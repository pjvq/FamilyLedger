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

// LevelFatal is a custom slog level above Error, used for unrecoverable
// failures that terminate the process. Tagging these distinctly lets log
// pipelines separate "an error was logged" from "the process died" (filter on
// level >= LevelFatal).
const LevelFatal = slog.Level(12)

// exitFunc is the process-exit hook used by Fatal/Fatalf.
//
// TEST ONLY override: it is a package-level var solely so tests can swap in a
// no-op to exercise the Fatal paths without terminating the test binary.
// Reassigning it is not goroutine-safe — production code must never do so, and
// Fatal/Fatalf are only ever called from the main goroutine during startup.
var exitFunc = os.Exit

// init configures a sensible structured default at package load, mirroring
// main's APP_ENV handling (empty env falls back to "development"). Because this
// package only depends on the standard library, its init runs before the init
// of any package that imports it — so logging from a dependent package's
// init() (e.g. pkg/ws) already goes through the structured handler with source
// attribution, rather than slog's bare built-in default. main still calls
// Setup() explicitly; it is idempotent and semantically identical to this.
func init() {
	appEnv := os.Getenv("APP_ENV")
	if appEnv == "" {
		appEnv = "development"
	}
	Setup(appEnv)
}

// Setup initializes the global structured logger.
// In production, uses JSON output; otherwise uses human-readable text.
// It also redirects the standard log package to slog at Warn level: any code
// still calling the bare log package is doing something unexpected, so it
// should stand out rather than hide among Info lines.
func Setup(appEnv string) {
	var handler slog.Handler
	opts := &slog.HandlerOptions{
		AddSource:   true,
		ReplaceAttr: replaceLevel,
	}
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

// replaceLevel renders the custom LevelFatal as "FATAL" instead of the default
// "ERROR+4" that slog prints for an unrecognized level.
func replaceLevel(groups []string, a slog.Attr) slog.Attr {
	if a.Key == slog.LevelKey {
		if lvl, ok := a.Value.Any().(slog.Level); ok && lvl == LevelFatal {
			a.Value = slog.StringValue("FATAL")
		}
	}
	return a
}

// callerSkipFrames is the number of stack frames between runtime.Callers and
// the original caller of an exported helper, along the path
// Callers → logfDepth → logf → Debugf/Infof/... → caller.
// If that call chain changes, update this constant or source lines will be wrong.
const callerSkipFrames = 4

// logf emits a formatted message at the given level with source attribution
// pointing at the original caller.
func logf(level slog.Level, format string, args ...any) {
	logfDepth(context.Background(), level, callerSkipFrames, format, args...)
}

// logfDepth is the shared implementation. skip is the number of stack frames
// between runtime.Callers and the original caller (see callerSkipFrames).
func logfDepth(ctx context.Context, level slog.Level, skip int, format string, args ...any) {
	l := slog.Default()
	if !l.Enabled(ctx, level) {
		return
	}
	var pcs [1]uintptr
	runtime.Callers(skip, pcs[:])
	r := slog.NewRecord(time.Now(), level, fmt.Sprintf(format, args...), pcs[0])
	if err := l.Handler().Handle(ctx, r); err != nil {
		// The logging sink itself failed (disk full, broken pipe). Don't lose
		// the failure silently — surface it on stderr as a last resort.
		fmt.Fprintf(os.Stderr, "logger: failed to write log record: %v\n", err)
	}
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

// Fatalf logs at the custom Fatal level and then exits the process with
// status 1. Use only for unrecoverable startup failures — never from a
// goroutine, where it would skip deferred cleanup and graceful shutdown.
func Fatalf(format string, args ...any) {
	logf(LevelFatal, format, args...)
	exitFunc(1)
}

// Fatal logs the message at the custom Fatal level and then exits with
// status 1. See Fatalf for usage constraints.
func Fatal(msg string) {
	logf(LevelFatal, "%s", msg)
	exitFunc(1)
}

// slogWriter bridges leftover standard-library log output to slog at Warn.
//
// Known, accepted limitation: records emitted through this bridge carry
// slogWriter.Write as their source location rather than the real caller,
// because the std log package doesn't expose the caller PC. This is fine
// because all first-party logging uses the leveled helpers above; the bridge
// only exists to catch stray third-party log.Print output, which is rare and
// for which a less-precise source is acceptable.
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
