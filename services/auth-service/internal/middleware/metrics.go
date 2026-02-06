package middleware

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// HTTP Metrics
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "path", "status"},
	)

	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path"},
	)

	httpRequestSize = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_size_bytes",
			Help:    "HTTP request size in bytes",
			Buckets: prometheus.ExponentialBuckets(100, 10, 8),
		},
		[]string{"method", "path"},
	)

	httpResponseSize = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_response_size_bytes",
			Help:    "HTTP response size in bytes",
			Buckets: prometheus.ExponentialBuckets(100, 10, 8),
		},
		[]string{"method", "path"},
	)

	// WebSocket Metrics
	websocketConnections = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "websocket_active_connections",
			Help: "Number of active WebSocket connections",
		},
	)

	websocketMessagesTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "websocket_messages_total",
			Help: "Total number of WebSocket messages",
		},
		[]string{"direction", "type"},
	)

	// Authentication Metrics
	authLoginTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "auth_login_total",
			Help: "Total number of login attempts",
		},
		[]string{"status"},
	)

	authLoginFailures = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "auth_login_failures_total",
			Help: "Total number of failed login attempts",
		},
		[]string{"reason"},
	)

	authTokenValidations = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "auth_token_validations_total",
			Help: "Total number of token validations",
		},
		[]string{"status"},
	)

	// Database Metrics
	dbQueryDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "db_query_duration_seconds",
			Help:    "Database query duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"operation", "table"},
	)

	dbConnectionsActive = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "db_connections_active",
			Help: "Number of active database connections",
		},
	)

	// Rate Limiting Metrics
	rateLimitedRequests = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_rate_limited_total",
			Help: "Total number of rate-limited requests",
		},
		[]string{"path"},
	)

	// Business Metrics
	messagesTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "chat_messages_total",
			Help: "Total number of chat messages",
		},
		[]string{"room_type", "message_type"},
	)

	activeRooms = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "chat_active_rooms",
			Help: "Number of active chat rooms",
		},
	)

	activeUsers = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "chat_active_users",
			Help: "Number of active users",
		},
	)

	callsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "webrtc_calls_total",
			Help: "Total number of WebRTC calls",
		},
		[]string{"type", "status"},
	)

	callDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "webrtc_call_duration_seconds",
			Help:    "WebRTC call duration in seconds",
			Buckets: []float64{10, 30, 60, 120, 300, 600, 1800, 3600},
		},
		[]string{"type"},
	)
)

// PrometheusMiddleware returns a Gin middleware for Prometheus metrics
func PrometheusMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Skip metrics endpoint
		if c.Request.URL.Path == "/metrics" {
			c.Next()
			return
		}

		start := time.Now()
		requestSize := c.Request.ContentLength
		if requestSize < 0 {
			requestSize = 0
		}

		// Process request
		c.Next()

		// Record metrics
		duration := time.Since(start).Seconds()
		status := strconv.Itoa(c.Writer.Status())
		path := c.FullPath()
		if path == "" {
			path = "unknown"
		}

		httpRequestsTotal.WithLabelValues(c.Request.Method, path, status).Inc()
		httpRequestDuration.WithLabelValues(c.Request.Method, path).Observe(duration)
		httpRequestSize.WithLabelValues(c.Request.Method, path).Observe(float64(requestSize))
		httpResponseSize.WithLabelValues(c.Request.Method, path).Observe(float64(c.Writer.Size()))
	}
}

// ============================================================
// Metric Recording Functions
// ============================================================

// RecordLogin records a login attempt
func RecordLogin(success bool, reason string) {
	if success {
		authLoginTotal.WithLabelValues("success").Inc()
	} else {
		authLoginTotal.WithLabelValues("failure").Inc()
		authLoginFailures.WithLabelValues(reason).Inc()
	}
}

// RecordTokenValidation records a token validation
func RecordTokenValidation(valid bool) {
	if valid {
		authTokenValidations.WithLabelValues("valid").Inc()
	} else {
		authTokenValidations.WithLabelValues("invalid").Inc()
	}
}

// RecordDBQuery records a database query
func RecordDBQuery(operation, table string, duration time.Duration) {
	dbQueryDuration.WithLabelValues(operation, table).Observe(duration.Seconds())
}

// SetDBConnections sets the number of active database connections
func SetDBConnections(count int) {
	dbConnectionsActive.Set(float64(count))
}

// RecordRateLimited records a rate-limited request
func RecordRateLimited(path string) {
	rateLimitedRequests.WithLabelValues(path).Inc()
}

// ============================================================
// WebSocket Metrics
// ============================================================

// WebSocketConnected records a new WebSocket connection
func WebSocketConnected() {
	websocketConnections.Inc()
}

// WebSocketDisconnected records a WebSocket disconnection
func WebSocketDisconnected() {
	websocketConnections.Dec()
}

// RecordWebSocketMessage records a WebSocket message
func RecordWebSocketMessage(direction, msgType string) {
	websocketMessagesTotal.WithLabelValues(direction, msgType).Inc()
}

// ============================================================
// Business Metrics
// ============================================================

// RecordMessage records a chat message
func RecordMessage(roomType, messageType string) {
	messagesTotal.WithLabelValues(roomType, messageType).Inc()
}

// SetActiveRooms sets the number of active rooms
func SetActiveRooms(count int) {
	activeRooms.Set(float64(count))
}

// SetActiveUsers sets the number of active users
func SetActiveUsers(count int) {
	activeUsers.Set(float64(count))
}

// RecordCall records a WebRTC call
func RecordCall(callType, status string) {
	callsTotal.WithLabelValues(callType, status).Inc()
}

// RecordCallDuration records the duration of a WebRTC call
func RecordCallDuration(callType string, duration time.Duration) {
	callDuration.WithLabelValues(callType).Observe(duration.Seconds())
}
