package config_test

import (
	"os"
	"testing"
	"time"

	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
)

func TestLoad_Defaults(t *testing.T) {
	// Unset all relevant env vars so we get the coded defaults.
	vars := []string{
		"SERVER_PORT", "DATA_BACKEND", "SQLITE_PATH", "POSTGRES_DSN",
		"NAGGER_TICK_SECONDS", "CALDAV_TICK_SECONDS",
		"AUTH_ACCESS_TOKEN_MINUTES", "AUTH_REFRESH_TOKEN_MINUTES",
		"ALLOWED_ORIGIN",
	}
	for _, v := range vars {
		os.Unsetenv(v)
	}

	cfg := config.Load()

	checks := []struct {
		name string
		got  any
		want any
	}{
		{"ServerPort", cfg.ServerPort, "8080"},
		{"DataBackend", cfg.DataBackend, "sqlite"},
		{"SQLitePath", cfg.SQLitePath, "/var/lib/todoapp/todoapp.db"},
		{"PostgresDSN", cfg.PostgresDSN, ""},
		{"NaggerTick", cfg.NaggerTick, 30 * time.Second},
		{"AuthAccessTokenTTL", cfg.AuthAccessTokenTTL, 15 * time.Minute},
		{"AuthRefreshTokenTTL", cfg.AuthRefreshTokenTTL, 60 * 24 * 7 * time.Minute},
		{"AllowedOrigin", cfg.AllowedOrigin, "*"},
	}

	for _, tc := range checks {
		if tc.got != tc.want {
			t.Errorf("Load() %s = %v, want %v", tc.name, tc.got, tc.want)
		}
	}
}

func TestLoad_EnvOverrides(t *testing.T) {
	t.Setenv("SERVER_PORT", "9090")
	t.Setenv("DATA_BACKEND", "postgres")
	t.Setenv("POSTGRES_DSN", "postgres://user:pass@localhost/db")
	t.Setenv("NAGGER_TICK_SECONDS", "10")
	t.Setenv("AUTH_ACCESS_TOKEN_MINUTES", "5")
	t.Setenv("AUTH_REFRESH_TOKEN_MINUTES", "60")
	t.Setenv("ALLOWED_ORIGIN", "http://localhost:3000")

	cfg := config.Load()

	if cfg.ServerPort != "9090" {
		t.Errorf("ServerPort = %q, want 9090", cfg.ServerPort)
	}
	if cfg.DataBackend != "postgres" {
		t.Errorf("DataBackend = %q, want postgres", cfg.DataBackend)
	}
	if cfg.PostgresDSN != "postgres://user:pass@localhost/db" {
		t.Errorf("PostgresDSN = %q", cfg.PostgresDSN)
	}
	if cfg.NaggerTick != 10*time.Second {
		t.Errorf("NaggerTick = %v, want 10s", cfg.NaggerTick)
	}
	if cfg.AuthAccessTokenTTL != 5*time.Minute {
		t.Errorf("AuthAccessTokenTTL = %v, want 5m", cfg.AuthAccessTokenTTL)
	}
	if cfg.AuthRefreshTokenTTL != 60*time.Minute {
		t.Errorf("AuthRefreshTokenTTL = %v, want 60m", cfg.AuthRefreshTokenTTL)
	}
	if cfg.AllowedOrigin != "http://localhost:3000" {
		t.Errorf("AllowedOrigin = %q, want http://localhost:3000", cfg.AllowedOrigin)
	}
}

func TestLoad_InvalidIntFallsBackToDefault(t *testing.T) {
	t.Setenv("NAGGER_TICK_SECONDS", "not-a-number")
	cfg := config.Load()
	if cfg.NaggerTick != 30*time.Second {
		t.Errorf("NaggerTick with invalid env = %v, want 30s (default)", cfg.NaggerTick)
	}
}
