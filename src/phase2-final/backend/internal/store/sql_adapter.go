package store

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

	_ "github.com/jackc/pgx/v5/stdlib"
	_ "modernc.org/sqlite"
)

type sqlDocAdapter struct {
	db          *sql.DB
	kind        string
	upsertQuery string
	getQuery    string
	listQuery   string
	deleteQuery string
}

func NewSQLiteAdapter(dbPath string) (Adapter, error) {
	if dbPath == "" {
		return nil, fmt.Errorf("sqlite path cannot be empty")
	}
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, fmt.Errorf("create sqlite directory: %w", err)
	}
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("open sqlite db: %w", err)
	}
	adapter := &sqlDocAdapter{
		db:   db,
		kind: "sqlite",
		upsertQuery: `INSERT INTO documents(collection, id, data, updated_at)
VALUES(?, ?, ?, CURRENT_TIMESTAMP)
ON CONFLICT(collection, id) DO UPDATE SET
data = excluded.data,
updated_at = CURRENT_TIMESTAMP`,
		getQuery:    "SELECT data FROM documents WHERE collection = ? AND id = ?",
		listQuery:   "SELECT data FROM documents WHERE collection = ? ORDER BY id",
		deleteQuery: "DELETE FROM documents WHERE collection = ? AND id = ?",
	}
	if err := adapter.ensureSchema(context.Background()); err != nil {
		_ = db.Close()
		return nil, err
	}
	return adapter, nil
}

func NewPostgresAdapter(dsn string) (Adapter, error) {
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, fmt.Errorf("open postgres db: %w", err)
	}
	adapter := &sqlDocAdapter{
		db:   db,
		kind: "postgres",
		upsertQuery: `INSERT INTO documents(collection, id, data, updated_at)
VALUES($1, $2, $3, NOW())
ON CONFLICT(collection, id) DO UPDATE SET
data = EXCLUDED.data,
updated_at = NOW()`,
		getQuery:    "SELECT data FROM documents WHERE collection = $1 AND id = $2",
		listQuery:   "SELECT data FROM documents WHERE collection = $1 ORDER BY id",
		deleteQuery: "DELETE FROM documents WHERE collection = $1 AND id = $2",
	}
	if err := adapter.ensureSchema(context.Background()); err != nil {
		_ = db.Close()
		return nil, err
	}
	return adapter, nil
}

func (s *sqlDocAdapter) ensureSchema(ctx context.Context) error {
	if err := s.Ping(ctx); err != nil {
		return err
	}
	schema := `CREATE TABLE IF NOT EXISTS documents (
collection TEXT NOT NULL,
id TEXT NOT NULL,
data TEXT NOT NULL,
updated_at TIMESTAMP NOT NULL,
PRIMARY KEY(collection, id)
)`
	if _, err := s.db.ExecContext(ctx, schema); err != nil {
		return fmt.Errorf("create documents table: %w", err)
	}
	return nil
}

func (s *sqlDocAdapter) Kind() string { return s.kind }

func (s *sqlDocAdapter) Ping(ctx context.Context) error {
	if err := s.db.PingContext(ctx); err != nil {
		return fmt.Errorf("ping %s db: %w", s.kind, err)
	}
	return nil
}

func (s *sqlDocAdapter) UpsertRaw(ctx context.Context, collection, id string, payload []byte) error {
	if _, err := s.db.ExecContext(ctx, s.upsertQuery, collection, id, string(payload)); err != nil {
		return fmt.Errorf("upsert %s/%s: %w", collection, id, err)
	}
	return nil
}

func (s *sqlDocAdapter) GetRaw(ctx context.Context, collection, id string) ([]byte, bool, error) {
	var payload string
	err := s.db.QueryRowContext(ctx, s.getQuery, collection, id).Scan(&payload)
	if err == sql.ErrNoRows {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("get %s/%s: %w", collection, id, err)
	}
	return []byte(payload), true, nil
}

func (s *sqlDocAdapter) Delete(ctx context.Context, collection, id string) error {
	if _, err := s.db.ExecContext(ctx, s.deleteQuery, collection, id); err != nil {
		return fmt.Errorf("delete %s/%s: %w", collection, id, err)
	}
	return nil
}

func (s *sqlDocAdapter) ListRaw(ctx context.Context, collection string) ([][]byte, error) {
	rows, err := s.db.QueryContext(ctx, s.listQuery, collection)
	if err != nil {
		return nil, fmt.Errorf("list %s: %w", collection, err)
	}
	defer rows.Close()
	items := make([][]byte, 0)
	for rows.Next() {
		var payload string
		if err := rows.Scan(&payload); err != nil {
			return nil, fmt.Errorf("scan list %s: %w", collection, err)
		}
		items = append(items, []byte(payload))
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate list %s: %w", collection, err)
	}
	return items, nil
}

func (s *sqlDocAdapter) Close() error { return s.db.Close() }
