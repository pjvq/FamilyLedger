package ws

import (
	"encoding/json"
	"log"
	"net/http"
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
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins in dev
	},
}

// HubConfig holds configurable timeouts for the Hub.
type HubConfig struct {
	WriteWait          time.Duration
	PongWait           time.Duration
	PingPeriod         time.Duration
	TokenCheckInterval time.Duration // 0 = disabled (default); >0 = periodic JWT re-verification
}

// DefaultHubConfig returns production defaults.
func DefaultHubConfig() HubConfig {
	return HubConfig{
		WriteWait:          writeWait,
		PongWait:           pongWait,
		PingPeriod:         pingPeriod,
		TokenCheckInterval: 0, // disabled by default; enable in tests or prod as needed
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
	token  string    // original JWT — for periodic re-verification
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

func NewHub(jwtManager *jwtpkg.Manager, configs ...HubConfig) *Hub {
	cfg := DefaultHubConfig()
	if len(configs) > 0 {
		cfg = configs[0]
	}
	if cfg.PingPeriod >= cfg.PongWait {
		log.Fatalf("ws: PingPeriod (%v) must be < PongWait (%v)", cfg.PingPeriod, cfg.PongWait)
	}
	return &Hub{
		clients:    make(map[string]map[*Client]bool),
		jwtManager: jwtManager,
		config:     cfg,
	}
}

func (h *Hub) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	// Authenticate via JWT token query param
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "missing token", http.StatusUnauthorized)
		return
	}

	claims, err := h.jwtManager.Verify(token)
	if err != nil {
		http.Error(w, "invalid token", http.StatusUnauthorized)
		return
	}

	h.upgradeAndRegister(w, r, claims.UserID, token)
}

func (h *Hub) upgradeAndRegister(w http.ResponseWriter, r *http.Request, userID string, token string) {

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
	log.Printf("ws: client connected for user %s", client.userID)
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
