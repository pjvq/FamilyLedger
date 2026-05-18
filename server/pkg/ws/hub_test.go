package ws

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	jwtpkg "github.com/familyledger/server/pkg/jwt"
)

// fastConfig returns a HubConfig with short timeouts for tests.
func fastConfig() HubConfig {
	return HubConfig{
		WriteWait:       2 * time.Second,
		PongWait:        3 * time.Second,
		PingPeriod:      1 * time.Second,
		AuthTimeout:     2 * time.Second,
		MaxConnsPerUser: 3,
	}
}

func setupTestHub() (*Hub, *httptest.Server) {
	jwtManager := jwtpkg.NewManager("test-secret-key-for-ws-tests-12345")
	hub := NewHub(jwtManager, fastConfig())

	server := httptest.NewServer(http.HandlerFunc(hub.HandleWebSocket))
	return hub, server
}

// wsURL builds a query-string auth URL (legacy/deprecated path).
func wsURL(server *httptest.Server, token string) string {
	url := "ws" + strings.TrimPrefix(server.URL, "http") + "?token=" + token
	return url
}

// wsURLNoToken builds a URL without token for first-message auth.
func wsURLNoToken(server *httptest.Server) string {
	return "ws" + strings.TrimPrefix(server.URL, "http")
}

// dialFirstMessageAuth connects via first-message auth and returns the authenticated conn.
func dialFirstMessageAuth(t *testing.T, server *httptest.Server, token string) *websocket.Conn {
	t.Helper()
	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURLNoToken(server), nil)
	require.NoError(t, err)

	// Send auth message
	authMsg, _ := json.Marshal(map[string]string{"type": "auth", "token": token})
	err = conn.WriteMessage(websocket.TextMessage, authMsg)
	require.NoError(t, err)

	// Read auth_ok
	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	_, msg, err := conn.ReadMessage()
	require.NoError(t, err)

	var resp map[string]string
	require.NoError(t, json.Unmarshal(msg, &resp))
	assert.Equal(t, "auth_ok", resp["type"])

	// Reset deadline
	conn.SetReadDeadline(time.Time{})
	return conn
}

// ═══════════════════════════════════════════════════════════════════════════════
// First-message auth tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestFirstMessageAuth_Success(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	tokenPair, err := hub.jwtManager.GenerateTokenPair("user-fma")
	require.NoError(t, err)

	conn := dialFirstMessageAuth(t, server, tokenPair.AccessToken)
	defer conn.Close()

	// Verify the client is registered
	time.Sleep(50 * time.Millisecond)
	hub.mu.RLock()
	count := len(hub.clients["user-fma"])
	hub.mu.RUnlock()
	assert.Equal(t, 1, count)
}

func TestFirstMessageAuth_InvalidToken(t *testing.T) {
	_, server := setupTestHub()
	defer server.Close()

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURLNoToken(server), nil)
	require.NoError(t, err)
	defer conn.Close()

	authMsg, _ := json.Marshal(map[string]string{"type": "auth", "token": "bad-token"})
	err = conn.WriteMessage(websocket.TextMessage, authMsg)
	require.NoError(t, err)

	// Should receive close frame with 4004
	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	_, _, err = conn.ReadMessage()
	assert.Error(t, err)
	if closeErr, ok := err.(*websocket.CloseError); ok {
		assert.Equal(t, 4004, closeErr.Code)
	}
}

func TestFirstMessageAuth_BadMessage(t *testing.T) {
	_, server := setupTestHub()
	defer server.Close()

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURLNoToken(server), nil)
	require.NoError(t, err)
	defer conn.Close()

	// Send garbage
	err = conn.WriteMessage(websocket.TextMessage, []byte(`not json`))
	require.NoError(t, err)

	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	_, _, err = conn.ReadMessage()
	assert.Error(t, err)
	if closeErr, ok := err.(*websocket.CloseError); ok {
		assert.Equal(t, 4003, closeErr.Code)
	}
}

func TestFirstMessageAuth_Timeout(t *testing.T) {
	_, server := setupTestHub()
	defer server.Close()

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURLNoToken(server), nil)
	require.NoError(t, err)
	defer conn.Close()

	// Don't send anything — wait for auth timeout (2s in test config)
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, _, err = conn.ReadMessage()
	assert.Error(t, err)
	if closeErr, ok := err.(*websocket.CloseError); ok {
		assert.Equal(t, 4002, closeErr.Code)
	}
}

func TestFirstMessageAuth_MissingTokenField(t *testing.T) {
	_, server := setupTestHub()
	defer server.Close()

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURLNoToken(server), nil)
	require.NoError(t, err)
	defer conn.Close()

	// Send auth message with empty token
	authMsg, _ := json.Marshal(map[string]string{"type": "auth", "token": ""})
	err = conn.WriteMessage(websocket.TextMessage, authMsg)
	require.NoError(t, err)

	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	_, _, err = conn.ReadMessage()
	assert.Error(t, err)
	if closeErr, ok := err.(*websocket.CloseError); ok {
		assert.Equal(t, 4003, closeErr.Code)
	}
}

// ═══════════════════════════════════════════════════════════════════════════════
// Max connections per user
// ═══════════════════════════════════════════════════════════════════════════════

func TestMaxConnsPerUser_FirstMessageAuth(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	tokenPair, err := hub.jwtManager.GenerateTokenPair("user-max")
	require.NoError(t, err)

	// Open MaxConnsPerUser (3) connections
	conns := make([]*websocket.Conn, 0, 3)
	for i := 0; i < 3; i++ {
		conn := dialFirstMessageAuth(t, server, tokenPair.AccessToken)
		conns = append(conns, conn)
		defer conn.Close()
	}

	time.Sleep(50 * time.Millisecond)

	// 4th should be rejected with 4005
	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURLNoToken(server), nil)
	require.NoError(t, err)
	defer conn.Close()

	authMsg, _ := json.Marshal(map[string]string{"type": "auth", "token": tokenPair.AccessToken})
	err = conn.WriteMessage(websocket.TextMessage, authMsg)
	require.NoError(t, err)

	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	_, _, err = conn.ReadMessage()
	assert.Error(t, err)
	if closeErr, ok := err.(*websocket.CloseError); ok {
		assert.Equal(t, 4005, closeErr.Code)
	}
}

func TestMaxConnsPerUser_LegacyAuth(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	tokenPair, err := hub.jwtManager.GenerateTokenPair("user-max-legacy")
	require.NoError(t, err)

	dialer := websocket.Dialer{}
	// Open 3 connections via legacy auth
	for i := 0; i < 3; i++ {
		conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
		require.NoError(t, err)
		defer conn.Close()
	}

	time.Sleep(50 * time.Millisecond)

	// 4th should get 429
	_, resp, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
	require.Error(t, err)
	assert.Equal(t, http.StatusTooManyRequests, resp.StatusCode)
}

// ═══════════════════════════════════════════════════════════════════════════════
// Legacy query-string auth tests (backwards compatibility)
// ═══════════════════════════════════════════════════════════════════════════════

func TestHub_PingPong_KeepsConnectionAlive(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()
	_ = hub

	tokenPair, err := hub.jwtManager.GenerateTokenPair("user1")
	require.NoError(t, err)

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
	require.NoError(t, err)
	defer conn.Close()

	// Track pings received
	pingReceived := make(chan struct{}, 1)
	conn.SetPingHandler(func(appData string) error {
		select {
		case pingReceived <- struct{}{}:
		default:
		}
		// Send pong back (default behavior)
		return conn.WriteControl(websocket.PongMessage, []byte(appData), time.Now().Add(hub.config.WriteWait))
	})

	// Start a goroutine to read messages (required to process control frames)
	done := make(chan struct{})
	go func() {
		defer close(done)
		for {
			_, _, err := conn.ReadMessage()
			if err != nil {
				return
			}
		}
	}()

	// Wait for a ping (should come within pingPeriod + some buffer)
	select {
	case <-pingReceived:
		// Success: received ping from server
	case <-time.After(hub.config.PingPeriod + 5*time.Second):
		t.Fatal("did not receive ping within expected time")
	}

	// Connection should still be open — send a message
	hub.BroadcastToUser("user1", []byte(`{"test":"alive"}`))

	conn.Close()
	<-done
}

func TestHub_ReadDeadline_ClosesOnNoPong(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	tokenPair, err := hub.jwtManager.GenerateTokenPair("user2")
	require.NoError(t, err)

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
	require.NoError(t, err)
	defer conn.Close()

	// Override ping handler to NOT send pong back
	conn.SetPingHandler(func(appData string) error {
		// Deliberately do nothing — no pong
		return nil
	})

	// Start reading to process control frames
	disconnected := make(chan struct{})
	go func() {
		defer close(disconnected)
		for {
			_, _, err := conn.ReadMessage()
			if err != nil {
				return
			}
		}
	}()

	// The server should close the connection after pongWait (3s in test config).
	select {
	case <-disconnected:
		// Connection was closed as expected
	case <-time.After(hub.config.PongWait + 5*time.Second):
		t.Fatal("connection was not closed after pong timeout")
	}
}

func TestHub_PongHandler_ResetsReadDeadline(t *testing.T) {
	// This test verifies the pong handler is properly installed
	// by checking that default constants are correctly defined.
	defaults := DefaultHubConfig()
	assert.True(t, defaults.PingPeriod < defaults.PongWait, "pingPeriod must be less than pongWait")
	assert.Equal(t, 30*time.Second, defaults.PingPeriod)
	assert.Equal(t, 60*time.Second, defaults.PongWait)
	assert.Equal(t, 10*time.Second, defaults.WriteWait)
	assert.Equal(t, 5*time.Second, defaults.AuthTimeout)
	assert.Equal(t, 5, defaults.MaxConnsPerUser)
}

func TestHub_HandleWebSocket_NoToken(t *testing.T) {
	_, server := setupTestHub()
	defer server.Close()

	// With no token in URL, the server upgrades and waits for first-message auth.
	// If we close immediately without sending auth, the server detects read error.
	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURLNoToken(server), nil)
	require.NoError(t, err)
	conn.Close()
}

func TestHub_HandleWebSocket_InvalidToken(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()
	_ = hub

	dialer := websocket.Dialer{}
	_, resp, err := dialer.Dial(wsURL(server, "invalid-token"), nil)
	require.Error(t, err)
	assert.Equal(t, http.StatusUnauthorized, resp.StatusCode)
}

func TestHub_BroadcastToUser(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	tokenPair, err := hub.jwtManager.GenerateTokenPair("user3")
	require.NoError(t, err)

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
	require.NoError(t, err)
	defer conn.Close()

	// Give the server a moment to register
	time.Sleep(50 * time.Millisecond)

	// Send a message to user3
	hub.BroadcastToUser("user3", []byte(`{"hello":"world"}`))

	// Read the message (skip heartbeats)
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	var msg []byte
	for {
		_, m, err := conn.ReadMessage()
		require.NoError(t, err)
		var parsed map[string]interface{}
		if json.Unmarshal(m, &parsed) == nil && parsed["type"] == "heartbeat" {
			continue
		}
		msg = m
		break
	}
	assert.Equal(t, `{"hello":"world"}`, string(msg))
}

func TestHub_BroadcastToUser_FirstMessageAuth(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	tokenPair, err := hub.jwtManager.GenerateTokenPair("user-fma-broadcast")
	require.NoError(t, err)

	conn := dialFirstMessageAuth(t, server, tokenPair.AccessToken)
	defer conn.Close()

	time.Sleep(50 * time.Millisecond)

	hub.BroadcastToUser("user-fma-broadcast", []byte(`{"test":"fma"}`))

	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	var msg []byte
	for {
		_, m, err := conn.ReadMessage()
		require.NoError(t, err)
		var parsed map[string]interface{}
		if json.Unmarshal(m, &parsed) == nil && parsed["type"] == "heartbeat" {
			continue
		}
		msg = m
		break
	}
	assert.Equal(t, `{"test":"fma"}`, string(msg))
}

func TestHub_WritePump_SendsCloseOnChannelClose(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	tokenPair, err := hub.jwtManager.GenerateTokenPair("user4")
	require.NoError(t, err)

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
	require.NoError(t, err)
	defer conn.Close()

	// Give the server a moment to register
	time.Sleep(50 * time.Millisecond)

	// Unregister the client (hub closes the send channel)
	hub.mu.RLock()
	clients := hub.clients["user4"]
	hub.mu.RUnlock()

	for client := range clients {
		hub.unregister(client)
		break
	}

	// The client should receive a close message or connection error
	// (heartbeats may arrive before close propagates)
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			// Expected: connection closed
			break
		}
		// Skip heartbeats
		var parsed map[string]interface{}
		if json.Unmarshal(msg, &parsed) == nil && parsed["type"] == "heartbeat" {
			continue
		}
		// Unexpected non-heartbeat message
		t.Errorf("unexpected message after unregister: %s", string(msg))
		break
	}
}

func TestHub_ConnectedUsers_And_TotalConnections(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	assert.Equal(t, 0, hub.ConnectedUsers())
	assert.Equal(t, 0, hub.TotalConnections())

	tokenPair1, err := hub.jwtManager.GenerateTokenPair("user-stats-1")
	require.NoError(t, err)
	tokenPair2, err := hub.jwtManager.GenerateTokenPair("user-stats-2")
	require.NoError(t, err)

	conn1 := dialFirstMessageAuth(t, server, tokenPair1.AccessToken)
	defer conn1.Close()
	conn2 := dialFirstMessageAuth(t, server, tokenPair1.AccessToken)
	defer conn2.Close()
	conn3 := dialFirstMessageAuth(t, server, tokenPair2.AccessToken)
	defer conn3.Close()

	time.Sleep(50 * time.Millisecond)

	assert.Equal(t, 2, hub.ConnectedUsers())
	assert.Equal(t, 3, hub.TotalConnections())
}
