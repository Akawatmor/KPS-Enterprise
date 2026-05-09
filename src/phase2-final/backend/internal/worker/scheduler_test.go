package worker

import (
	"context"
	"io"
	"log"
	"testing"
	"time"

	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
)

func TestNewScheduler(t *testing.T) {
	logger := log.New(io.Discard, "", 0)
	scheduler := NewScheduler(config.Config{NaggerTick: 25 * time.Millisecond}, logger, nil)
	if scheduler == nil {
		t.Fatal("NewScheduler returned nil")
	}
	if scheduler.naggerTick != 25*time.Millisecond {
		t.Fatalf("naggerTick = %s, want 25ms", scheduler.naggerTick)
	}
}

func TestRunStopsOnContextCancel(t *testing.T) {
	logger := log.New(io.Discard, "", 0)
	scheduler := NewScheduler(config.Config{NaggerTick: 5 * time.Millisecond}, logger, nil)
	ctx, cancel := context.WithCancel(context.Background())
	scheduler.Run(ctx)
	time.Sleep(10 * time.Millisecond)
	cancel()
	time.Sleep(10 * time.Millisecond)

	if scheduler.service != nil {
		t.Fatal("expected nil service in test scheduler")
	}
}