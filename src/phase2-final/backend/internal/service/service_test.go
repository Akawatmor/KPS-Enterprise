package service_test

import (
	"context"
	"log"
	"os"
	"testing"
	"time"

	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
	"github.com/KPS-Enterprise/todoapp/backend/internal/model"
	"github.com/KPS-Enterprise/todoapp/backend/internal/service"
	"github.com/KPS-Enterprise/todoapp/backend/internal/store"
)

// newTestService returns a Service wired to an in-memory store with a fixed clock.
func newTestService(t *testing.T) (*service.Service, time.Time) {
	t.Helper()
	fixed := time.Date(2026, 4, 26, 12, 0, 0, 0, time.UTC)
	cfg := config.Config{
		AuthAccessTokenTTL:  15 * time.Minute,
		AuthRefreshTokenTTL: 7 * 24 * time.Hour,
	}
	logger := log.New(os.Stderr, "[test] ", 0)
	mem := store.NewMemoryAdapter()
	svc := service.NewWithClock(cfg, logger, mem, func() time.Time { return fixed })
	return svc, fixed
}

// ── Task CRUD ─────────────────────────────────────────────────────────────────

func TestCreateTask_Defaults(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	task, err := svc.CreateTask(ctx, model.Task{
		UserID: "usr_1",
		Title:  "Buy milk",
	})
	if err != nil {
		t.Fatalf("CreateTask error: %v", err)
	}
	if task.ID == "" {
		t.Error("CreateTask: expected non-empty ID")
	}
	if task.Status != model.TaskStatusOpen {
		t.Errorf("CreateTask: Status = %q, want %q", task.Status, model.TaskStatusOpen)
	}
	if task.Priority != "normal" {
		t.Errorf("CreateTask: Priority = %q, want normal", task.Priority)
	}
	if task.Column != "todo" {
		t.Errorf("CreateTask: Column = %q, want todo", task.Column)
	}
}

func TestCreateTask_HighPriority(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	task, err := svc.CreateTask(ctx, model.Task{
		UserID:   "usr_1",
		Title:    "Urgent task",
		Priority: "high",
	})
	if err != nil {
		t.Fatalf("CreateTask error: %v", err)
	}
	if task.Priority != "high" {
		t.Errorf("Priority = %q, want high", task.Priority)
	}
}

func TestListTasks_FilterByUser(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	_, _ = svc.CreateTask(ctx, model.Task{UserID: "alice", Title: "Alice task"})
	_, _ = svc.CreateTask(ctx, model.Task{UserID: "bob", Title: "Bob task"})

	items, err := svc.ListTasks(ctx, service.TaskListFilter{UserID: "alice"})
	if err != nil {
		t.Fatalf("ListTasks error: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("ListTasks: got %d items, want 1", len(items))
	}
	if items[0].Task.UserID != "alice" {
		t.Errorf("ListTasks: returned task UserID = %q, want alice", items[0].Task.UserID)
	}
}

func TestListTasks_FilterByStatus(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	t1, _ := svc.CreateTask(ctx, model.Task{UserID: "usr_1", Title: "Open task"})
	_, _ = svc.CreateTask(ctx, model.Task{UserID: "usr_1", Title: "Another open"})

	// Mark first task done
	_, _ = svc.UpdateTask(ctx, t1.ID, "usr_1", map[string]any{"status": "done"})

	open, err := svc.ListTasks(ctx, service.TaskListFilter{UserID: "usr_1", Status: "open"})
	if err != nil {
		t.Fatalf("ListTasks error: %v", err)
	}
	if len(open) != 1 {
		t.Errorf("open tasks: got %d, want 1", len(open))
	}

	done, err := svc.ListTasks(ctx, service.TaskListFilter{UserID: "usr_1", Status: "done"})
	if err != nil {
		t.Fatalf("ListTasks error: %v", err)
	}
	if len(done) != 1 {
		t.Errorf("done tasks: got %d, want 1", len(done))
	}
}

func TestUpdateTask_Title(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	task, _ := svc.CreateTask(ctx, model.Task{UserID: "usr_1", Title: "Old title"})
	updated, err := svc.UpdateTask(ctx, task.ID, "usr_1", map[string]any{"title": "New title"})
	if err != nil {
		t.Fatalf("UpdateTask error: %v", err)
	}
	if updated.Title != "New title" {
		t.Errorf("UpdateTask Title = %q, want %q", updated.Title, "New title")
	}
}

func TestUpdateTask_Forbidden(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	task, _ := svc.CreateTask(ctx, model.Task{UserID: "alice", Title: "Alice's task"})
	_, err := svc.UpdateTask(ctx, task.ID, "bob", map[string]any{"title": "hacked"})
	if err == nil {
		t.Error("UpdateTask: expected forbidden error for wrong user")
	}
}

func TestUpdateTask_NotFound(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	_, err := svc.UpdateTask(ctx, "nonexistent", "usr_1", map[string]any{"title": "x"})
	if err == nil {
		t.Error("UpdateTask: expected error for nonexistent task")
	}
}

func TestDeleteTask(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	task, _ := svc.CreateTask(ctx, model.Task{UserID: "usr_1", Title: "To delete"})
	if err := svc.DeleteTask(ctx, task.ID, "usr_1"); err != nil {
		t.Fatalf("DeleteTask error: %v", err)
	}

	items, _ := svc.ListTasks(ctx, service.TaskListFilter{UserID: "usr_1"})
	if len(items) != 0 {
		t.Errorf("expected 0 tasks after delete, got %d", len(items))
	}
}

func TestDeleteTask_Forbidden(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	task, _ := svc.CreateTask(ctx, model.Task{UserID: "alice", Title: "Private"})
	if err := svc.DeleteTask(ctx, task.ID, "bob"); err == nil {
		t.Error("DeleteTask: expected forbidden error for wrong user")
	}
}

// ── Auth ──────────────────────────────────────────────────────────────────────

func TestExchangeOAuthCode_CreatesUser(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	bundle, err := svc.ExchangeOAuthCode(ctx, "github", "test-code-abc")
	if err != nil {
		t.Fatalf("ExchangeOAuthCode error: %v", err)
	}
	if bundle.User.ID == "" {
		t.Error("expected non-empty User.ID")
	}
	if bundle.Session.AccessToken == "" {
		t.Error("expected non-empty Session.AccessToken")
	}
	if bundle.Session.RefreshToken == "" {
		t.Error("expected non-empty Session.RefreshToken")
	}
}

func TestExchangeOAuthCode_SecondLoginReusesUser(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	b1, _ := svc.ExchangeOAuthCode(ctx, "github", "code-xyz")
	b2, _ := svc.ExchangeOAuthCode(ctx, "github", "code-xyz")

	if b1.User.ID != b2.User.ID {
		t.Errorf("second login created a new user: %q != %q", b1.User.ID, b2.User.ID)
	}
}

func TestExchangeOAuthCode_InvalidProvider(t *testing.T) {
	svc, _ := newTestService(t)
	_, err := svc.ExchangeOAuthCode(context.Background(), "gitlab", "any-code")
	if err == nil {
		t.Error("expected error for unsupported provider")
	}
}

func TestAuthenticateAccessToken_Valid(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	bundle, _ := svc.ExchangeOAuthCode(ctx, "github", "code-1")
	session, err := svc.AuthenticateAccessToken(ctx, bundle.Session.AccessToken)
	if err != nil {
		t.Fatalf("AuthenticateAccessToken error: %v", err)
	}
	if session.UserID != bundle.User.ID {
		t.Errorf("UserID mismatch: got %q, want %q", session.UserID, bundle.User.ID)
	}
}

func TestAuthenticateAccessToken_Empty(t *testing.T) {
	svc, _ := newTestService(t)
	_, err := svc.AuthenticateAccessToken(context.Background(), "")
	if err == nil {
		t.Error("expected error for empty token")
	}
}

func TestAuthenticateAccessToken_Unknown(t *testing.T) {
	svc, _ := newTestService(t)
	_, err := svc.AuthenticateAccessToken(context.Background(), "atk_bogus")
	if err == nil {
		t.Error("expected error for unknown token")
	}
}

func TestLogoutAndReject(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()

	bundle, _ := svc.ExchangeOAuthCode(ctx, "github", "code-2")
	token := bundle.Session.AccessToken

	if err := svc.LogoutAccessToken(ctx, token); err != nil {
		t.Fatalf("LogoutAccessToken error: %v", err)
	}
	if _, err := svc.AuthenticateAccessToken(ctx, token); err == nil {
		t.Error("expected error after logout")
	}
}

// ── Misc ──────────────────────────────────────────────────────────────────────

func TestAdapterKind(t *testing.T) {
	svc, _ := newTestService(t)
	if svc.AdapterKind() != "memory" {
		t.Errorf("AdapterKind = %q, want memory", svc.AdapterKind())
	}
}

func TestPing(t *testing.T) {
	svc, _ := newTestService(t)
	if err := svc.Ping(context.Background()); err != nil {
		t.Errorf("Ping error: %v", err)
	}
}
