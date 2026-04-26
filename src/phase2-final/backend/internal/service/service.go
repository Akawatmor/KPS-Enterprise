package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"sort"
	"strings"
	"sync/atomic"
	"time"

	"github.com/KPS-Enterprise/todoapp/backend/internal/auth"
	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
	"github.com/KPS-Enterprise/todoapp/backend/internal/model"
	"github.com/KPS-Enterprise/todoapp/backend/internal/store"
)

type Service struct {
	cfg       config.Config
	logger    *log.Logger
	store     store.Adapter
	providers map[string]auth.Provider
	clock     func() time.Time
	counter   uint64
}

type SessionBundle struct {
	User    model.User    `json:"user"`
	Session model.Session `json:"session"`
}

type TaskListFilter struct {
	UserID   string
	Status   string
	Column   string
	DueStart *time.Time
	DueEnd   *time.Time
}

type ReminderDispatchInput struct {
	ScheduleID      string `json:"schedule_id"`
	IdempotencyKey  string `json:"idempotency_key"`
	Channel         string `json:"channel"`
	RequestedByUser string
}

func New(cfg config.Config, logger *log.Logger, st store.Adapter) *Service {
	providers := map[string]auth.Provider{
		"github": auth.NewGitHubProvider(),
	}
	return &Service{
		cfg:       cfg,
		logger:    logger,
		store:     st,
		providers: providers,
		clock:     func() time.Time { return time.Now().UTC() },
	}
}

// NewWithClock is like New but accepts a custom clock function. Use in tests.
func NewWithClock(cfg config.Config, logger *log.Logger, st store.Adapter, clock func() time.Time) *Service {
	s := New(cfg, logger, st)
	s.clock = clock
	return s
}

func (s *Service) AdapterKind() string            { return s.store.Kind() }
func (s *Service) Ping(ctx context.Context) error { return s.store.Ping(ctx) }
func (s *Service) Close() error                   { return s.store.Close() }
func (s *Service) Now() time.Time                 { return s.clock() }

func (s *Service) nextID(prefix string) string {
	value := atomic.AddUint64(&s.counter, 1)
	return fmt.Sprintf("%s_%d_%d", prefix, s.clock().UnixMilli(), value)
}

func newToken(prefix string) (string, error) {
	buff := make([]byte, 24)
	if _, err := rand.Read(buff); err != nil {
		return "", fmt.Errorf("generate token: %w", err)
	}
	return prefix + "_" + hex.EncodeToString(buff), nil
}

func saveEntity(ctx context.Context, st store.Adapter, collection, id string, value any) error {
	payload, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("marshal %s/%s: %w", collection, id, err)
	}
	return st.UpsertRaw(ctx, collection, id, payload)
}

func loadEntity[T any](ctx context.Context, st store.Adapter, collection, id string) (T, bool, error) {
	var zero T
	payload, found, err := st.GetRaw(ctx, collection, id)
	if err != nil {
		return zero, false, err
	}
	if !found {
		return zero, false, nil
	}
	var value T
	if err := json.Unmarshal(payload, &value); err != nil {
		return zero, false, fmt.Errorf("unmarshal %s/%s: %w", collection, id, err)
	}
	return value, true, nil
}

func listEntities[T any](ctx context.Context, st store.Adapter, collection string) ([]T, error) {
	payloads, err := st.ListRaw(ctx, collection)
	if err != nil {
		return nil, err
	}
	items := make([]T, 0, len(payloads))
	for _, payload := range payloads {
		var item T
		if err := json.Unmarshal(payload, &item); err != nil {
			return nil, fmt.Errorf("unmarshal list %s: %w", collection, err)
		}
		items = append(items, item)
	}
	return items, nil
}

// ── Auth ──────────────────────────────────────────────────────────────────────

func (s *Service) ListAuthProviders() []string {
	keys := make([]string, 0, len(s.providers))
	for name := range s.providers {
		keys = append(keys, name)
	}
	sort.Strings(keys)
	return keys
}

func (s *Service) ExchangeOAuthCode(ctx context.Context, providerName, code string) (SessionBundle, error) {
	providerName = strings.ToLower(strings.TrimSpace(providerName))
	provider, ok := s.providers[providerName]
	if !ok {
		return SessionBundle{}, fmt.Errorf("unsupported oauth provider: %s", providerName)
	}

	profile, err := provider.ExchangeCode(ctx, code)
	if err != nil {
		return SessionBundle{}, err
	}

	now := s.clock()
	identities, err := listEntities[model.OAuthIdentity](ctx, s.store, store.CollectionOAuthIdentities)
	if err != nil {
		return SessionBundle{}, err
	}

	var identity model.OAuthIdentity
	identityFound := false
	for _, candidate := range identities {
		if candidate.Provider == providerName && candidate.ExternalUserID == profile.ExternalUserID {
			identity = candidate
			identityFound = true
			break
		}
	}

	var user model.User
	if identityFound {
		loaded, found, err := loadEntity[model.User](ctx, s.store, store.CollectionUsers, identity.UserID)
		if err != nil {
			return SessionBundle{}, err
		}
		if !found {
			return SessionBundle{}, fmt.Errorf("identity references missing user: %s", identity.UserID)
		}
		user = loaded
		user.Email = profile.Email
		user.DisplayName = profile.DisplayName
		user.UpdatedAt = now
	} else {
		user = model.User{
			ID:          s.nextID("usr"),
			Email:       profile.Email,
			DisplayName: profile.DisplayName,
			Locale:      "th",
			Theme:       "light",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		identity = model.OAuthIdentity{
			ID:             s.nextID("oid"),
			UserID:         user.ID,
			Provider:       providerName,
			ExternalUserID: profile.ExternalUserID,
			Email:          profile.Email,
			DisplayName:    profile.DisplayName,
			CreatedAt:      now,
			UpdatedAt:      now,
		}
	}

	if err := saveEntity(ctx, s.store, store.CollectionUsers, user.ID, user); err != nil {
		return SessionBundle{}, err
	}
	identity.Email = profile.Email
	identity.DisplayName = profile.DisplayName
	identity.UpdatedAt = now
	if err := saveEntity(ctx, s.store, store.CollectionOAuthIdentities, identity.ID, identity); err != nil {
		return SessionBundle{}, err
	}

	session, err := s.createSession(ctx, user.ID, providerName)
	if err != nil {
		return SessionBundle{}, err
	}
	return SessionBundle{User: user, Session: session}, nil
}

func (s *Service) createSession(ctx context.Context, userID, provider string) (model.Session, error) {
	now := s.clock()
	accessToken, err := newToken("atk")
	if err != nil {
		return model.Session{}, err
	}
	refreshToken, err := newToken("rtk")
	if err != nil {
		return model.Session{}, err
	}
	session := model.Session{
		ID:               s.nextID("ses"),
		UserID:           userID,
		Provider:         provider,
		AccessToken:      accessToken,
		RefreshToken:     refreshToken,
		AccessExpiresAt:  now.Add(s.cfg.AuthAccessTokenTTL),
		RefreshExpiresAt: now.Add(s.cfg.AuthRefreshTokenTTL),
		CreatedAt:        now,
	}
	if err := saveEntity(ctx, s.store, store.CollectionSessions, session.ID, session); err != nil {
		return model.Session{}, err
	}
	return session, nil
}

func (s *Service) AuthenticateAccessToken(ctx context.Context, accessToken string) (model.Session, error) {
	if strings.TrimSpace(accessToken) == "" {
		return model.Session{}, fmt.Errorf("access token is required")
	}
	sessions, err := listEntities[model.Session](ctx, s.store, store.CollectionSessions)
	if err != nil {
		return model.Session{}, err
	}
	now := s.clock()
	for _, session := range sessions {
		if session.AccessToken != accessToken {
			continue
		}
		if session.RevokedAt != nil {
			return model.Session{}, fmt.Errorf("session revoked")
		}
		if now.After(session.AccessExpiresAt) {
			return model.Session{}, fmt.Errorf("access token expired")
		}
		return session, nil
	}
	return model.Session{}, fmt.Errorf("session not found")
}

func (s *Service) RefreshSession(ctx context.Context, refreshToken string) (model.Session, error) {
	if strings.TrimSpace(refreshToken) == "" {
		return model.Session{}, fmt.Errorf("refresh token is required")
	}
	sessions, err := listEntities[model.Session](ctx, s.store, store.CollectionSessions)
	if err != nil {
		return model.Session{}, err
	}
	now := s.clock()
	var matched *model.Session
	for idx := range sessions {
		if sessions[idx].RefreshToken == refreshToken {
			matched = &sessions[idx]
			break
		}
	}
	if matched == nil {
		return model.Session{}, fmt.Errorf("refresh token not found")
	}
	if matched.RevokedAt != nil {
		return model.Session{}, fmt.Errorf("session revoked")
	}
	if now.After(matched.RefreshExpiresAt) {
		return model.Session{}, fmt.Errorf("refresh token expired")
	}
	matched.RevokedAt = &now
	if err := saveEntity(ctx, s.store, store.CollectionSessions, matched.ID, *matched); err != nil {
		return model.Session{}, err
	}
	return s.createSession(ctx, matched.UserID, matched.Provider)
}

func (s *Service) LogoutAccessToken(ctx context.Context, accessToken string) error {
	sessions, err := listEntities[model.Session](ctx, s.store, store.CollectionSessions)
	if err != nil {
		return err
	}
	now := s.clock()
	for _, session := range sessions {
		if session.AccessToken == accessToken {
			session.RevokedAt = &now
			return saveEntity(ctx, s.store, store.CollectionSessions, session.ID, session)
		}
	}
	return fmt.Errorf("session not found")
}

// ── Tasks ─────────────────────────────────────────────────────────────────────

func (s *Service) CreateTask(ctx context.Context, task model.Task) (model.Task, error) {
	now := s.clock()
	task.ID = s.nextID("tsk")
	task.CreatedAt = now
	task.UpdatedAt = now
	if task.Column == "" {
		task.Column = "todo"
	}
	if task.Status == "" {
		task.Status = model.TaskStatusOpen
	}
	if task.Priority == "" {
		task.Priority = "normal"
	}
	if err := saveEntity(ctx, s.store, store.CollectionTasks, task.ID, task); err != nil {
		return model.Task{}, err
	}
	return task, nil
}

func (s *Service) UpdateTask(ctx context.Context, taskID, userID string, patch map[string]any) (model.Task, error) {
	task, found, err := loadEntity[model.Task](ctx, s.store, store.CollectionTasks, taskID)
	if err != nil {
		return model.Task{}, err
	}
	if !found {
		return model.Task{}, fmt.Errorf("task not found")
	}
	if task.UserID != userID {
		return model.Task{}, fmt.Errorf("forbidden")
	}

	if value, ok := patch["title"].(string); ok && strings.TrimSpace(value) != "" {
		task.Title = value
	}
	if value, ok := patch["description"].(string); ok {
		task.Description = value
	}
	if value, ok := patch["column"].(string); ok && strings.TrimSpace(value) != "" {
		task.Column = value
	}
	if value, ok := patch["position"].(int); ok {
		task.Position = value
	}
	if value, ok := patch["priority"].(string); ok && strings.TrimSpace(value) != "" {
		task.Priority = value
	}
	if value, ok := patch["status"].(string); ok {
		switch value {
		case model.TaskStatusDone:
			now := s.clock()
			task.Status = model.TaskStatusDone
			task.CompletedAt = &now
		case model.TaskStatusOpen:
			task.Status = model.TaskStatusOpen
			task.CompletedAt = nil
		}
	}
	if value, ok := patch["due_at"].(*time.Time); ok {
		task.DueAt = value
	}
	task.UpdatedAt = s.clock()

	if err := saveEntity(ctx, s.store, store.CollectionTasks, task.ID, task); err != nil {
		return model.Task{}, err
	}
	return task, nil
}

func (s *Service) DeleteTask(ctx context.Context, taskID, userID string) error {
	task, found, err := loadEntity[model.Task](ctx, s.store, store.CollectionTasks, taskID)
	if err != nil {
		return err
	}
	if !found {
		return fmt.Errorf("task not found")
	}
	if task.UserID != userID {
		return fmt.Errorf("forbidden")
	}
	subtasks, err := listEntities[model.SubTask](ctx, s.store, store.CollectionSubTasks)
	if err != nil {
		return err
	}
	for _, subtask := range subtasks {
		if subtask.TaskID == taskID {
			if err := s.store.Delete(ctx, store.CollectionSubTasks, subtask.ID); err != nil {
				return err
			}
		}
	}
	return s.store.Delete(ctx, store.CollectionTasks, taskID)
}

func (s *Service) ListTasks(ctx context.Context, filter TaskListFilter) ([]model.TaskWithSubTasks, error) {
	tasks, err := listEntities[model.Task](ctx, s.store, store.CollectionTasks)
	if err != nil {
		return nil, err
	}
	subtasks, err := listEntities[model.SubTask](ctx, s.store, store.CollectionSubTasks)
	if err != nil {
		return nil, err
	}

	subByTask := map[string][]model.SubTask{}
	for _, sub := range subtasks {
		subByTask[sub.TaskID] = append(subByTask[sub.TaskID], sub)
	}
	for taskID := range subByTask {
		sort.Slice(subByTask[taskID], func(i, j int) bool {
			return subByTask[taskID][i].Position < subByTask[taskID][j].Position
		})
	}

	result := make([]model.TaskWithSubTasks, 0)
	for _, task := range tasks {
		if task.UserID != filter.UserID {
			continue
		}
		if filter.Status != "" && task.Status != filter.Status {
			continue
		}
		if filter.Column != "" && task.Column != filter.Column {
			continue
		}
		if filter.DueStart != nil && task.DueAt != nil && task.DueAt.Before(*filter.DueStart) {
			continue
		}
		if filter.DueEnd != nil && task.DueAt != nil && task.DueAt.After(*filter.DueEnd) {
			continue
		}
		result = append(result, model.TaskWithSubTasks{Task: task, SubTasks: subByTask[task.ID]})
	}

	sort.Slice(result, func(i, j int) bool {
		ti := result[i].Task
		tj := result[j].Task
		if ti.DueAt != nil && tj.DueAt != nil {
			return ti.DueAt.Before(*tj.DueAt)
		}
		if ti.DueAt != nil {
			return true
		}
		if tj.DueAt != nil {
			return false
		}
		return ti.CreatedAt.Before(tj.CreatedAt)
	})
	return result, nil
}

// ── SubTasks ─────────────────────────────────────────────────────────────────

func (s *Service) CreateSubTask(ctx context.Context, subtask model.SubTask) (model.SubTask, error) {
	task, found, err := loadEntity[model.Task](ctx, s.store, store.CollectionTasks, subtask.TaskID)
	if err != nil {
		return model.SubTask{}, err
	}
	if !found {
		return model.SubTask{}, fmt.Errorf("task not found")
	}
	if task.UserID != subtask.UserID {
		return model.SubTask{}, fmt.Errorf("forbidden")
	}
	now := s.clock()
	subtask.ID = s.nextID("sub")
	subtask.CreatedAt = now
	subtask.UpdatedAt = now
	if err := saveEntity(ctx, s.store, store.CollectionSubTasks, subtask.ID, subtask); err != nil {
		return model.SubTask{}, err
	}
	return subtask, nil
}

func (s *Service) UpdateSubTask(ctx context.Context, taskID, subtaskID, userID string, patch map[string]any) (model.SubTask, error) {
	task, found, err := loadEntity[model.Task](ctx, s.store, store.CollectionTasks, taskID)
	if err != nil {
		return model.SubTask{}, err
	}
	if !found {
		return model.SubTask{}, fmt.Errorf("task not found")
	}
	if task.UserID != userID {
		return model.SubTask{}, fmt.Errorf("forbidden")
	}

	subtask, found, err := loadEntity[model.SubTask](ctx, s.store, store.CollectionSubTasks, subtaskID)
	if err != nil {
		return model.SubTask{}, err
	}
	if !found || subtask.TaskID != taskID {
		return model.SubTask{}, fmt.Errorf("subtask not found")
	}

	if value, ok := patch["title"].(string); ok {
		subtask.Title = value
	}
	if value, ok := patch["position"].(int); ok {
		subtask.Position = value
	}
	if value, ok := patch["is_done"].(bool); ok {
		subtask.IsDone = value
		if value {
			now := s.clock()
			subtask.CompletedAt = &now
		} else {
			subtask.CompletedAt = nil
		}
	}
	subtask.UpdatedAt = s.clock()
	if err := saveEntity(ctx, s.store, store.CollectionSubTasks, subtask.ID, subtask); err != nil {
		return model.SubTask{}, err
	}
	return subtask, nil
}

// ── Reminders (nagger) ────────────────────────────────────────────────────────

func (s *Service) CreateReminderRule(ctx context.Context, rule model.ReminderRule) (model.ReminderRule, model.NaggerSchedule, error) {
	now := s.clock()
	rule.ID = s.nextID("rmr")
	rule.CreatedAt = now
	rule.UpdatedAt = now
	if err := saveEntity(ctx, s.store, store.CollectionReminderRules, rule.ID, rule); err != nil {
		return model.ReminderRule{}, model.NaggerSchedule{}, err
	}

	schedule := model.NaggerSchedule{
		ID:                s.nextID("nag"),
		ReminderRuleID:    rule.ID,
		UserID:            rule.UserID,
		NextRunAt:         now.Add(time.Duration(rule.IntervalMinutes) * time.Minute),
		RemainingDispatch: rule.RepeatCount,
		Status:            model.ScheduleStatusActive,
		CreatedAt:         now,
		UpdatedAt:         now,
	}
	if err := saveEntity(ctx, s.store, store.CollectionNaggerSchedules, schedule.ID, schedule); err != nil {
		return model.ReminderRule{}, model.NaggerSchedule{}, err
	}
	return rule, schedule, nil
}

func (s *Service) ListReminderRules(ctx context.Context, userID string) ([]model.ReminderRule, error) {
	rules, err := listEntities[model.ReminderRule](ctx, s.store, store.CollectionReminderRules)
	if err != nil {
		return nil, err
	}
	filtered := make([]model.ReminderRule, 0)
	for _, rule := range rules {
		if rule.UserID == userID {
			filtered = append(filtered, rule)
		}
	}
	return filtered, nil
}

func (s *Service) UpdateReminderRule(ctx context.Context, ruleID, userID string, patch map[string]any) (model.ReminderRule, error) {
	rule, found, err := loadEntity[model.ReminderRule](ctx, s.store, store.CollectionReminderRules, ruleID)
	if err != nil {
		return model.ReminderRule{}, err
	}
	if !found {
		return model.ReminderRule{}, fmt.Errorf("reminder rule not found")
	}
	if rule.UserID != userID {
		return model.ReminderRule{}, fmt.Errorf("forbidden")
	}
	if value, ok := patch["active"].(bool); ok {
		rule.Active = value
	}
	if value, ok := patch["interval_minutes"].(int); ok {
		rule.IntervalMinutes = value
	}
	if value, ok := patch["repeat_count"].(int); ok {
		rule.RepeatCount = value
	}
	rule.UpdatedAt = s.clock()
	if err := saveEntity(ctx, s.store, store.CollectionReminderRules, rule.ID, rule); err != nil {
		return model.ReminderRule{}, err
	}
	return rule, nil
}

func (s *Service) DispatchNagger(ctx context.Context, input ReminderDispatchInput) (model.NotificationLog, error) {
	schedule, found, err := loadEntity[model.NaggerSchedule](ctx, s.store, store.CollectionNaggerSchedules, input.ScheduleID)
	if err != nil {
		return model.NotificationLog{}, err
	}
	if !found {
		return model.NotificationLog{}, fmt.Errorf("schedule not found")
	}
	if schedule.UserID != input.RequestedByUser {
		return model.NotificationLog{}, fmt.Errorf("forbidden")
	}

	// Idempotency check
	if schedule.LastNotificationID != "" {
		existing, found, err := loadEntity[model.NotificationLog](ctx, s.store, store.CollectionNotificationLogs, schedule.LastNotificationID)
		if err == nil && found && existing.IdempotencyKey == input.IdempotencyKey {
			return existing, nil
		}
	}

	now := s.clock()
	rule, _, err := loadEntity[model.ReminderRule](ctx, s.store, store.CollectionReminderRules, schedule.ReminderRuleID)
	if err != nil {
		return model.NotificationLog{}, err
	}

	logItem := model.NotificationLog{
		ID:             s.nextID("not"),
		UserID:         schedule.UserID,
		ScheduleID:     schedule.ID,
		EntityType:     rule.EntityType,
		EntityID:       rule.EntityID,
		Channel:        input.Channel,
		IdempotencyKey: input.IdempotencyKey,
		Status:         "sent",
		CreatedAt:      now,
	}
	if err := saveEntity(ctx, s.store, store.CollectionNotificationLogs, logItem.ID, logItem); err != nil {
		return model.NotificationLog{}, err
	}

	schedule.LastNotificationID = logItem.ID
	schedule.RemainingDispatch--
	if schedule.RemainingDispatch <= 0 {
		schedule.Status = model.ScheduleStatusCompleted
	} else {
		schedule.NextRunAt = now.Add(time.Duration(rule.IntervalMinutes) * time.Minute)
	}
	schedule.UpdatedAt = now
	if err := saveEntity(ctx, s.store, store.CollectionNaggerSchedules, schedule.ID, schedule); err != nil {
		return model.NotificationLog{}, err
	}
	return logItem, nil
}

func (s *Service) ProcessDueNaggerSchedules(ctx context.Context) (int, error) {
	schedules, err := listEntities[model.NaggerSchedule](ctx, s.store, store.CollectionNaggerSchedules)
	if err != nil {
		return 0, err
	}
	now := s.clock()
	count := 0
	for _, schedule := range schedules {
		if schedule.Status != model.ScheduleStatusActive {
			continue
		}
		if schedule.NextRunAt.After(now) {
			continue
		}
		idempotencyKey := fmt.Sprintf("nagger_%s_%d", schedule.ID, now.UnixMilli())
		_, err := s.DispatchNagger(ctx, ReminderDispatchInput{
			ScheduleID:      schedule.ID,
			IdempotencyKey:  idempotencyKey,
			Channel:         "in_app",
			RequestedByUser: schedule.UserID,
		})
		if err != nil {
			s.logger.Printf("nagger dispatch error schedule=%s: %v", schedule.ID, err)
			continue
		}
		count++
	}
	return count, nil
}
