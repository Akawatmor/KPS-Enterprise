package auth

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
)

type GitHubProvider struct{}

func NewGitHubProvider() *GitHubProvider { return &GitHubProvider{} }

func (p *GitHubProvider) Name() string { return "github" }

func (p *GitHubProvider) ExchangeCode(_ context.Context, code string) (Profile, error) {
	cleaned := strings.TrimSpace(code)
	if cleaned == "" {
		return Profile{}, fmt.Errorf("oauth code is required")
	}
	hash := sha256.Sum256([]byte(cleaned))
	external := hex.EncodeToString(hash[:])
	short := external[:10]
	return Profile{
		ExternalUserID: external,
		Email:          fmt.Sprintf("%s@users.noreply.github.com", short),
		DisplayName:    fmt.Sprintf("github_%s", short),
	}, nil
}
