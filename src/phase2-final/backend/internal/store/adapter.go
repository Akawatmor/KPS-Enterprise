package store

import (
	"context"
	"errors"
	"fmt"
	"log"

	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
)

var ErrNotFound = errors.New("record not found")

type Adapter interface {
	Kind() string
	Ping(ctx context.Context) error
	UpsertRaw(ctx context.Context, collection, id string, payload []byte) error
	GetRaw(ctx context.Context, collection, id string) ([]byte, bool, error)
	Delete(ctx context.Context, collection, id string) error
	ListRaw(ctx context.Context, collection string) ([][]byte, error)
	Close() error
}

func NewAdapter(cfg config.Config, logger *log.Logger) (Adapter, error) {
	switch cfg.DataBackend {
	case "sqlite":
		return NewSQLiteAdapter(cfg.SQLitePath)
	case "postgres":
		if cfg.PostgresDSN == "" {
			return nil, fmt.Errorf("POSTGRES_DSN is required when DATA_BACKEND=postgres")
		}
		return NewPostgresAdapter(cfg.PostgresDSN)
	case "memory":
		logger.Println("DATA_BACKEND=memory selected; data is not durable across restarts")
		return NewMemoryAdapter(), nil
	default:
		return nil, fmt.Errorf("unsupported DATA_BACKEND: %s", cfg.DataBackend)
	}
}
