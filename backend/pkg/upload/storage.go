package upload

import (
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
)

const (
	MaxUploadSize = 10 << 20 // 10 MB
	UploadDir     = "./uploads/reports"
)

var allowedMIMETypes = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
}

func SaveImage(file multipart.File, header *multipart.FileHeader) (string, string, error) {
	if header.Size > MaxUploadSize {
		return "", "", fmt.Errorf("file terlalu besar, maksimum 10MB")
	}

	buf := make([]byte, 512)
	if _, err := file.Read(buf); err != nil {
		return "", "", fmt.Errorf("baca file: %w", err)
	}
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		return "", "", err
	}

	mimeType := http.DetectContentType(buf)
	ext, allowed := allowedMIMETypes[mimeType]
	if !allowed {
		return "", "", fmt.Errorf("format file tidak didukung: %s", mimeType)
	}

	filename := fmt.Sprintf("%s-%d%s", uuid.New().String(), time.Now().Unix(), ext)

	if err := os.MkdirAll(UploadDir, 0755); err != nil {
		return "", "", err
	}

	dest := filepath.Join(UploadDir, filename)
	f, err := os.Create(dest)
	if err != nil {
		return "", "", fmt.Errorf("buat file: %w", err)
	}
	defer f.Close()

	if _, err := io.Copy(f, file); err != nil {
		return "", "", fmt.Errorf("salin file: %w", err)
	}

	publicURL := fmt.Sprintf("/uploads/reports/%s", filename)
	return dest, publicURL, nil
}
