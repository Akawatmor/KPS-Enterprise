package config

import (
	"os"
	"strconv"
	"time"
)

// Config contains runtime settings for the todoapp core service.
type Config struct {
	ServerPort          string
	DataBackend         string
	SQLitePath          string
	PostgresDSN         string
	NaggerTick          time.Duration
	CalDAVTick          time.Duration
	AuthAccessTokenTTL  time.Duration
	AuthRefreshTokenTTL time.Duration
	AllowedOrigin       string
}

// Load reads configuration from environment variables with sane defaults.
func Load() Config {
	return Config{
		ServerPort:          getEnv("SERVER_PORT", "8080"),
		DataBackend:         getEnv("DATA_BACKEND", "sqlite"),
		SQLitePath:          getEnv("SQLITE_PATH", "/var/lib/todoapp/todoapp.db"),
		PostgresDSN:         getEnv("POSTGRES_DSN", ""),
		NaggerTick:          time.Duration(getEnvInt("NAGGER_TICK_SECONDS", 30)) * time.Second,
		CalDAVTick:          time.Duration(getEnvInt("CALDAV_TICK_SECONDS", 60)) * time.Second,
		AuthAccessTokenTTL:  time.Duration(getEnvInt("AUTH_ACCESS_TOKEN_MINUTES", 15)) * time.Minute,
		AuthRefreshTokenTTL: time.Duration(getEnvInt("AUTH_REFRESH_TOKEN_MINUTES", 60*24*7)) * time.Minute,
		AllowedOrigin:       getEnv("ALLOWED_ORIGIN", "*"),
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok && value != "" {
		return value
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if value, ok := os.LookupEnv(key); ok {
		parsed, err := strconv.Atoi(value)
		if err == nil {
			return parsed
		}
	}
	return fallback
}
