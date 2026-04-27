// Package storage defines the FileStorage interface for file upload/download operations.
package storage

import "context"

// FileStorage abstracts file storage operations.
// Implementations may store files locally, in S3, or other backends.
type FileStorage interface {
	// Upload stores data under the given key and returns the publicly accessible URL.
	Upload(ctx context.Context, key string, data []byte, contentType string) (url string, err error)

	// Delete removes the file identified by key.
	Delete(ctx context.Context, key string) error

	// GetURL returns the publicly accessible URL for the given key.
	GetURL(ctx context.Context, key string) (string, error)
}
