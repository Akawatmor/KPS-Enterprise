package httpapi

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type Metrics struct {
	registry            *prometheus.Registry
	httpRequests        *prometheus.CounterVec
	httpRequestDuration *prometheus.HistogramVec
	authAttempts        *prometheus.CounterVec
	taskMutations       *prometheus.CounterVec
	readyzChecks        *prometheus.CounterVec
}

func NewMetrics() *Metrics {
	registry := prometheus.NewRegistry()

	metrics := &Metrics{
		registry: registry,
		httpRequests: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: "todoapp",
				Name:      "http_requests_total",
				Help:      "Total number of HTTP requests handled by the backend.",
			},
			[]string{"method", "route", "status_class"},
		),
		httpRequestDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Namespace: "todoapp",
				Name:      "http_request_duration_seconds",
				Help:      "Latency of HTTP requests handled by the backend.",
				Buckets:   []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5},
			},
			[]string{"method", "route", "status_class"},
		),
		authAttempts: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: "todoapp",
				Name:      "auth_attempts_total",
				Help:      "Authentication attempts grouped by operation and result.",
			},
			[]string{"operation", "result"},
		),
		taskMutations: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: "todoapp",
				Name:      "task_mutations_total",
				Help:      "Task create/update/delete operations grouped by result.",
			},
			[]string{"operation", "result"},
		),
		readyzChecks: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: "todoapp",
				Name:      "readyz_checks_total",
				Help:      "Readiness probe checks grouped by result.",
			},
			[]string{"result"},
		),
	}

	registry.MustRegister(
		collectors.NewGoCollector(),
		collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}),
		metrics.httpRequests,
		metrics.httpRequestDuration,
		metrics.authAttempts,
		metrics.taskMutations,
		metrics.readyzChecks,
	)

	return metrics
}

func (m *Metrics) Handler() http.Handler {
	return promhttp.HandlerFor(m.registry, promhttp.HandlerOpts{})
}

func (m *Metrics) Instrument(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/metrics" {
			next.ServeHTTP(w, r)
			return
		}

		startedAt := time.Now()
		recorder := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(recorder, r)

		route := strings.TrimSpace(r.Pattern)
		if route == "" {
			route = r.URL.Path
		}

		statusClass := statusClassFor(recorder.statusCode)
		m.httpRequests.WithLabelValues(r.Method, route, statusClass).Inc()
		m.httpRequestDuration.WithLabelValues(r.Method, route, statusClass).Observe(time.Since(startedAt).Seconds())
	})
}

func (m *Metrics) RecordAuthAttempt(operation string, err error) {
	m.authAttempts.WithLabelValues(operation, resultLabel(err)).Inc()
}

func (m *Metrics) RecordTaskMutation(operation string, err error) {
	m.taskMutations.WithLabelValues(operation, resultLabel(err)).Inc()
}

func (m *Metrics) RecordReadyz(err error) {
	m.readyzChecks.WithLabelValues(resultLabel(err)).Inc()
}

func resultLabel(err error) string {
	if err != nil {
		return "error"
	}
	return "success"
}

func statusClassFor(statusCode int) string {
	return strconv.Itoa(statusCode/100) + "xx"
}

type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (r *statusRecorder) WriteHeader(statusCode int) {
	r.statusCode = statusCode
	r.ResponseWriter.WriteHeader(statusCode)
}
