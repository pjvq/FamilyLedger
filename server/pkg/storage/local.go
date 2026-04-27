package storage

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
)

// LocalFileStorage stores files on the local filesystem.
type LocalFileStorage struct {
	// BaseDir is the root directory for file storage (e.g., "./uploads/images").
	BaseDir string
	// BaseURL is the URL prefix for accessing stored files (e.g., "/uploads/images").
	BaseURL string
}

// NewLocalFileStorage creates a new local file storage instance.
func NewLocalFileStorage(baseDir, baseURL string) *LocalFileStorage {
	return &LocalFileStorage{
		BaseDir: baseDir,
		BaseURL: baseURL,
	}
}

func (s *LocalFileStorage) Upload(_ context.Context, key string, data []byte, _ string) (string, error) {
	fullPath := filepath.Join(s.BaseDir, key)

	// Ensure parent directory exists
	dir := filepath.Dir(fullPath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", fmt.Errorf("create directory %s: %w", dir, err)
	}

	if err := os.WriteFile(fullPath, data, 0o644); err != nil {
		return "", fmt.Errorf("write file %s: %w", fullPath, err)
	}

	url := fmt.Sprintf("%s/%s", s.BaseURL, key)
	return url, nil
}

func (s *LocalFileStorage) Delete(_ context.Context, key string) error {
	fullPath := filepath.Join(s.BaseDir, key)

	if err := os.Remove(fullPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("delete file %s: %w", fullPath, err)
	}
	return nil
}

func (s *LocalFileStorage) GetURL(_ context.Context, key string) (string, error) {
	fullPath := filepath.Join(s.BaseDir, key)

	if _, err := os.Stat(fullPath); err != nil {
		if os.IsNotExist(err) {
			return "", fmt.Errorf("file not found: %s", key)
		}
		return "", fmt.Errorf("stat file %s: %w", fullPath, err)
	}

	url := fmt.Sprintf("%s/%s", s.BaseURL, key)
	return url, nil
}
