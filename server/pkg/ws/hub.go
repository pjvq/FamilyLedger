package ws

import (
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"

	"github.com/familyledger/server/pkg/logger"
	jwtpkg "github.com/familyledger/server/pkg/jwt"
)

const (
	// Default time allowed to write a message to the peer.
	writeWait = 10 * time.Second

	// Default time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second

	// Default ping period. Must be less than pongWait.
	pingPeriod = 30 * time.Second

	// Maximum message size allowed from peer.
	maxMessageSize = 512

	// Default auth timeout: how long a newly connected client has to authenticate.
	defaultAuthTimeout = 5 * time.Second

	// Default max connections per user. -1 means unlimited.
	defaultMaxConnsPerUser = 5

	// Default max pending auth connections (anti-slowloris).
	defaultMaxPendingAuth = 100
)

// Pre-marshaled messages to avoid repeated json.Marshal in hot paths.
var authOKMsg = []byte(`{"type":"auth_ok"}`)

// allowedOrigins is parsed once at init from ALLOWED_ORIGINS env var.
var (
	allowedOrigins  map[string]struct{}
	allowAllOrigins bool
	isProduction    bool
)

func init() {
	isProduction = os.Getenv("APP_ENV") == "production"
	raw, isSet := os.LookupEnv("ALLOWED_ORIGINS")
	if !isSet || raw == "" {
		// Not set or explicitly empty:
		// - Production: secure-by-default — reject browser origins, allow mobile (no Origin).
		// - Development: allow all origins for convenience.
		if isProduction {
			logger.Warnf("ws: ALLOWED_ORIGINS not set in production - browser origins will be rejected, mobile (no Origin) allowed")
		} else {
			allowAllOrigins = true
			logger.Warnf("ws: ALLOWED_ORIGINS not set (non-production) - allowing all origins")
		}
		return
	}
	if raw == "*" {
		allowAllOrigins = true
		logger.Infof("ws: ALLOWED_ORIGINS=* - explicitly allowing all origins")
		return
	}
	allowedOrigins = make(map[string]struct{})
	for _, o := range strings.Split(raw, ",") {
		if trimmed := strings.TrimSpace(o); trimmed != "" {
			allowedOrigins[trimmed] = struct{}{}
		}
	}
	logger.Infof("ws: allowed origins: %d entries", len(allowedOrigins))
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin:     checkOrigin,
}

// checkOrigin validates the request origin against the pre-parsed allowedOrigins set.
func checkOrigin(r *http.Request) bool {
	origin := r.Header.Get("Origin")

	// Mobile apps don't send Origin header - always allow
	if origin == "" {
		return true
	}

	// Explicit wildcard (*) - allow all origins
	if allowAllOrigins {
		return true
	}

	// Whitelist check
	if _, ok := allowedOrigins[origin]; ok {
		return true
	}

	logger.Warnf("ws: rejected origin %q", origin)
	return false
}

// HubConfig holds configurable timeouts for the Hub.
type HubConfig struct {
	WriteWait          time.Duration
	PongWait           time.Duration
	PingPeriod         time.Duration
	TokenCheckInterval time.Duration // 0 = disabled (default); >0 = periodic JWT re-verification
	AuthTimeout        time.Duration // Time allowed for first-message auth after upgrade (default 5s)
	MaxConnsPerUser    int           // Max concurrent WebSocket connections per user (default 5, -1 = unlimited)
	MaxPendingAuth     int           // Max connections in auth-pending state (anti-slowloris, default 100, -1 = unlimited)
}

// DefaultHubConfig returns production defaults.
func DefaultHubConfig() HubConfig {
	return HubConfig{
		WriteWait:          writeWait,
		PongWait:           pongWait,
		PingPeriod:         pingPeriod,
		TokenCheckInterval: 0, // disabled by default
		AuthTimeout:        defaultAuthTimeout,
		MaxConnsPerUser:    defaultMaxConnsPerUser,
		MaxPendingAuth:     defaultMaxPendingAuth,
	}
}

// Hub manages all WebSocket connections.
type Hub struct {
	mu          sync.RWMutex
	clients     map[string]map[*Client]bool // userID -> clients
	jwtManager  *jwtpkg.Manager
	config      HubConfig
	pendingAuth atomic.Int64 // number of connections waiting for auth
}

type Client struct {
	conn   *websocket.Conn
	userID string
	token  string     // original JWT — for periodic re-verification
	send   chan []byte
	done   chan struct{} // closed when client is unregistered
	once   sync.Once    // ensures unregister logic runs only once
	hub    *Hub         // back-reference for config access
}

type ChangeNotification struct {
	EntityType string `json:"entity_type"`
	EntityID   string `json:"entity_id"`
	OpType     string `json:"op_type"`
	UserID     string `json:"user_id"`
}

// authMessage is the expected first message from a client using first-message auth.
type authMessage struct {
	Type  string `json:"type"`
	Token string `json:"token"`
}

func NewHub(jwtManager *jwtpkg.Manager, configs ...HubConfig) *Hub {
	cfg := DefaultHubConfig()
	if len(configs) > 0 {
		cfg = configs[0]
	}
	if cfg.PingPeriod >= cfg.PongWait {
		logger.Fatalf("ws: PingPeriod (%v) must be < PongWait (%v)", cfg.PingPeriod, cfg.PongWait)
	}
	if cfg.AuthTimeout == 0 {
		cfg.AuthTimeout = defaultAuthTimeout
	}
	// MaxConnsPerUser: 0 means "use default", -1 means unlimited
	if cfg.MaxConnsPerUser == 0 {
		cfg.MaxConnsPerUser = defaultMaxConnsPerUser
	}
	if cfg.MaxPendingAuth == 0 {
		cfg.MaxPendingAuth = defaultMaxPendingAuth
	}
	return &Hub{
		clients:    make(map[string]map[*Client]bool),
		jwtManager: jwtManager,
		config:     cfg,
	}
}

// HandleWebSocket handles WebSocket upgrade and authentication.
//
// Supports two auth modes:
//  1. First-message auth (preferred): connect without token in URL, then send
//     {"type":"auth","token":"<jwt>"} as the first message within AuthTimeout.
//  2. Query-string auth (deprecated): pass ?token=<jwt> in the URL.
func (h *Hub) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	clientAddr := r.RemoteAddr

	token := r.URL.Query().Get("token")
	if token != "" {
		// Legacy query-string auth (deprecated)
		logger.Warnf("ws: DEPRECATED: token passed via query string from %s — migrate to first-message auth", clientAddr)
		claims, err := h.jwtManager.Verify(token)
		if err != nil {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}
		if !h.registerIfAllowed(w, r, claims.UserID, token, clientAddr) {
			return // registerIfAllowed already wrote HTTP error
		}
		return
	}

	// Anti-slowloris: atomically increment pending count, reject if over limit
	if h.config.MaxPendingAuth > 0 {
		newCount := h.pendingAuth.Add(1)
		if newCount > int64(h.config.MaxPendingAuth) {
			h.pendingAuth.Add(-1)
			logger.Warnf("ws: max pending auth connections exceeded, rejecting %s", clientAddr)
			http.Error(w, "too many pending connections", http.StatusServiceUnavailable)
			return
		}
	} else {
		h.pendingAuth.Add(1)
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		h.pendingAuth.Add(-1) // release the slot we reserved
		logger.Errorf("ws: upgrade error from %s: %v", clientAddr, err)
		return
	}

	// Run auth handshake in a separate goroutine to not block HTTP handler
	go h.handleFirstMessageAuth(conn, clientAddr)
}

// handleFirstMessageAuth waits for the auth message and registers the client.
func (h *Hub) handleFirstMessageAuth(conn *websocket.Conn, clientAddr string) {
	defer h.pendingAuth.Add(-1)

	// Set read limit for auth phase (prevent oversized auth messages)
	conn.SetReadLimit(maxMessageSize)

	// Set a deadline for the auth message
	conn.SetReadDeadline(time.Now().Add(h.config.AuthTimeout))
	_, msg, err := conn.ReadMessage()
	if err != nil {
		logger.Warnf("ws: auth timeout or read error from %s: %v", clientAddr, err)
		if wErr := conn.WriteControl(
			websocket.CloseMessage,
			websocket.FormatCloseMessage(4002, "auth timeout"),
			time.Now().Add(h.config.WriteWait),
		); wErr != nil {
			logger.Errorf("ws: failed to send close 4002 to %s: %v", clientAddr, wErr)
		}
		conn.Close()
		return
	}

	var authMsg authMessage
	if err := json.Unmarshal(msg, &authMsg); err != nil || authMsg.Type != "auth" || authMsg.Token == "" {
		logger.Warnf("ws: invalid auth message from %s", clientAddr)
		if wErr := conn.WriteControl(
			websocket.CloseMessage,
			websocket.FormatCloseMessage(4003, "invalid auth message"),
			time.Now().Add(h.config.WriteWait),
		); wErr != nil {
			logger.Errorf("ws: failed to send close 4003 to %s: %v", clientAddr, wErr)
		}
		conn.Close()
		return
	}

	claims, err := h.jwtManager.Verify(authMsg.Token)
	if err != nil {
		logger.Warnf("ws: auth failed from %s: invalid token", clientAddr)
		if wErr := conn.WriteControl(
			websocket.CloseMessage,
			websocket.FormatCloseMessage(4004, "invalid token"),
			time.Now().Add(h.config.WriteWait),
		); wErr != nil {
			logger.Errorf("ws: failed to send close 4004 to %s: %v", clientAddr, wErr)
		}
		conn.Close()
		return
	}

	// Atomically check max connections and register
	client := &Client{
		conn:   conn,
		userID: claims.UserID,
		token:  authMsg.Token,
		send:   make(chan []byte, 256),
		done:   make(chan struct{}),
		hub:    h,
	}

	if !h.registerAtomic(client, clientAddr) {
		// Max connections exceeded — registerAtomic already sent close frame
		return
	}

	// Send auth_ok AFTER register (so client won't miss broadcasts)
	conn.SetWriteDeadline(time.Now().Add(h.config.WriteWait))
	if err := conn.WriteMessage(websocket.TextMessage, authOKMsg); err != nil {
		logger.Errorf("ws: failed to send auth_ok to %s: %v", clientAddr, err)
		h.unregister(client)
		return
	}

	// Clear read deadline before entering readPump
	conn.SetReadDeadline(time.Time{})

	go client.writePump()
	go client.readPump(h)
}

// registerIfAllowed handles legacy (query-string) auth: upgrades + registers atomically.
func (h *Hub) registerIfAllowed(w http.ResponseWriter, r *http.Request, userID, token, clientAddr string) bool {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		logger.Errorf("ws: upgrade error from %s: %v", clientAddr, err)
		return false
	}

	client := &Client{
		conn:   conn,
		userID: userID,
		token:  token,
		send:   make(chan []byte, 256),
		done:   make(chan struct{}),
		hub:    h,
	}

	if !h.registerAtomic(client, clientAddr) {
		// registerAtomic sends close 4005 and closes conn
		return false
	}

	go client.writePump()
	go client.readPump(h)
	return true
}

// registerAtomic checks max connections and registers the client atomically.
// Returns false if max connections exceeded (sends close frame and closes conn).
func (h *Hub) registerAtomic(client *Client, clientAddr string) bool {
	h.mu.Lock()

	if h.config.MaxConnsPerUser > 0 {
		if len(h.clients[client.userID]) >= h.config.MaxConnsPerUser {
			h.mu.Unlock()
			// Network I/O outside lock to prevent Hub deadlock
			logger.Warnf("ws: max connections (%d) exceeded for user %s from %s", h.config.MaxConnsPerUser, client.userID, clientAddr)
			if wErr := client.conn.WriteControl(
				websocket.CloseMessage,
				websocket.FormatCloseMessage(4005, "max connections exceeded"),
				time.Now().Add(h.config.WriteWait),
			); wErr != nil {
				logger.Errorf("ws: failed to send close 4005 to %s: %v", clientAddr, wErr)
			}
			client.conn.Close()
			return false
		}
	}

	if h.clients[client.userID] == nil {
		h.clients[client.userID] = make(map[*Client]bool)
	}
	h.clients[client.userID][client] = true
	logger.Infof("ws: client connected for user %s from %s (total: %d)", client.userID, clientAddr, len(h.clients[client.userID]))
	h.mu.Unlock()
	return true
}

func (h *Hub) register(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if h.clients[client.userID] == nil {
		h.clients[client.userID] = make(map[*Client]bool)
	}
	h.clients[client.userID][client] = true
	logger.Infof("ws: client connected for user %s (total: %d)", client.userID, len(h.clients[client.userID]))
}

func (h *Hub) unregister(client *Client) {
	client.once.Do(func() {
		h.mu.Lock()
		defer h.mu.Unlock()

		if clients, ok := h.clients[client.userID]; ok {
			delete(clients, client)
			if len(clients) == 0 {
				delete(h.clients, client.userID)
			}
		}
		close(client.done)
		close(client.send)
		client.conn.Close()
		logger.Infof("ws: client disconnected for user %s", client.userID)
	})
}

// ConnectedUsers returns the number of unique users with active connections.
func (h *Hub) ConnectedUsers() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

// TotalConnections returns the total number of active WebSocket connections.
func (h *Hub) TotalConnections() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	total := 0
	for _, clients := range h.clients {
		total += len(clients)
	}
	return total
}

// PendingAuthConnections returns the number of connections waiting for auth.
func (h *Hub) PendingAuthConnections() int64 {
	return h.pendingAuth.Load()
}

// BroadcastToUser sends a message to all connections of a specific user.
func (h *Hub) BroadcastToUser(userID string, message []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	if clients, ok := h.clients[userID]; ok {
		for client := range clients {
			select {
			case client.send <- message:
			default:
				// Buffer full, skip
			}
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(c.hub.config.PingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(c.hub.config.WriteWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				logger.Errorf("ws: write error: %v", err)
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(c.hub.config.WriteWait))
			// Send application-level heartbeat with server timestamp (watermark)
			hb, _ := json.Marshal(map[string]interface{}{
				"type":        "heartbeat",
				"server_time": time.Now().UnixMilli(),
			})
			if err := c.conn.WriteMessage(websocket.TextMessage, hb); err != nil {
				logger.Errorf("ws: heartbeat write error: %v", err)
				return
			}
			// Also send protocol-level ping for connection keepalive
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				logger.Errorf("ws: ping error: %v", err)
				return
			}
		}
	}
}

func (c *Client) readPump(h *Hub) {
	defer h.unregister(c)

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(c.hub.config.PongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(c.hub.config.PongWait))
		return nil
	})

	// If token check is enabled, run a goroutine that periodically verifies the JWT.
	if c.hub.config.TokenCheckInterval > 0 {
		go c.tokenCheckLoop(h)
	}

	for {
		_, _, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				logger.Errorf("ws: read error: %v", err)
			}
			return
		}
	}
}

// tokenCheckLoop periodically re-verifies the client's JWT token.
func (c *Client) tokenCheckLoop(h *Hub) {
	ticker := time.NewTicker(c.hub.config.TokenCheckInterval)
	defer ticker.Stop()

	for {
		select {
		case <-c.done:
			return
		case <-ticker.C:
			_, err := h.jwtManager.Verify(c.token)
			if err != nil {
				logger.Infof("ws: token expired for user %s, disconnecting", c.userID)
				if wErr := c.conn.WriteControl(
					websocket.CloseMessage,
					websocket.FormatCloseMessage(4001, "token expired"),
					time.Now().Add(c.hub.config.WriteWait),
				); wErr != nil {
					logger.Errorf("ws: failed to send close 4001: %v", wErr)
				}
				h.unregister(c)
				c.conn.Close()
				return
			}
		}
	}
}
