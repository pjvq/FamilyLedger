package storage

import (
	"context"
	"fmt"
)

// S3Storage stores files in AWS S3 or compatible object storage.
// This is a placeholder implementation; methods return Unimplemented errors.
type S3Storage struct {
	Bucket string
	Region string
	// client would be *s3.Client in a real implementation
}

// NewS3Storage creates a new S3 storage instance.
// In production, this would initialize an AWS S3 client.
func NewS3Storage(bucket, region string) *S3Storage {
	return &S3Storage{
		Bucket: bucket,
		Region: region,
	}
}

func (s *S3Storage) Upload(_ context.Context, _ string, _ []byte, _ string) (string, error) {
	return "", fmt.Errorf("s3 storage not implemented: bucket=%s region=%s", s.Bucket, s.Region)
}

func (s *S3Storage) Delete(_ context.Context, _ string) error {
	return fmt.Errorf("s3 storage not implemented: bucket=%s region=%s", s.Bucket, s.Region)
}

func (s *S3Storage) GetURL(_ context.Context, _ string) (string, error) {
	return "", fmt.Errorf("s3 storage not implemented: bucket=%s region=%s", s.Bucket, s.Region)
}
