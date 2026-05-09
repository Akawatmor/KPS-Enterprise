package model

import "time"

const (
	TaskStatusOpen = "open"
	TaskStatusDone = "done"

	ScheduleStatusActive    = "active"
	ScheduleStatusCompleted = "completed"

	// User Roles
	RoleUser  = "user"
	RoleAdmin = "admin"

	// Auth Providers
	ProviderLocal  = "local"
	ProviderGitHub = "github"
)

type User struct {
	ID          string    `json:"id"`
	Email       string    `json:"email"`
	DisplayName string    `json:"display_name"`
	Role        string    `json:"role"` // user, admin
	Locale      string    `json:"locale"`
	Theme       string    `json:"theme"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type OAuthIdentity struct {
	ID             string    `json:"id"`
	UserID         string    `json:"user_id"`
	Provider       string    `json:"provider"`
	ExternalUserID string    `json:"external_user_id"`
	Email          string    `json:"email"`
	DisplayName    string    `json:"display_name"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// LocalAuthIdentity stores password-based authentication credentials
type LocalAuthIdentity struct {
	ID           string    `json:"id"`
	UserID       string    `json:"user_id"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"` // Never expose password hash in JSON
	EmailVerified bool     `json:"email_verified"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type Session struct {
	ID               string     `json:"id"`
	UserID           string     `json:"user_id"`
	Provider         string     `json:"provider"`
	AccessToken      string     `json:"access_token"`
	RefreshToken     string     `json:"refresh_token"`
	AccessExpiresAt  time.Time  `json:"access_expires_at"`
	RefreshExpiresAt time.Time  `json:"refresh_expires_at"`
	CreatedAt        time.Time  `json:"created_at"`
	RevokedAt        *time.Time `json:"revoked_at,omitempty"`
}

// Task is the core entity for the todo app.
type Task struct {
	ID          string     `json:"id"`
	UserID      string     `json:"user_id"`
	Title       string     `json:"title"`
	Description string     `json:"description"`
	Status      string     `json:"status"`
	Priority    string     `json:"priority"`
	Column      string     `json:"column"`
	Position    int        `json:"position"`
	DueAt       *time.Time `json:"due_at,omitempty"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

type SubTask struct {
	ID          string     `json:"id"`
	TaskID      string     `json:"task_id"`
	UserID      string     `json:"user_id"`
	Title       string     `json:"title"`
	IsDone      bool       `json:"is_done"`
	Position    int        `json:"position"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

type TaskWithSubTasks struct {
	Task     Task      `json:"task"`
	SubTasks []SubTask `json:"subtasks"`
}

type KanbanColumn struct {
	Name  string `json:"name"`
	Tasks []Task `json:"tasks"`
}

type KanbanBoard struct {
	UserID  string         `json:"user_id"`
	Columns []KanbanColumn `json:"columns"`
}

type ReminderRule struct {
	ID              string    `json:"id"`
	UserID          string    `json:"user_id"`
	EntityType      string    `json:"entity_type"`
	EntityID        string    `json:"entity_id"`
	IntervalMinutes int       `json:"interval_minutes"`
	RepeatCount     int       `json:"repeat_count"`
	Active          bool      `json:"active"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

type NaggerSchedule struct {
	ID                 string    `json:"id"`
	ReminderRuleID     string    `json:"reminder_rule_id"`
	UserID             string    `json:"user_id"`
	NextRunAt          time.Time `json:"next_run_at"`
	RemainingDispatch  int       `json:"remaining_dispatch"`
	Status             string    `json:"status"`
	LastNotificationID string    `json:"last_notification_id,omitempty"`
	CreatedAt          time.Time `json:"created_at"`
	UpdatedAt          time.Time `json:"updated_at"`
}

type NotificationLog struct {
	ID             string    `json:"id"`
	UserID         string    `json:"user_id"`
	ScheduleID     string    `json:"schedule_id"`
	EntityType     string    `json:"entity_type"`
	EntityID       string    `json:"entity_id"`
	Channel        string    `json:"channel"`
	IdempotencyKey string    `json:"idempotency_key"`
	Status         string    `json:"status"`
	CreatedAt      time.Time `json:"created_at"`
}

// Friend represents a friendship relationship between two users
type Friend struct {
	ID         string    `json:"id"`
	UserID     string    `json:"user_id"`     // User who initiated
	FriendID   string    `json:"friend_id"`   // User who was added
	Status     string    `json:"status"`      // pending, accepted, rejected
	CreatedAt  time.Time `json:"created_at"`
	AcceptedAt *time.Time `json:"accepted_at,omitempty"`
}

// SharedBoard represents a Kanban board shared among friends
type SharedBoard struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	OwnerID     string    `json:"owner_id"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// BoardMember represents users who have access to a shared board
type BoardMember struct {
	ID        string    `json:"id"`
	BoardID   string    `json:"board_id"`
	UserID    string    `json:"user_id"`
	Role      string    `json:"role"` // owner, editor, viewer
	CreatedAt time.Time `json:"created_at"`
}

// PushSubscription stores Web Push API subscription data
type PushSubscription struct {
	ID       string    `json:"id"`
	UserID   string    `json:"user_id"`
	Endpoint string    `json:"endpoint"`
	P256dh   string    `json:"p256dh"`   // Public key
	Auth     string    `json:"auth"`     // Auth secret
	CreatedAt time.Time `json:"created_at"`
}
