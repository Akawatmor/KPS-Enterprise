package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
	"github.com/KPS-Enterprise/todoapp/backend/internal/model"
	"github.com/KPS-Enterprise/todoapp/backend/internal/service"
)

type Handler struct {
	cfg    config.Config
	logger *log.Logger
	core   *service.Service
}

func NewHandler(cfg config.Config, logger *log.Logger, core *service.Service) *Handler {
	return &Handler{cfg: cfg, logger: logger, core: core}
}

func (h *Handler) Healthz(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status":  "ok",
		"service": "todoapp-core",
		"time":    time.Now().UTC().Format(time.RFC3339),
	})
}

func (h *Handler) Readyz(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if h.core != nil {
		if err := h.core.Ping(r.Context()); err != nil {
			h.logger.Printf("readyz ping failed: %v", err)
			writeError(w, http.StatusServiceUnavailable, "storage backend not reachable")
			return
		}
	}
	if h.cfg.DataBackend == "sqlite" {
		// G304: resolve to a clean absolute path to prevent directory traversal
		dbPath := filepath.Clean(h.cfg.SQLitePath)
		if !filepath.IsAbs(dbPath) {
			writeError(w, http.StatusInternalServerError, "sqlite path must be absolute")
			return
		}
		// G301: directory permissions 0750 (owner rwx, group rx, others none)
		if err := os.MkdirAll(filepath.Dir(dbPath), 0o750); err != nil {
			writeError(w, http.StatusServiceUnavailable, "sqlite volume not writable")
			return
		}
		// G302: file permissions 0600 (owner rw, no group/others access)
		f, err := os.OpenFile(dbPath, os.O_CREATE|os.O_RDWR, 0o600) // #nosec G304 -- path is cleaned and validated above
		if err != nil {
			writeError(w, http.StatusServiceUnavailable, "sqlite file not writable")
			return
		}
		_ = f.Close()
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status":       "ready",
		"data_backend": h.cfg.DataBackend,
	})
}

func (h *Handler) Meta(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	providers := []string{}
	if h.core != nil {
		providers = h.core.ListAuthProviders()
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"name":             "TodoApp",
		"description":      "Todo app with big calendar — Phase 2 K3s + Woodpecker",
		"backend":          "Go",
		"data_backend":     h.cfg.DataBackend,
		"auth_providers":   providers,
		"features":         []string{"tasks", "subtasks", "reminders", "calendar-view", "friends", "shared-boards", "pwa", "push-notifications", "admin-panel"},
		"infra":            "K3s 3-node (1 master + 2 workers) + Woodpecker CI/CD + Docker Hub",
	})
}

// ── Auth ──────────────────────────────────────────────────────────────────────

func (h *Handler) ListAuthProviders(w http.ResponseWriter, r *http.Request) {
	if h.core == nil {
		writeJSON(w, http.StatusOK, map[string]any{"providers": []string{}})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"providers": h.core.ListAuthProviders()})
}

func (h *Handler) ExchangeGitHubCode(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Code string `json:"code"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	bundle, err := h.core.ExchangeOAuthCode(r.Context(), "github", req.Code)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, bundle)
}

func (h *Handler) RefreshAuthSession(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	session, err := h.core.RefreshSession(r.Context(), req.RefreshToken)
	if err != nil {
		writeError(w, http.StatusUnauthorized, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"session": session})
}

func (h *Handler) LogoutAuthSession(w http.ResponseWriter, r *http.Request) {
	accessToken := bearerToken(r)
	if accessToken == "" {
		var req struct {
			AccessToken string `json:"access_token"`
		}
		_ = decodeJSON(r, &req)
		accessToken = req.AccessToken
	}
	if strings.TrimSpace(accessToken) == "" {
		writeError(w, http.StatusBadRequest, "access token is required")
		return
	}
	if err := h.core.LogoutAccessToken(r.Context(), accessToken); err != nil {
		writeError(w, http.StatusUnauthorized, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "logged_out"})
}

// ── Tasks ─────────────────────────────────────────────────────────────────────

func (h *Handler) CreateTask(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		Title       string     `json:"title"`
		Description string     `json:"description"`
		Column      string     `json:"column"`
		Position    int        `json:"position"`
		Priority    string     `json:"priority"`
		DueAt       *time.Time `json:"due_at"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	task, err := h.core.CreateTask(r.Context(), model.Task{
		UserID:      userID,
		Title:       req.Title,
		Description: req.Description,
		Column:      req.Column,
		Position:    req.Position,
		Priority:    req.Priority,
		DueAt:       req.DueAt,
	})
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, task)
}

func (h *Handler) ListTasks(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	filter := service.TaskListFilter{
		UserID: userID,
		Status: strings.TrimSpace(r.URL.Query().Get("status")),
		Column: strings.TrimSpace(r.URL.Query().Get("column")),
	}
	if value := strings.TrimSpace(r.URL.Query().Get("due_start")); value != "" {
		parsed, err := time.Parse(time.RFC3339, value)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid due_start")
			return
		}
		filter.DueStart = &parsed
	}
	if value := strings.TrimSpace(r.URL.Query().Get("due_end")); value != "" {
		parsed, err := time.Parse(time.RFC3339, value)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid due_end")
			return
		}
		filter.DueEnd = &parsed
	}
	items, err := h.core.ListTasks(r.Context(), filter)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) UpdateTask(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		Title       *string    `json:"title"`
		Description *string    `json:"description"`
		Status      *string    `json:"status"`
		Column      *string    `json:"column"`
		Position    *int       `json:"position"`
		Priority    *string    `json:"priority"`
		DueAt       *time.Time `json:"due_at"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	patch := map[string]any{}
	if req.Title != nil {
		patch["title"] = *req.Title
	}
	if req.Description != nil {
		patch["description"] = *req.Description
	}
	if req.Status != nil {
		patch["status"] = *req.Status
	}
	if req.Column != nil {
		patch["column"] = *req.Column
	}
	if req.Position != nil {
		patch["position"] = *req.Position
	}
	if req.Priority != nil {
		patch["priority"] = *req.Priority
	}
	if req.DueAt != nil {
		patch["due_at"] = req.DueAt
	}
	task, err := h.core.UpdateTask(r.Context(), r.PathValue("id"), userID, patch)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, task)
}

func (h *Handler) DeleteTask(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	if err := h.core.DeleteTask(r.Context(), r.PathValue("id"), userID); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "deleted"})
}

// ── SubTasks ──────────────────────────────────────────────────────────────────

func (h *Handler) CreateSubTask(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		Title    string `json:"title"`
		Position int    `json:"position"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	subtask, err := h.core.CreateSubTask(r.Context(), model.SubTask{
		TaskID:   r.PathValue("id"),
		UserID:   userID,
		Title:    req.Title,
		Position: req.Position,
	})
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, subtask)
}

func (h *Handler) UpdateSubTask(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		Title    *string `json:"title"`
		Position *int    `json:"position"`
		IsDone   *bool   `json:"is_done"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	patch := map[string]any{}
	if req.Title != nil {
		patch["title"] = *req.Title
	}
	if req.Position != nil {
		patch["position"] = *req.Position
	}
	if req.IsDone != nil {
		patch["is_done"] = *req.IsDone
	}
	subtask, err := h.core.UpdateSubTask(r.Context(), r.PathValue("id"), r.PathValue("subtaskID"), userID, patch)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, subtask)
}

// ── Reminders ─────────────────────────────────────────────────────────────────

func (h *Handler) CreateReminderRule(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		EntityType      string `json:"entity_type"`
		EntityID        string `json:"entity_id"`
		IntervalMinutes int    `json:"interval_minutes"`
		RepeatCount     int    `json:"repeat_count"`
		Active          bool   `json:"active"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	rule, schedule, err := h.core.CreateReminderRule(r.Context(), model.ReminderRule{
		UserID:          userID,
		EntityType:      req.EntityType,
		EntityID:        req.EntityID,
		IntervalMinutes: req.IntervalMinutes,
		RepeatCount:     req.RepeatCount,
		Active:          req.Active,
	})
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"rule": rule, "schedule": schedule})
}

func (h *Handler) ListReminderRules(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	rules, err := h.core.ListReminderRules(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": rules})
}

func (h *Handler) UpdateReminderRule(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		Active          *bool `json:"active"`
		IntervalMinutes *int  `json:"interval_minutes"`
		RepeatCount     *int  `json:"repeat_count"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	patch := map[string]any{}
	if req.Active != nil {
		patch["active"] = *req.Active
	}
	if req.IntervalMinutes != nil {
		patch["interval_minutes"] = *req.IntervalMinutes
	}
	if req.RepeatCount != nil {
		patch["repeat_count"] = *req.RepeatCount
	}
	rule, err := h.core.UpdateReminderRule(r.Context(), r.PathValue("id"), userID, patch)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, rule)
}

func (h *Handler) DispatchReminder(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req service.ReminderDispatchInput
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	req.RequestedByUser = userID
	logItem, err := h.core.DispatchNagger(r.Context(), req)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, logItem)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

func (h *Handler) resolveUserID(w http.ResponseWriter, r *http.Request) (string, bool) {
	if headerUserID := strings.TrimSpace(r.Header.Get("X-User-ID")); headerUserID != "" {
		return headerUserID, true
	}
	token := bearerToken(r)
	if token == "" {
		writeError(w, http.StatusUnauthorized, "missing access token")
		return "", false
	}
	session, err := h.core.AuthenticateAccessToken(r.Context(), token)
	if err != nil {
		writeError(w, http.StatusUnauthorized, err.Error())
		return "", false
	}
	return session.UserID, true
}

func bearerToken(r *http.Request) string {
	value := strings.TrimSpace(r.Header.Get("Authorization"))
	if value == "" {
		return ""
	}
	parts := strings.SplitN(value, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return ""
	}
	return strings.TrimSpace(parts[1])
}

func decodeJSON(r *http.Request, dst any) error {
	if r.Body == nil {
		return errors.New("request body is required")
	}
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(dst); err != nil {
		return fmtBadRequestError(err)
	}
	return nil
}

func fmtBadRequestError(err error) error {
	if errors.Is(err, context.Canceled) {
		return errors.New("request canceled")
	}
	return err
}

func writeError(w http.ResponseWriter, statusCode int, message string) {
	writeJSON(w, statusCode, map[string]string{"error": message})
}

func writeJSON(w http.ResponseWriter, statusCode int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(payload)
}

// ── Password Auth ─────────────────────────────────────────────────────────────

func (h *Handler) RegisterWithPassword(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email       string `json:"email"`
		Password    string `json:"password"`
		DisplayName string `json:"display_name"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	bundle, err := h.core.RegisterWithPassword(r.Context(), req.Email, req.Password, req.DisplayName)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, bundle)
}

func (h *Handler) LoginWithPassword(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	bundle, err := h.core.LoginWithPassword(r.Context(), req.Email, req.Password)
	if err != nil {
		writeError(w, http.StatusUnauthorized, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, bundle)
}

// ── Admin ─────────────────────────────────────────────────────────────────────

func (h *Handler) AdminListUsers(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	users, err := h.core.ListAllUsers(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": users})
}

func (h *Handler) AdminUpdateUserRole(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		Role string `json:"role"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	targetID := r.PathValue("id")
	user, err := h.core.UpdateUserRole(r.Context(), targetID, req.Role, userID)
	if err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, user)
}

func (h *Handler) AdminDeleteUser(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	targetID := r.PathValue("id")
	if err := h.core.DeleteUser(r.Context(), targetID, userID); err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "deleted"})
}

// ── Friends ───────────────────────────────────────────────────────────────────

func (h *Handler) SendFriendRequest(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		FriendID string `json:"friend_id"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	friend, err := h.core.SendFriendRequest(r.Context(), userID, req.FriendID)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, friend)
}

func (h *Handler) AcceptFriendRequest(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	friendshipID := r.PathValue("id")
	friend, err := h.core.AcceptFriendRequest(r.Context(), friendshipID, userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, friend)
}

func (h *Handler) ListFriends(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	friends, err := h.core.ListFriends(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": friends})
}

// ── Shared Boards ─────────────────────────────────────────────────────────────

func (h *Handler) CreateSharedBoard(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	board, err := h.core.CreateSharedBoard(r.Context(), req.Name, req.Description, userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, board)
}

func (h *Handler) ListUserBoards(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	boards, err := h.core.ListUserBoards(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": boards})
}

func (h *Handler) AddBoardMember(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	boardID := r.PathValue("id")
	var req struct {
		UserID string `json:"user_id"`
		Role   string `json:"role"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	member, err := h.core.AddBoardMember(r.Context(), boardID, req.UserID, req.Role, userID)
	if err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, member)
}

// ── Push Subscriptions ────────────────────────────────────────────────────────

func (h *Handler) SavePushSubscription(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		Endpoint string `json:"endpoint"`
		P256dh   string `json:"p256dh"`
		Auth     string `json:"auth"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	subscription, err := h.core.SavePushSubscription(r.Context(), userID, req.Endpoint, req.P256dh, req.Auth)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, subscription)
}

func (h *Handler) GetPushSubscriptions(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.resolveUserID(w, r)
	if !ok {
		return
	}
	subscriptions, err := h.core.GetUserPushSubscriptions(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": subscriptions})
}
