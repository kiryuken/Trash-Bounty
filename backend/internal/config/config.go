package config

import (
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/joho/godotenv"
)

const defaultBackendPort = "8080"

type Config struct {
	Port             string
	AllowedOrigins   []string
	DatabaseURL      string
	JWTSecret        string
	OpenAIAPIKey     string
	GPTMiniModel     string
	GPTStandardModel string
	GPTChatModel     string
	AgentsInternalURL string
	AgentsInternalSecret string
	UploadDir        string
	AppEnv           string
}

func Load() *Config {
	if os.Getenv("APP_ENV") != "production" {
		loadLocalEnvFiles()
	}

	dbURL := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		getEnv("DB_HOST", "localhost"),
		getEnv("DB_PORT", "5432"),
		getEnv("DB_USER", "trashbounty"),
		mustEnv("DB_PASSWORD"),
		getEnv("DB_NAME", "trashbounty_db"),
		getEnv("DB_SSLMODE", "disable"),
	)

	origins := getEnv("ALLOWED_ORIGINS", "http://localhost:3000")

	return &Config{
		// Keep the repo-tracked local default on 8080. Use PORT=8081 only
		// as an explicit machine-local tunnel override.
		Port:             getEnv("PORT", defaultBackendPort),
		AllowedOrigins:   strings.Split(origins, ","),
		DatabaseURL:      dbURL,
		JWTSecret:        mustEnv("JWT_SECRET"),
		OpenAIAPIKey:     mustEnv("OPENAI_API_KEY"),
		GPTMiniModel:     getEnv("GPT_MINI_MODEL", "gpt-5.4-mini"),
		GPTStandardModel: getEnv("GPT_STANDARD_MODEL", "gpt-4o"),
		GPTChatModel:     getEnv("GPT_CHAT_MODEL", "gpt-5.4-mini"),
		AgentsInternalURL: getEnv("AGENTS_INTERNAL_URL", ""),
		AgentsInternalSecret: getEnv("AGENTS_INTERNAL_SECRET", ""),
		UploadDir:        getEnv("UPLOAD_DIR", "./uploads"),
		AppEnv:           getEnv("APP_ENV", "development"),
	}
}

func loadLocalEnvFiles() {
	candidates := []string{".env.local", ".env"}
	loaded := false

	for _, path := range candidates {
		if _, err := os.Stat(path); err != nil {
			continue
		}
		if err := godotenv.Load(path); err != nil {
			log.Printf("WARN: could not load %s: %v", path, err)
			continue
		}
		loaded = true
	}

	if !loaded {
		log.Println("WARN: .env.local or .env file not found, using system env")
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("FATAL: env var %s wajib diisi", key)
	}
	return v
}
