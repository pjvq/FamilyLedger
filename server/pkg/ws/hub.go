package ws

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"

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

	// Default max connections per user.
	defaultMaxConnsPerUser = 5
)

// allowedOrigins is parsed once at init from ALLOWED_ORIGINS env var.
// NOTE: kept at package level for websocket.Upgrader.CheckOrigin function signature.
// Hub.NewHub() does NOT re-parse; these are immutable for process lifetime.
var (
	allowedOrigins  map[string]struct{}
	allowAllOrigins bool
	isProduction    bool
)

func init() {
	isProduction = os.Getenv("APP_ENV") == "production"
	raw := os.Getenv("ALLOWED_ORIGINS")
	if raw == "" || raw == "*" {
		allowAllOrigins = true
		if isProduction {
			log.Printf("ws: WARNING: ALLOWED_ORIGINS not set in production — connections will be rejected")
		}
		return
	}
	allowedOrigins = make(map[string]struct{})
	for _, o := range strings.Split(raw, ",") {
		if trimmed := strings.TrimSpace(o); trimmed != "" {
			allowedOrigins[trimmed] = struct{}{}
		}
	}
	log.Printf("ws: allowed origins: %d entries", len(allowedOrigins))
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin:     checkOrigin,
}

// checkOrigin validates the request origin against the pre-parsed allowedOrigins set.
func checkOrigin(r *http.Request) bool {
	if allowAllOrigins {
		if isProduction {
			log.Printf("ws: WARNING: ALLOWED_ORIGINS not set in production, rejecting connection")
			return false
		}
		return true
	}
	origin := r.Header.Get("Origin")
	if _, ok := allowedOrigins[origin]; ok {
		return true
	}
	log.Printf("ws: rejected origin %q", origin)
	return false
}

// HubConfig holds configurable timeouts for the Hub.
type HubConfig struct {
	WriteWait          time.Duration
	PongWait           time.Duration
	PingPeriod         time.Duration
	TokenCheckInterval time.Duration // 0 = disabled (default); >0 = periodic JWT re-verification
	AuthTimeout        time.Duration // Time allowed for first-message auth after upgrade (default 5s)
	MaxConnsPerUser    int           // Max concurrent WebSocket connections per user (default 5, 0 = unlimited)
}

// DefaultHubConfig returns production defaults.
func DefaultHubConfig() HubConfig {
	return HubConfig{
		WriteWait:          writeWait,
		PongWait:           pongWait,
		PingPeriod:         pingPeriod,
		TokenCheckInterval: 0, // disabled by default; enable in tests or prod as needed
		AuthTimeout:        defaultAuthTimeout,
		MaxConnsPerUser:    defaultMaxConnsPerUser,
	}
}

// Hub manages all WebSocket connections.
type Hub struct {
	mu         sync.RWMutex
	clients    map[string]map[*Client]bool // userID -> clients
	jwtManager *jwtpkg.Manager
	config     HubConfig
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
		log.Fatalf("ws: PingPeriod (%v) must be < PongWait (%v)", cfg.PingPeriod, cfg.PongWait)
	}
	if cfg.AuthTimeout == 0 {
		cfg.AuthTimeout = defaultAuthTimeout
	}
	if cfg.MaxConnsPerUser == 0 {
		cfg.MaxConnsPerUser = defaultMaxConnsPerUser
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
//     This mode logs a deprecation warning and will be removed in a future version.
func (h *Hub) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")

	if token != "" {
		// Legacy query-string auth (deprecated)
		log.Printf("ws: DEPRECATED: token passed via query string — migrate to first-message auth")
		claims, err := h.jwtManager.Verify(token)
		if err != nil {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}
		h.upgradeAndRegister(w, r, claims.UserID, token)
		return
	}

	// First-message auth: upgrade first, then wait for auth message
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("ws: upgrade error: %v", err)
		return
	}

	// Set a deadline for the auth message
	conn.SetReadDeadline(time.Now().Add(h.config.AuthTimeout))
	_, msg, err := conn.ReadMessage()
	if err != nil {
		log.Printf("ws: auth timeout or read error: %v", err)
		conn.WriteControl(
			websocket.CloseMessage,
			websocket.FormatCloseMessage(4002, "auth timeout"),
			time.Now().Add(h.config.WriteWait),
		)
		conn.Close()
		return
	}

	var authMsg authMessage
	if err := json.Unmarshal(msg, &authMsg); err != nil || authMsg.Type != "auth" || authMsg.Token == "" {
		log.Printf("ws: invalid auth message")
		conn.WriteControl(
			websocket.CloseMessage,
			websocket.FormatCloseMessage(4003, "invalid auth message"),
			time.Now().Add(h.config.WriteWait),
		)
		conn.Close()
		return
	}

	claims, err := h.jwtManager.Verify(authMsg.Token)
	if err != nil {
		log.Printf("ws: auth failed: invalid token")
		conn.WriteControl(
			websocket.CloseMessage,
			websocket.FormatCloseMessage(4004, "invalid token"),
			time.Now().Add(h.config.WriteWait),
		)
		conn.Close()
		return
	}

	// Check max connections before sending auth_ok
	if h.config.MaxConnsPerUser > 0 {
		h.mu.RLock()
		count := len(h.clients[claims.UserID])
		h.mu.RUnlock()
		if count >= h.config.MaxConnsPerUser {
			log.Printf("ws: max connections (%d) exceeded for user %s", h.config.MaxConnsPerUser, claims.UserID)
			conn.WriteControl(
				websocket.CloseMessage,
				websocket.FormatCloseMessage(4005, "max connections exceeded"),
				time.Now().Add(h.config.WriteWait),
			)
			conn.Close()
			return
		}
	}

	// Send auth_ok before registering (so client knows auth succeeded)
	authOK, _ := json.Marshal(map[string]string{"type": "auth_ok"})
	conn.SetWriteDeadline(time.Now().Add(h.config.WriteWait))
	if err := conn.WriteMessage(websocket.TextMessage, authOK); err != nil {
		log.Printf("ws: failed to send auth_ok: %v", err)
		conn.Close()
		return
	}

	client := &Client{
		conn:   conn,
		userID: claims.UserID,
		token:  authMsg.Token,
		send:   make(chan []byte, 256),
		done:   make(chan struct{}),
		hub:    h,
	}

	h.register(client)

	go client.writePump()
	go client.readPump(h)
}

func (h *Hub) upgradeAndRegister(w http.ResponseWriter, r *http.Request, userID string, token string) {
	// Check max connections before upgrading
	if h.config.MaxConnsPerUser > 0 {
		h.mu.RLock()
		count := len(h.clients[userID])
		h.mu.RUnlock()
		if count >= h.config.MaxConnsPerUser {
			log.Printf("ws: max connections (%d) exceeded for user %s", h.config.MaxConnsPerUser, userID)
			http.Error(w, "max connections exceeded", http.StatusTooManyRequests)
			return
		}
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("websocket upgrade error: %v", err)
		return
	}

	client := &Client{
		conn:   conn,
		userID: userID,
		token:  token,
		send:   make(chan []byte, 256),
		done:   make(chan struct{}),
		hub:    h,
	}

	h.register(client)

	go client.writePump()
	go client.readPump(h)
}

func (h *Hub) register(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if h.clients[client.userID] == nil {
		h.clients[client.userID] = make(map[*Client]bool)
	}
	h.clients[client.userID][client] = true
	log.Printf("ws: client connected for user %s (total: %d)", client.userID, len(h.clients[client.userID]))
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
		log.Printf("ws: client disconnected for user %s", client.userID)
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
				// Hub closed the channel.
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				log.Printf("ws: write error: %v", err)
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
				log.Printf("ws: heartbeat write error: %v", err)
				return
			}
			// Also send protocol-level ping for connection keepalive
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				log.Printf("ws: ping error: %v", err)
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
				log.Printf("ws: read error: %v", err)
			}
			return
		}
		// For now, we just keep the connection alive by reading.
		// Client messages can be handled here in the future.
	}
}

// tokenCheckLoop periodically re-verifies the client's JWT token.
// If the token has expired, it sends a close frame (4001 = token expired) and unregisters.
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
				log.Printf("ws: token expired for user %s, disconnecting", c.userID)
				// Send close frame with custom code 4001 (token expired)
				c.conn.WriteControl(
					websocket.CloseMessage,
					websocket.FormatCloseMessage(4001, "token expired"),
					time.Now().Add(c.hub.config.WriteWait),
				)
				h.unregister(c) // explicit cleanup (sync.Once makes this safe even if readPump also calls it)
				// Force close the connection so readPump and writePump exit
				c.conn.Close()
				return
			}
		}
	}
}
