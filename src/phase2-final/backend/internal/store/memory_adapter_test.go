package store_test

import (
	"context"
	"testing"

	"github.com/KPS-Enterprise/todoapp/backend/internal/store"
)

func TestMemoryAdapter_KindAndPing(t *testing.T) {
	m := store.NewMemoryAdapter()
	if m.Kind() != "memory" {
		t.Errorf("Kind() = %q, want %q", m.Kind(), "memory")
	}
	if err := m.Ping(context.Background()); err != nil {
		t.Errorf("Ping() unexpected error: %v", err)
	}
}

func TestMemoryAdapter_UpsertAndGet(t *testing.T) {
	m := store.NewMemoryAdapter()
	ctx := context.Background()

	payload := []byte(`{"id":"1","title":"buy milk"}`)
	if err := m.UpsertRaw(ctx, "tasks", "1", payload); err != nil {
		t.Fatalf("UpsertRaw error: %v", err)
	}

	got, found, err := m.GetRaw(ctx, "tasks", "1")
	if err != nil {
		t.Fatalf("GetRaw error: %v", err)
	}
	if !found {
		t.Fatal("GetRaw: expected found=true")
	}
	if string(got) != string(payload) {
		t.Errorf("GetRaw = %s, want %s", got, payload)
	}
}

func TestMemoryAdapter_GetMissing(t *testing.T) {
	m := store.NewMemoryAdapter()
	_, found, err := m.GetRaw(context.Background(), "tasks", "nonexistent")
	if err != nil {
		t.Fatalf("GetRaw error: %v", err)
	}
	if found {
		t.Error("expected found=false for missing key")
	}
}

func TestMemoryAdapter_UpsertOverwrites(t *testing.T) {
	m := store.NewMemoryAdapter()
	ctx := context.Background()

	_ = m.UpsertRaw(ctx, "tasks", "1", []byte(`{"v":1}`))
	_ = m.UpsertRaw(ctx, "tasks", "1", []byte(`{"v":2}`))

	got, _, _ := m.GetRaw(ctx, "tasks", "1")
	if string(got) != `{"v":2}` {
		t.Errorf("UpsertRaw overwrite: got %s, want {\"v\":2}", got)
	}
}

func TestMemoryAdapter_Delete(t *testing.T) {
	m := store.NewMemoryAdapter()
	ctx := context.Background()

	_ = m.UpsertRaw(ctx, "tasks", "1", []byte(`{}`))
	if err := m.Delete(ctx, "tasks", "1"); err != nil {
		t.Fatalf("Delete error: %v", err)
	}
	_, found, _ := m.GetRaw(ctx, "tasks", "1")
	if found {
		t.Error("expected item to be deleted")
	}
}

func TestMemoryAdapter_DeleteMissing(t *testing.T) {
	m := store.NewMemoryAdapter()
	// Deleting a non-existent key should not error
	if err := m.Delete(context.Background(), "tasks", "ghost"); err != nil {
		t.Errorf("Delete missing key: unexpected error: %v", err)
	}
}

func TestMemoryAdapter_ListRaw_Empty(t *testing.T) {
	m := store.NewMemoryAdapter()
	items, err := m.ListRaw(context.Background(), "tasks")
	if err != nil {
		t.Fatalf("ListRaw error: %v", err)
	}
	if len(items) != 0 {
		t.Errorf("ListRaw empty collection: got %d items, want 0", len(items))
	}
}

func TestMemoryAdapter_ListRaw_ReturnsSorted(t *testing.T) {
	m := store.NewMemoryAdapter()
	ctx := context.Background()

	_ = m.UpsertRaw(ctx, "tasks", "c", []byte(`{"id":"c"}`))
	_ = m.UpsertRaw(ctx, "tasks", "a", []byte(`{"id":"a"}`))
	_ = m.UpsertRaw(ctx, "tasks", "b", []byte(`{"id":"b"}`))

	items, err := m.ListRaw(ctx, "tasks")
	if err != nil {
		t.Fatalf("ListRaw error: %v", err)
	}
	if len(items) != 3 {
		t.Fatalf("ListRaw: got %d items, want 3", len(items))
	}
	// MemoryAdapter sorts by key lexicographically
	expected := []string{`{"id":"a"}`, `{"id":"b"}`, `{"id":"c"}`}
	for i, want := range expected {
		if string(items[i]) != want {
			t.Errorf("item[%d] = %s, want %s", i, items[i], want)
		}
	}
}

func TestMemoryAdapter_IsolatedPayload(t *testing.T) {
	// Mutations to the returned slice must not affect the stored data.
	m := store.NewMemoryAdapter()
	ctx := context.Background()

	original := []byte(`{"id":"1"}`)
	_ = m.UpsertRaw(ctx, "tasks", "1", original)

	got, _, _ := m.GetRaw(ctx, "tasks", "1")
	got[0] = 'X' // mutate the returned slice

	again, _, _ := m.GetRaw(ctx, "tasks", "1")
	if again[0] == 'X' {
		t.Error("GetRaw returned a reference to internal storage — mutation leaked")
	}
}

func TestMemoryAdapter_Close(t *testing.T) {
	m := store.NewMemoryAdapter()
	if err := m.Close(); err != nil {
		t.Errorf("Close() unexpected error: %v", err)
	}
}
