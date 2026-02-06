package storage

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// Storage 存储接口
type Storage interface {
	Upload(ctx context.Context, key string, reader io.Reader, size int64, contentType string) error
	Download(ctx context.Context, key string) (io.ReadCloser, error)
	Delete(ctx context.Context, key string) error
	GetURL(ctx context.Context, key string) (string, error)
}

// MinioStorage MinIO存储实现
type MinioStorage struct {
	client *minio.Client
	bucket string
}

// NewMinioStorage 创建MinIO存储
func NewMinioStorage(endpoint, accessKey, secretKey, bucket string, useSSL bool) (*MinioStorage, error) {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, err
	}

	// 检查bucket是否存在，不存在则创建
	ctx := context.Background()
	exists, err := client.BucketExists(ctx, bucket)
	if err != nil {
		return nil, err
	}

	if !exists {
		err = client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{})
		if err != nil {
			return nil, err
		}
	}

	return &MinioStorage{
		client: client,
		bucket: bucket,
	}, nil
}

func (s *MinioStorage) Upload(ctx context.Context, key string, reader io.Reader, size int64, contentType string) error {
	_, err := s.client.PutObject(ctx, s.bucket, key, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	return err
}

func (s *MinioStorage) Download(ctx context.Context, key string) (io.ReadCloser, error) {
	return s.client.GetObject(ctx, s.bucket, key, minio.GetObjectOptions{})
}

func (s *MinioStorage) Delete(ctx context.Context, key string) error {
	return s.client.RemoveObject(ctx, s.bucket, key, minio.RemoveObjectOptions{})
}

func (s *MinioStorage) GetURL(ctx context.Context, key string) (string, error) {
	// 返回内部URL，实际访问通过media-proxy服务
	return fmt.Sprintf("/%s/%s", s.bucket, key), nil
}

// LocalStorage 本地文件存储实现
type LocalStorage struct {
	basePath string
}

// NewLocalStorage 创建本地存储
func NewLocalStorage(basePath string) (*LocalStorage, error) {
	if err := os.MkdirAll(basePath, 0755); err != nil {
		return nil, err
	}
	return &LocalStorage{basePath: basePath}, nil
}

func (s *LocalStorage) Upload(ctx context.Context, key string, reader io.Reader, size int64, contentType string) error {
	filePath := filepath.Join(s.basePath, key)

	// 确保目录存在
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	file, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = io.Copy(file, reader)
	return err
}

func (s *LocalStorage) Download(ctx context.Context, key string) (io.ReadCloser, error) {
	filePath := filepath.Join(s.basePath, key)
	return os.Open(filePath)
}

func (s *LocalStorage) Delete(ctx context.Context, key string) error {
	filePath := filepath.Join(s.basePath, key)
	return os.Remove(filePath)
}

func (s *LocalStorage) GetURL(ctx context.Context, key string) (string, error) {
	return "/media/" + key, nil
}
