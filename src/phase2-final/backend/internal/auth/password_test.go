package auth

import (
	"context"
	"errors"
	"testing"
)

func TestGitHubProvider_ExchangeCode(t *testing.T) {
	provider := NewGitHubProvider()
	if provider.Name() != "github" {
		t.Fatalf("Name() = %q, want github", provider.Name())
	}

	profile, err := provider.ExchangeCode(context.Background(), "  demo-code  ")
	if err != nil {
		t.Fatalf("ExchangeCode error: %v", err)
	}
	if profile.ExternalUserID == "" {
		t.Fatal("ExternalUserID should not be empty")
	}
	if profile.Email == "" {
		t.Fatal("Email should not be empty")
	}
	if profile.DisplayName == "" {
		t.Fatal("DisplayName should not be empty")
	}
}

func TestGitHubProvider_ExchangeCode_RequiresCode(t *testing.T) {
	_, err := NewGitHubProvider().ExchangeCode(context.Background(), "   ")
	if err == nil {
		t.Fatal("expected error for empty oauth code")
	}
}

func TestValidatePassword(t *testing.T) {
	tests := []struct {
		name     string
		password string
		wantErr  error
	}{
		{name: "too short", password: "Aa1!", wantErr: ErrPasswordTooShort},
		{name: "missing special", password: "Strong123", wantErr: ErrPasswordTooWeak},
		{name: "strong", password: "Str0ng!Pass"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidatePassword(tt.password)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("ValidatePassword(%q) error = %v, want %v", tt.password, err, tt.wantErr)
			}
		})
	}
}

func TestHashAndComparePassword(t *testing.T) {
	password := "Str0ng!Pass"
	hash, err := HashPassword(password)
	if err != nil {
		t.Fatalf("HashPassword error: %v", err)
	}
	if hash == password {
		t.Fatal("hash should differ from plain password")
	}
	if err := ComparePassword(hash, password); err != nil {
		t.Fatalf("ComparePassword(valid) error: %v", err)
	}
	if err := ComparePassword(hash, "Wr0ng!Pass"); err == nil {
		t.Fatal("expected compare error for wrong password")
	}
}

func TestValidateEmail(t *testing.T) {
	if err := ValidateEmail("person@example.com"); err != nil {
		t.Fatalf("ValidateEmail(valid) error: %v", err)
	}
	if err := ValidateEmail("not-an-email"); !errors.Is(err, ErrInvalidEmail) {
		t.Fatalf("ValidateEmail(invalid) error = %v, want %v", err, ErrInvalidEmail)
	}
}