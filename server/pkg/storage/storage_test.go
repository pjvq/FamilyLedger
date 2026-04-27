package storage

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLocalFileStorage_Upload(t *testing.T) {
	dir := t.TempDir()
	s := NewLocalFileStorage(dir, "/uploads")

	url, err := s.Upload(context.Background(), "user1/test.jpg", []byte("fake image data"), "image/jpeg")
	require.NoError(t, err)
	assert.Equal(t, "/uploads/user1/test.jpg", url)

	// Verify file was written
	content, err := os.ReadFile(filepath.Join(dir, "user1", "test.jpg"))
	require.NoError(t, err)
	assert.Equal(t, []byte("fake image data"), content)
}

func TestLocalFileStorage_Upload_CreatesDir(t *testing.T) {
	dir := t.TempDir()
	s := NewLocalFileStorage(dir, "/uploads")

	_, err := s.Upload(context.Background(), "nested/deep/file.png", []byte("data"), "image/png")
	require.NoError(t, err)

	// Verify nested directory was created
	_, err = os.Stat(filepath.Join(dir, "nested", "deep", "file.png"))
	require.NoError(t, err)
}

func TestLocalFileStorage_Delete(t *testing.T) {
	dir := t.TempDir()
	s := NewLocalFileStorage(dir, "/uploads")

	// First upload
	_, err := s.Upload(context.Background(), "user1/delete_me.jpg", []byte("data"), "image/jpeg")
	require.NoError(t, err)

	// Then delete
	err = s.Delete(context.Background(), "user1/delete_me.jpg")
	require.NoError(t, err)

	// Verify file is gone
	_, err = os.Stat(filepath.Join(dir, "user1", "delete_me.jpg"))
	assert.True(t, os.IsNotExist(err))
}

func TestLocalFileStorage_Delete_NonExistent(t *testing.T) {
	dir := t.TempDir()
	s := NewLocalFileStorage(dir, "/uploads")

	// Deleting non-existent file should not error
	err := s.Delete(context.Background(), "nonexistent.jpg")
	assert.NoError(t, err)
}

func TestLocalFileStorage_GetURL(t *testing.T) {
	dir := t.TempDir()
	s := NewLocalFileStorage(dir, "/uploads")

	// Upload first
	_, err := s.Upload(context.Background(), "user1/photo.png", []byte("img"), "image/png")
	require.NoError(t, err)

	// GetURL
	url, err := s.GetURL(context.Background(), "user1/photo.png")
	require.NoError(t, err)
	assert.Equal(t, "/uploads/user1/photo.png", url)
}

func TestLocalFileStorage_GetURL_NotFound(t *testing.T) {
	dir := t.TempDir()
	s := NewLocalFileStorage(dir, "/uploads")

	_, err := s.GetURL(context.Background(), "nonexistent.jpg")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "file not found")
}

func TestS3Storage_Upload_Unimplemented(t *testing.T) {
	s := NewS3Storage("my-bucket", "us-east-1")
	_, err := s.Upload(context.Background(), "key", []byte("data"), "image/jpeg")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not implemented")
}

func TestS3Storage_Delete_Unimplemented(t *testing.T) {
	s := NewS3Storage("my-bucket", "us-east-1")
	err := s.Delete(context.Background(), "key")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not implemented")
}

func TestS3Storage_GetURL_Unimplemented(t *testing.T) {
	s := NewS3Storage("my-bucket", "us-east-1")
	_, err := s.GetURL(context.Background(), "key")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not implemented")
}
