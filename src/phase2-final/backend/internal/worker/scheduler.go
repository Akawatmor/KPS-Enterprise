package worker

import (
	"context"
	"log"
	"time"

	"github.com/KPS-Enterprise/todoapp/backend/internal/config"
	"github.com/KPS-Enterprise/todoapp/backend/internal/service"
)

type Scheduler struct {
	logger     *log.Logger
	service    *service.Service
	naggerTick time.Duration
}

func NewScheduler(cfg config.Config, logger *log.Logger, svc *service.Service) *Scheduler {
	return &Scheduler{
		logger:     logger,
		service:    svc,
		naggerTick: cfg.NaggerTick,
	}
}

func (s *Scheduler) Run(ctx context.Context) {
	go s.runNagger(ctx)
}

func (s *Scheduler) runNagger(ctx context.Context) {
	s.logger.Printf("worker=nagger interval=%s started", s.naggerTick)
	ticker := time.NewTicker(s.naggerTick)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			s.logger.Println("worker=nagger stopped")
			return
		case <-ticker.C:
			if s.service == nil {
				continue
			}
			count, err := s.service.ProcessDueNaggerSchedules(ctx)
			if err != nil {
				s.logger.Printf("worker=nagger error: %v", err)
				continue
			}
			if count > 0 {
				s.logger.Printf("worker=nagger dispatched=%d", count)
			}
		}
	}
}
