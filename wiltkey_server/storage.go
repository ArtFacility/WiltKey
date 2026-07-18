package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// ObjectStorage defines interface for storing encrypted message envelopes.
type ObjectStorage interface {
	Upload(ctx context.Context, key string, reader io.Reader, size int64, contentType string) (string, error)
	Download(ctx context.Context, key string) (io.ReadCloser, error)
	Delete(ctx context.Context, key string) error
}

// S3StorageClient implements ObjectStorage for S3 / MinIO APIs.
type S3StorageClient struct {
	client     *minio.Client
	bucketName string
	endpoint   string
	useSSL     bool
}

// NewS3Storage creates a new S3-compatible client and ensures the bucket exists.
func NewS3Storage(endpoint, accessKey, secretKey, bucketName string, useSSL bool) (*S3StorageClient, error) {
	minioClient, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, err
	}

	ctx := context.Background()
	exists, err := minioClient.BucketExists(ctx, bucketName)
	if err != nil {
		return nil, err
	}
	if !exists {
		err = minioClient.MakeBucket(ctx, bucketName, minio.MakeBucketOptions{})
		if err != nil {
			return nil, err
		}
	}

	return &S3StorageClient{
		client:     minioClient,
		bucketName: bucketName,
		endpoint:   endpoint,
		useSSL:     useSSL,
	}, nil
}

// Upload stores a file in the S3 bucket and returns its virtual URL.
func (s *S3StorageClient) Upload(ctx context.Context, key string, reader io.Reader, size int64, contentType string) (string, error) {
	_, err := s.client.PutObject(ctx, s.bucketName, key, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", err
	}
	protocol := "http"
	if s.useSSL {
		protocol = "https"
	}
	return fmt.Sprintf("%s://%s/%s/%s", protocol, s.endpoint, s.bucketName, key), nil
}

// Download retrieves a reader for the file in S3.
func (s *S3StorageClient) Download(ctx context.Context, key string) (io.ReadCloser, error) {
	return s.client.GetObject(ctx, s.bucketName, key, minio.GetObjectOptions{})
}

// Delete removes a file from the S3 bucket.
func (s *S3StorageClient) Delete(ctx context.Context, key string) error {
	return s.client.RemoveObject(ctx, s.bucketName, key, minio.RemoveObjectOptions{})
}

// LocalStorageClient stores files locally on disk (fallback for local development/test).
type LocalStorageClient struct {
	dir string
}

// NewLocalStorage creates a LocalStorageClient.
func NewLocalStorage(dir string) (*LocalStorageClient, error) {
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, err
	}
	return &LocalStorageClient{dir: dir}, nil
}

// Upload writes a file to disk and returns a local URI path.
func (l *LocalStorageClient) Upload(ctx context.Context, key string, reader io.Reader, size int64, contentType string) (string, error) {
	path := filepath.Join(l.dir, key)
	file, err := os.Create(path)
	if err != nil {
		return "", err
	}
	defer file.Close()

	_, err = io.Copy(file, reader)
	if err != nil {
		return "", err
	}
	return "local://" + key, nil
}

// Download opens the local file for reading.
func (l *LocalStorageClient) Download(ctx context.Context, key string) (io.ReadCloser, error) {
	path := filepath.Join(l.dir, key)
	return os.Open(path)
}

// Delete removes the local file.
func (l *LocalStorageClient) Delete(ctx context.Context, key string) error {
	path := filepath.Join(l.dir, key)
	return os.Remove(path)
}
