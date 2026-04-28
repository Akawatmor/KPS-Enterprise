package auth

import "context"

type Profile struct {
	ExternalUserID string
	Email          string
	DisplayName    string
}

type Provider interface {
	Name() string
	ExchangeCode(ctx context.Context, code string) (Profile, error)
}
