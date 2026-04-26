package httpapi

import (
	"log"
	"net/http"

	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
	"github.com/KPS-Enterprise/todoapp/backend/internal/service"
)

func NewMux(cfg config.Config, logger *log.Logger, core *service.Service) http.Handler {
	h := NewHandler(cfg, logger, core)
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", h.Healthz)
	mux.HandleFunc("GET /readyz", h.Readyz)
	mux.HandleFunc("GET /api/v1/meta", h.Meta)

	// Auth
	mux.HandleFunc("GET /api/v1/auth/providers", h.ListAuthProviders)
	mux.HandleFunc("POST /api/v1/auth/github/exchange", h.ExchangeGitHubCode)
	mux.HandleFunc("POST /api/v1/auth/session/refresh", h.RefreshAuthSession)
	mux.HandleFunc("POST /api/v1/auth/session/logout", h.LogoutAuthSession)

	// Tasks (core of the todo app)
	mux.HandleFunc("POST /api/v1/tasks", h.CreateTask)
	mux.HandleFunc("GET /api/v1/tasks", h.ListTasks)
	mux.HandleFunc("PATCH /api/v1/tasks/{id}", h.UpdateTask)
	mux.HandleFunc("DELETE /api/v1/tasks/{id}", h.DeleteTask)

	// SubTasks
	mux.HandleFunc("POST /api/v1/tasks/{id}/subtasks", h.CreateSubTask)
	mux.HandleFunc("PATCH /api/v1/tasks/{id}/subtasks/{subtaskID}", h.UpdateSubTask)

	// Reminders
	mux.HandleFunc("POST /api/v1/reminders/rules", h.CreateReminderRule)
	mux.HandleFunc("GET /api/v1/reminders/rules", h.ListReminderRules)
	mux.HandleFunc("PATCH /api/v1/reminders/rules/{id}", h.UpdateReminderRule)
	mux.HandleFunc("POST /api/v1/reminders/dispatch", h.DispatchReminder)

	return withCORS(mux, cfg.AllowedOrigin)
}

func withCORS(next http.Handler, allowedOrigin string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-User-ID")
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
