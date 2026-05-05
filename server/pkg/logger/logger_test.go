package logger

import (
	"log"
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
