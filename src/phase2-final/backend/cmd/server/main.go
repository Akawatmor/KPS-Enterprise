package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
	"github.com/KPS-Enterprise/todoapp/backend/internal/httpapi"
	"github.com/KPS-Enterprise/todoapp/backend/internal/service"
	"github.com/KPS-Enterprise/todoapp/backend/internal/store"
	"github.com/KPS-Enterprise/todoapp/backend/internal/worker"
)

func main() {
	cfg := config.Load()
	logger := log.New(os.Stdout, "", log.LstdFlags|log.LUTC)

	adapter, err := store.NewAdapter(cfg, logger)
	if err != nil {
		logger.Fatalf("storage initialization failed: %v", err)
	}
	defer func() {
		if closeErr := adapter.Close(); closeErr != nil {
			logger.Printf("storage close failed: %v", closeErr)
		}
	}()

	svc := service.New(cfg, logger, adapter)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	scheduler := worker.NewScheduler(cfg, logger, svc)
	scheduler.Run(ctx)

	srv := &http.Server{
		Addr:         ":" + cfg.ServerPort,
		Handler:      httpapi.NewMux(cfg, logger, svc),
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		<-ctx.Done()
		logger.Println("shutdown signal received")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			logger.Printf("graceful shutdown failed: %v", err)
		}
	}()

	logger.Printf("todoapp-core listening on %s", srv.Addr)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logger.Fatalf("server failed: %v", err)
	}

	logger.Println("todoapp-core stopped")
}
