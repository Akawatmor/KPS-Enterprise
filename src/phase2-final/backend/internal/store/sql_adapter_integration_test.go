//go:build integration
// +build integration

package store

import (
	"context"
	"encoding/json"
	"os"
	"testing"
	"time"
)

// ── Helper: setup adapter เชื่อมต่อ DB จริง ───────────────────────────────
func setupPostgres(t *testing.T) Adapter {
	t.Helper()

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set, skipping integration test")
	}

	// Wait for DB ready (max 30s)
	deadline := time.Now().Add(30 * time.Second)
	var (
		adapter Adapter
		err     error
	)
	for time.Now().Before(deadline) {
		adapter, err = NewPostgresAdapter(dsn)
		if err == nil {
			if pingErr := adapter.Ping(context.Background()); pingErr == nil {
				break
			}
			adapter.Close()
		}
		time.Sleep(time.Second)
	}
	if err != nil {
		t.Fatalf("connect postgres: %v", err)
	}

	t.Cleanup(func() {
		// Clean test data หลัง test เสร็จ
		ctx := context.Background()
		_ = adapter.Delete(ctx, "test_tasks", "task-1")
		_ = adapter.Delete(ctx, "test_tasks", "task-2")
		_ = adapter.Delete(ctx, "test_tasks", "task-3")
		_ = adapter.Close()
	})

	return adapter
}

// ── Test 1: Adapter kind + ping ───────────────────────────────────────────
func TestPostgresAdapter_Integration_KindAndPing(t *testing.T) {
	adapter := setupPostgres(t)

	if kind := adapter.Kind(); kind != "postgres" {
		t.Errorf("expected kind=postgres, got %q", kind)
	}

	if err := adapter.Ping(context.Background()); err != nil {
		t.Fatalf("ping failed: %v", err)
	}
}

// ── Test 2: Upsert + Get round-trip ───────────────────────────────────────
func TestPostgresAdapter_Integration_UpsertGet(t *testing.T) {
	adapter := setupPostgres(t)
	ctx := context.Background()

	payload, _ := json.Marshal(map[string]any{
		"title":  "buy milk",
		"column": "todo",
	})

	// Insert
	if err := adapter.UpsertRaw(ctx, "test_tasks", "task-1", payload); err != nil {
		t.Fatalf("UpsertRaw: %v", err)
	}

	// Read back
	got, found, err := adapter.GetRaw(ctx, "test_tasks", "task-1")
	if err != nil {
		t.Fatalf("GetRaw: %v", err)
	}
	if !found {
		t.Fatal("expected found=true")
	}

	var decoded map[string]any
	if err := json.Unmarshal(got, &decoded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if decoded["title"] != "buy milk" {
		t.Errorf("title mismatch: got %v", decoded["title"])
	}
}

// ── Test 3: Upsert overwrites existing ────────────────────────────────────
func TestPostgresAdapter_Integration_UpsertOverwrite(t *testing.T) {
	adapter := setupPostgres(t)
	ctx := context.Background()

	v1, _ := json.Marshal(map[string]string{"title": "v1"})
	v2, _ := json.Marshal(map[string]string{"title": "v2"})

	if err := adapter.UpsertRaw(ctx, "test_tasks", "task-1", v1); err != nil {
		t.Fatalf("upsert v1: %v", err)
	}
	if err := adapter.UpsertRaw(ctx, "test_tasks", "task-1", v2); err != nil {
		t.Fatalf("upsert v2: %v", err)
	}

	got, _, err := adapter.GetRaw(ctx, "test_tasks", "task-1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}

	var decoded map[string]string
	_ = json.Unmarshal(got, &decoded)
	if decoded["title"] != "v2" {
		t.Errorf("expected v2 after overwrite, got %v", decoded["title"])
	}
}

// ── Test 4: Get missing key returns found=false ───────────────────────────
func TestPostgresAdapter_Integration_GetMissing(t *testing.T) {
	adapter := setupPostgres(t)
	ctx := context.Background()

	_, found, err := adapter.GetRaw(ctx, "test_tasks", "nonexistent-id")
	if err != nil {
		t.Fatalf("expected no error for missing key, got: %v", err)
	}
	if found {
		t.Error("expected found=false for missing key")
	}
}

// ── Test 5: List returns all items in collection ──────────────────────────
func TestPostgresAdapter_Integration_List(t *testing.T) {
	adapter := setupPostgres(t)
	ctx := context.Background()

	for i, id := range []string{"task-1", "task-2", "task-3"} {
		payload, _ := json.Marshal(map[string]int{"index": i})
		if err := adapter.UpsertRaw(ctx, "test_tasks", id, payload); err != nil {
			t.Fatalf("upsert %s: %v", id, err)
		}
	}

	items, err := adapter.ListRaw(ctx, "test_tasks")
	if err != nil {
		t.Fatalf("ListRaw: %v", err)
	}
	if len(items) < 3 {
		t.Errorf("expected at least 3 items, got %d", len(items))
	}
}

// ── Test 6: Delete removes item ───────────────────────────────────────────
func TestPostgresAdapter_Integration_Delete(t *testing.T) {
	adapter := setupPostgres(t)
	ctx := context.Background()

	payload, _ := json.Marshal(map[string]string{"title": "to-delete"})
	if err := adapter.UpsertRaw(ctx, "test_tasks", "task-1", payload); err != nil {
		t.Fatalf("upsert: %v", err)
	}

	if err := adapter.Delete(ctx, "test_tasks", "task-1"); err != nil {
		t.Fatalf("delete: %v", err)
	}

	_, found, err := adapter.GetRaw(ctx, "test_tasks", "task-1")
	if err != nil {
		t.Fatalf("get after delete: %v", err)
	}
	if found {
		t.Error("expected found=false after delete")
	}
}

// ── Test 7: Collection isolation ──────────────────────────────────────────
func TestPostgresAdapter_Integration_CollectionIsolation(t *testing.T) {
	adapter := setupPostgres(t)
	ctx := context.Background()

	defer adapter.Delete(ctx, "test_other", "task-1")

	payloadA, _ := json.Marshal(map[string]string{"col": "A"})
	payloadB, _ := json.Marshal(map[string]string{"col": "B"})

	_ = adapter.UpsertRaw(ctx, "test_tasks", "task-1", payloadA)
	_ = adapter.UpsertRaw(ctx, "test_other", "task-1", payloadB)

	gotA, _, _ := adapter.GetRaw(ctx, "test_tasks", "task-1")
	gotB, _, _ := adapter.GetRaw(ctx, "test_other", "task-1")

	var decA, decB map[string]string
	_ = json.Unmarshal(gotA, &decA)
	_ = json.Unmarshal(gotB, &decB)

	if decA["col"] != "A" || decB["col"] != "B" {
		t.Errorf("collection isolation broken: A=%v B=%v", decA, decB)
	}
}

// ── Test 8: Concurrent upserts (race-safe) ────────────────────────────────
func TestPostgresAdapter_Integration_ConcurrentUpserts(t *testing.T) {
	adapter := setupPostgres(t)
	ctx := context.Background()

	const N = 20
	done := make(chan error, N)

	for i := 0; i < N; i++ {
		go func(idx int) {
			payload, _ := json.Marshal(map[string]int{"i": idx})
			done <- adapter.UpsertRaw(ctx, "test_tasks", "task-1", payload)
		}(i)
	}

	for i := 0; i < N; i++ {
		if err := <-done; err != nil {
			t.Errorf("concurrent upsert: %v", err)
		}
	}

	// ตรวจว่ามี value ใดๆ อยู่ (ไม่ snap หาย)
	_, found, err := adapter.GetRaw(ctx, "test_tasks", "task-1")
	if err != nil || !found {
		t.Errorf("expected key to exist after concurrent upserts (found=%v, err=%v)", found, err)
	}
}