package logger

import (
	"log"
	"log/slog"
	"os"
)

// Setup initializes the global structured logger.
// In production, uses JSON output; otherwise uses text.
// Also redirects the standard log package to use slog.
func Setup(appEnv string) {
	var handler slog.Handler
	switch appEnv {
	case "production", "prod":
		handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
			Level: slog.LevelInfo,
		})
	default:
		handler = slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
			Level: slog.LevelDebug,
		})
	}
	logger := slog.New(handler)
	slog.SetDefault(logger)

	// Bridge: redirect standard log to slog
	log.SetFlags(0)
	log.SetOutput(&slogWriter{logger: logger})
}

// slogWriter bridges standard log output to slog.
type slogWriter struct {
	logger *slog.Logger
}

func (w *slogWriter) Write(p []byte) (n int, err error) {
	// Strip trailing newline
	msg := string(p)
	if len(msg) > 0 && msg[len(msg)-1] == '\n' {
		msg = msg[:len(msg)-1]
	}
	w.logger.Info(msg)
	return len(p), nil
}
