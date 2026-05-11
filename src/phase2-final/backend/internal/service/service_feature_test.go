package service_test

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
	"github.com/KPS-Enterprise/todoapp/backend/internal/model"
	"github.com/KPS-Enterprise/todoapp/backend/internal/service"
	"github.com/KPS-Enterprise/todoapp/backend/internal/store"
)

func newSeededTestService(t *testing.T) (*service.Service, store.Adapter, time.Time) {
	t.Helper()
	fixed := time.Date(2026, 4, 26, 12, 0, 0, 0, time.UTC)
	cfg := config.Config{
		AuthAccessTokenTTL:  15 * time.Minute,
		AuthRefreshTokenTTL: 7 * 24 * time.Hour,
	}
	logger := log.New(os.Stderr, "[test] ", 0)
	mem := store.NewMemoryAdapter()
	svc := service.NewWithClock(cfg, logger, mem, func() time.Time { return fixed })
	return svc, mem, fixed
}

func persistEntity(t *testing.T, ctx context.Context, st store.Adapter, collection, id string, value any) {
	t.Helper()
	payload, err := json.Marshal(value)
	if err != nil {
		t.Fatalf("marshal %s/%s: %v", collection, id, err)
	}
	if err := st.UpsertRaw(ctx, collection, id, payload); err != nil {
		t.Fatalf("upsert %s/%s: %v", collection, id, err)
	}
}

func seedUser(t *testing.T, ctx context.Context, st store.Adapter, now time.Time, id, email, displayName, role string) model.User {
	t.Helper()
	user := model.User{
		ID:          id,
		Email:       email,
		DisplayName: displayName,
		Role:        role,
		Locale:      "th",
		Theme:       "light",
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	persistEntity(t, ctx, st, store.CollectionUsers, user.ID, user)
	return user
}

func TestListAuthProviders(t *testing.T) {
	svc, _, _ := newSeededTestService(t)
	providers := svc.ListAuthProviders()
	if len(providers) != 2 || providers[0] != model.ProviderGitHub || providers[1] != model.ProviderLocal {
		t.Fatalf("ListAuthProviders() = %v, want [github local]", providers)
	}
}

func TestRefreshSession_RotatesTokensAndRevokesOld(t *testing.T) {
	svc, _, _ := newSeededTestService(t)
	ctx := context.Background()

	bundle, err := svc.ExchangeOAuthCode(ctx, "github", "refresh-code")
	if err != nil {
		t.Fatalf("ExchangeOAuthCode error: %v", err)
	}

	refreshed, err := svc.RefreshSession(ctx, bundle.Session.RefreshToken)
	if err != nil {
		t.Fatalf("RefreshSession error: %v", err)
	}
	if refreshed.UserID != bundle.User.ID {
		t.Fatalf("RefreshSession UserID = %q, want %q", refreshed.UserID, bundle.User.ID)
	}
	if refreshed.AccessToken == bundle.Session.AccessToken {
		t.Fatal("expected new access token")
	}
	if refreshed.RefreshToken == bundle.Session.RefreshToken {
		t.Fatal("expected new refresh token")
	}

	if _, err := svc.AuthenticateAccessToken(ctx, bundle.Session.AccessToken); err == nil || !strings.Contains(err.Error(), "revoked") {
		t.Fatalf("old access token error = %v, want revoked", err)
	}
	if session, err := svc.AuthenticateAccessToken(ctx, refreshed.AccessToken); err != nil || session.UserID != bundle.User.ID {
		t.Fatalf("new access token auth = (%+v, %v), want user %q", session, err, bundle.User.ID)
	}
}

func TestRegisterAndLoginWithPassword(t *testing.T) {
	svc, _, _ := newSeededTestService(t)
	ctx := context.Background()

	bundle, err := svc.RegisterWithPassword(ctx, "alice@example.com", "Str0ng!Pass", "Alice")
	if err != nil {
		t.Fatalf("RegisterWithPassword error: %v", err)
	}
	if bundle.User.Email != "alice@example.com" {
		t.Fatalf("registered email = %q, want alice@example.com", bundle.User.Email)
	}
	if bundle.Session.Provider != model.ProviderLocal {
		t.Fatalf("session provider = %q, want %q", bundle.Session.Provider, model.ProviderLocal)
	}

	login, err := svc.LoginWithPassword(ctx, "ALICE@example.com", "Str0ng!Pass")
	if err != nil {
		t.Fatalf("LoginWithPassword error: %v", err)
	}
	if login.User.ID != bundle.User.ID {
		t.Fatalf("login user = %q, want %q", login.User.ID, bundle.User.ID)
	}

	if _, err := svc.RegisterWithPassword(ctx, "alice@example.com", "Str0ng!Pass", "Alice 2"); err == nil {
		t.Fatal("expected duplicate email error")
	}
	if _, err := svc.LoginWithPassword(ctx, "alice@example.com", "Wrong!Pass1"); err == nil {
		t.Fatal("expected login failure for wrong password")
	}
}

func TestAdminUserManagement(t *testing.T) {
	svc, st, fixed := newSeededTestService(t)
	ctx := context.Background()

	admin := seedUser(t, ctx, st, fixed, "usr_admin", "admin@example.com", "Admin", model.RoleAdmin)
	member, err := svc.RegisterWithPassword(ctx, "member@example.com", "Str0ng!Pass", "Member")
	if err != nil {
		t.Fatalf("RegisterWithPassword(member) error: %v", err)
	}
	if _, err := svc.ListAllUsers(ctx, member.User.ID); err == nil {
		t.Fatal("expected non-admin user listing to fail")
	}

	users, err := svc.ListAllUsers(ctx, admin.ID)
	if err != nil {
		t.Fatalf("ListAllUsers(admin) error: %v", err)
	}
	if len(users) != 2 {
		t.Fatalf("ListAllUsers(admin) len = %d, want 2", len(users))
	}

	updated, err := svc.UpdateUserRole(ctx, member.User.ID, model.RoleAdmin, admin.ID)
	if err != nil {
		t.Fatalf("UpdateUserRole error: %v", err)
	}
	if updated.Role != model.RoleAdmin {
		t.Fatalf("updated role = %q, want %q", updated.Role, model.RoleAdmin)
	}
	if _, err := svc.UpdateUserRole(ctx, member.User.ID, "superadmin", admin.ID); err == nil {
		t.Fatal("expected invalid role error")
	}

	if _, err := svc.CreateTask(ctx, model.Task{UserID: member.User.ID, Title: "Owned task"}); err != nil {
		t.Fatalf("CreateTask(member) error: %v", err)
	}
	if err := svc.DeleteUser(ctx, admin.ID, admin.ID); err == nil {
		t.Fatal("expected self-delete to fail")
	}
	if err := svc.DeleteUser(ctx, member.User.ID, admin.ID); err != nil {
		t.Fatalf("DeleteUser error: %v", err)
	}

	if _, err := svc.GetUserByID(ctx, member.User.ID); err == nil {
		t.Fatal("expected deleted user lookup to fail")
	}
	if _, err := svc.LoginWithPassword(ctx, "member@example.com", "Str0ng!Pass"); err == nil {
		t.Fatal("expected deleted user login to fail")
	}
	items, err := svc.ListTasks(ctx, service.TaskListFilter{UserID: member.User.ID})
	if err != nil {
		t.Fatalf("ListTasks(deleted user) error: %v", err)
	}
	if len(items) != 0 {
		t.Fatalf("deleted user tasks len = %d, want 0", len(items))
	}
}

func TestCollaborationAndPushSubscriptions(t *testing.T) {
	svc, _, _ := newSeededTestService(t)
	ctx := context.Background()

	alice, err := svc.RegisterWithPassword(ctx, "alice@example.com", "Str0ng!Pass", "Alice")
	if err != nil {
		t.Fatalf("RegisterWithPassword(alice) error: %v", err)
	}
	bob, err := svc.RegisterWithPassword(ctx, "bob@example.com", "An0ther!Pass", "Bob")
	if err != nil {
		t.Fatalf("RegisterWithPassword(bob) error: %v", err)
	}

	request, err := svc.SendFriendRequest(ctx, alice.User.ID, bob.User.ID)
	if err != nil {
		t.Fatalf("SendFriendRequest error: %v", err)
	}
	accepted, err := svc.AcceptFriendRequest(ctx, request.ID, bob.User.ID)
	if err != nil {
		t.Fatalf("AcceptFriendRequest error: %v", err)
	}
	if accepted.Status != "accepted" {
		t.Fatalf("friend request status = %q, want accepted", accepted.Status)
	}
	friends, err := svc.ListFriends(ctx, alice.User.ID)
	if err != nil {
		t.Fatalf("ListFriends error: %v", err)
	}
	if len(friends) != 1 || friends[0].ID != bob.User.ID {
		t.Fatalf("ListFriends(alice) = %v, want bob", friends)
	}

	board, err := svc.CreateSharedBoard(ctx, "Shared board", "Team work", alice.User.ID)
	if err != nil {
		t.Fatalf("CreateSharedBoard error: %v", err)
	}
	member, err := svc.AddBoardMember(ctx, board.ID, bob.User.ID, "editor", alice.User.ID)
	if err != nil {
		t.Fatalf("AddBoardMember error: %v", err)
	}
	if member.Role != "editor" {
		t.Fatalf("board member role = %q, want editor", member.Role)
	}
	boards, err := svc.ListUserBoards(ctx, bob.User.ID)
	if err != nil {
		t.Fatalf("ListUserBoards error: %v", err)
	}
	if len(boards) != 1 || boards[0].ID != board.ID {
		t.Fatalf("ListUserBoards(bob) = %v, want board %q", boards, board.ID)
	}

	subscription, err := svc.SavePushSubscription(ctx, bob.User.ID, "https://push.example/sub", "p256dh", "auth")
	if err != nil {
		t.Fatalf("SavePushSubscription error: %v", err)
	}
	duplicate, err := svc.SavePushSubscription(ctx, bob.User.ID, "https://push.example/sub", "p256dh", "auth")
	if err != nil {
		t.Fatalf("SavePushSubscription(duplicate) error: %v", err)
	}
	if duplicate.ID != subscription.ID {
		t.Fatalf("duplicate subscription ID = %q, want %q", duplicate.ID, subscription.ID)
	}
	subscriptions, err := svc.GetUserPushSubscriptions(ctx, bob.User.ID)
	if err != nil {
		t.Fatalf("GetUserPushSubscriptions error: %v", err)
	}
	if len(subscriptions) != 1 || subscriptions[0].Endpoint != "https://push.example/sub" {
		t.Fatalf("GetUserPushSubscriptions = %v, want one endpoint", subscriptions)
	}
}

func TestSubTasksAndReminders(t *testing.T) {
	svc, st, fixed := newSeededTestService(t)
	ctx := context.Background()

	bundle, err := svc.RegisterWithPassword(ctx, "owner@example.com", "Str0ng!Pass", "Owner")
	if err != nil {
		t.Fatalf("RegisterWithPassword error: %v", err)
	}
	task, err := svc.CreateTask(ctx, model.Task{UserID: bundle.User.ID, Title: "Parent task"})
	if err != nil {
		t.Fatalf("CreateTask error: %v", err)
	}
	subtask, err := svc.CreateSubTask(ctx, model.SubTask{TaskID: task.ID, UserID: bundle.User.ID, Title: "Child", Position: 1})
	if err != nil {
		t.Fatalf("CreateSubTask error: %v", err)
	}
	updatedSubtask, err := svc.UpdateSubTask(ctx, task.ID, subtask.ID, bundle.User.ID, map[string]any{
		"title":    "Child done",
		"position": 2,
		"is_done":  true,
	})
	if err != nil {
		t.Fatalf("UpdateSubTask error: %v", err)
	}
	if !updatedSubtask.IsDone || updatedSubtask.CompletedAt == nil {
		t.Fatalf("updated subtask = %+v, want completed", updatedSubtask)
	}

	items, err := svc.ListTasks(ctx, service.TaskListFilter{UserID: bundle.User.ID})
	if err != nil {
		t.Fatalf("ListTasks error: %v", err)
	}
	if len(items) != 1 || len(items[0].SubTasks) != 1 || items[0].SubTasks[0].ID != subtask.ID {
		t.Fatalf("ListTasks with subtasks = %+v, want one subtask %q", items, subtask.ID)
	}

	rule, schedule, err := svc.CreateReminderRule(ctx, model.ReminderRule{
		UserID:          bundle.User.ID,
		EntityType:      "task",
		EntityID:        task.ID,
		IntervalMinutes: 30,
		RepeatCount:     2,
		Active:          true,
	})
	if err != nil {
		t.Fatalf("CreateReminderRule error: %v", err)
	}
	rules, err := svc.ListReminderRules(ctx, bundle.User.ID)
	if err != nil {
		t.Fatalf("ListReminderRules error: %v", err)
	}
	if len(rules) != 1 || rules[0].ID != rule.ID {
		t.Fatalf("ListReminderRules = %v, want rule %q", rules, rule.ID)
	}
	updatedRule, err := svc.UpdateReminderRule(ctx, rule.ID, bundle.User.ID, map[string]any{
		"active":       false,
		"repeat_count": 3,
	})
	if err != nil {
		t.Fatalf("UpdateReminderRule error: %v", err)
	}
	if updatedRule.Active || updatedRule.RepeatCount != 3 {
		t.Fatalf("updated reminder rule = %+v, want inactive repeat_count=3", updatedRule)
	}

	logItem, err := svc.DispatchNagger(ctx, service.ReminderDispatchInput{
		ScheduleID:      schedule.ID,
		IdempotencyKey:  "idem-1",
		Channel:         "in_app",
		RequestedByUser: bundle.User.ID,
	})
	if err != nil {
		t.Fatalf("DispatchNagger error: %v", err)
	}
	duplicate, err := svc.DispatchNagger(ctx, service.ReminderDispatchInput{
		ScheduleID:      schedule.ID,
		IdempotencyKey:  "idem-1",
		Channel:         "in_app",
		RequestedByUser: bundle.User.ID,
	})
	if err != nil {
		t.Fatalf("DispatchNagger(duplicate) error: %v", err)
	}
	if duplicate.ID != logItem.ID {
		t.Fatalf("duplicate nagger log ID = %q, want %q", duplicate.ID, logItem.ID)
	}

	_, dueSchedule, err := svc.CreateReminderRule(ctx, model.ReminderRule{
		UserID:          bundle.User.ID,
		EntityType:      "task",
		EntityID:        task.ID,
		IntervalMinutes: 1,
		RepeatCount:     1,
		Active:          true,
	})
	if err != nil {
		t.Fatalf("CreateReminderRule(due) error: %v", err)
	}
	dueSchedule.NextRunAt = fixed.Add(-time.Minute)
	persistEntity(t, ctx, st, store.CollectionNaggerSchedules, dueSchedule.ID, dueSchedule)

	processed, err := svc.ProcessDueNaggerSchedules(ctx)
	if err != nil {
		t.Fatalf("ProcessDueNaggerSchedules error: %v", err)
	}
	if processed != 1 {
		t.Fatalf("ProcessDueNaggerSchedules processed = %d, want 1", processed)
	}

	if err := svc.DeleteTask(ctx, task.ID, bundle.User.ID); err != nil {
		t.Fatalf("DeleteTask error: %v", err)
	}
	items, err = svc.ListTasks(ctx, service.TaskListFilter{UserID: bundle.User.ID})
	if err != nil {
		t.Fatalf("ListTasks(after delete) error: %v", err)
	}
	if len(items) != 0 {
		t.Fatalf("ListTasks(after delete) len = %d, want 0", len(items))
	}
}