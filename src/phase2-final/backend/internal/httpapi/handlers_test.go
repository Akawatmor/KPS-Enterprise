package httpapi_test

import (
	"encoding/json"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
	"github.com/KPS-Enterprise/todoapp/backend/internal/httpapi"
	"github.com/KPS-Enterprise/todoapp/backend/internal/service"
	"github.com/KPS-Enterprise/todoapp/backend/internal/store"
)

// newTestMux returns a fully wired HTTP mux using the in-memory adapter.
func newTestMux(t *testing.T) http.Handler {
	t.Helper()
	cfg := config.Config{
		DataBackend:         "memory",
		AllowedOrigin:       "*",
		AuthAccessTokenTTL:  15 * 60 * 1e9, // 15 min in nanoseconds
		AuthRefreshTokenTTL: 7 * 24 * 60 * 60 * 1e9,
	}
	logger := log.New(os.Stderr, "[test-http] ", 0)
	mem := store.NewMemoryAdapter()
	svc := service.New(cfg, logger, mem)
	return httpapi.NewMux(cfg, logger, svc)
}

// ── /healthz ─────────────────────────────────────────────────────────────────

func TestHealthz_OK(t *testing.T) {
	mux := newTestMux(t)
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("GET /healthz status = %d, want 200", w.Code)
	}

	var body map[string]any
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("body.status = %v, want ok", body["status"])
	}
	if body["service"] != "todoapp-core" {
		t.Errorf("body.service = %v, want todoapp-core", body["service"])
	}
}

func TestHealthz_MethodNotAllowed(t *testing.T) {
	mux := newTestMux(t)
	req := httptest.NewRequest(http.MethodPost, "/healthz", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusMethodNotAllowed {
		t.Errorf("POST /healthz status = %d, want 405", w.Code)
	}
}

// ── /readyz ───────────────────────────────────────────────────────────────────

func TestReadyz_OK(t *testing.T) {
	mux := newTestMux(t)
	req := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("GET /readyz status = %d, want 200", w.Code)
	}

	var body map[string]any
	json.NewDecoder(w.Body).Decode(&body)
	if body["status"] != "ready" {
		t.Errorf("body.status = %v, want ready", body["status"])
	}
}

// ── /api/v1/meta ──────────────────────────────────────────────────────────────

func TestMeta_OK(t *testing.T) {
	mux := newTestMux(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/meta", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("GET /api/v1/meta status = %d, want 200", w.Code)
	}

	var body map[string]any
	json.NewDecoder(w.Body).Decode(&body)
	if body["name"] != "TodoApp" {
		t.Errorf("meta.name = %v, want TodoApp", body["name"])
	}
	if body["backend"] != "Go" {
		t.Errorf("meta.backend = %v, want Go", body["backend"])
	}
}

// ── CORS ─────────────────────────────────────────────────────────────────────

func TestCORS_Options(t *testing.T) {
	mux := newTestMux(t)
	req := httptest.NewRequest(http.MethodOptions, "/api/v1/tasks", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("OPTIONS /api/v1/tasks status = %d, want 204", w.Code)
	}
	if h := w.Header().Get("Access-Control-Allow-Origin"); h == "" {
		t.Error("missing Access-Control-Allow-Origin header")
	}
}

// ── Auth ──────────────────────────────────────────────────────────────────────

func TestListAuthProviders(t *testing.T) {
	mux := newTestMux(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/providers", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("GET /api/v1/auth/providers status = %d, want 200", w.Code)
	}
	var body map[string]any
	json.NewDecoder(w.Body).Decode(&body)
	providers, ok := body["providers"].([]any)
	if !ok || len(providers) == 0 {
		t.Errorf("expected non-empty providers list, got %v", body["providers"])
	}
}

func TestExchangeGitHubCode_OK(t *testing.T) {
	mux := newTestMux(t)
	body := `{"code":"test-code-123"}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/github/exchange",
		strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("POST /api/v1/auth/github/exchange status = %d, want 200 — body: %s",
			w.Code, w.Body.String())
	}
	var resp map[string]any
	json.NewDecoder(w.Body).Decode(&resp)
	if resp["user"] == nil {
		t.Error("expected user in response")
	}
	if resp["session"] == nil {
		t.Error("expected session in response")
	}
}

func TestExchangeGitHubCode_MissingCode(t *testing.T) {
	mux := newTestMux(t)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/github/exchange",
		strings.NewReader(`{"code":""}`))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	// Empty code should fail at the service level
	if w.Code == http.StatusOK {
		t.Error("expected non-200 for empty code")
	}
}

// ── Tasks ─────────────────────────────────────────────────────────────────────

func TestCreateAndListTasks(t *testing.T) {
	mux := newTestMux(t)

	// Create task using dev X-User-ID header
	body := `{"title":"Test task","priority":"high"}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/tasks", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-User-ID", "dev-user-1")
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusCreated && w.Code != http.StatusOK {
		t.Fatalf("POST /api/v1/tasks status = %d — body: %s", w.Code, w.Body.String())
	}

	// List tasks
	req2 := httptest.NewRequest(http.MethodGet, "/api/v1/tasks", nil)
	req2.Header.Set("X-User-ID", "dev-user-1")
	w2 := httptest.NewRecorder()
	mux.ServeHTTP(w2, req2)

	if w2.Code != http.StatusOK {
		t.Fatalf("GET /api/v1/tasks status = %d — body: %s", w2.Code, w2.Body.String())
	}
	var listResp map[string]any
	json.NewDecoder(w2.Body).Decode(&listResp)
	items, ok := listResp["items"].([]any)
	if !ok || len(items) == 0 {
		t.Errorf("expected at least 1 task in list, got: %v", listResp)
	}
}

func TestContentTypeJSON(t *testing.T) {
	mux := newTestMux(t)
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	ct := w.Header().Get("Content-Type")
	if !strings.HasPrefix(ct, "application/json") {
		t.Errorf("Content-Type = %q, want application/json", ct)
	}
}
