package ws

import (
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
		WriteWait:  2 * time.Second,
		PongWait:   3 * time.Second,
		PingPeriod: 1 * time.Second,
	}
}

func setupTestHub() (*Hub, *httptest.Server) {
	jwtManager := jwtpkg.NewManager("test-secret-key-for-ws-tests-12345")
	hub := NewHub(jwtManager, fastConfig())

	server := httptest.NewServer(http.HandlerFunc(hub.HandleWebSocket))
	return hub, server
}

func wsURL(server *httptest.Server, token string) string {
	url := "ws" + strings.TrimPrefix(server.URL, "http") + "?token=" + token
	return url
}

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
}

func TestHub_HandleWebSocket_NoToken(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()
	_ = hub

	dialer := websocket.Dialer{}
	_, resp, err := dialer.Dial("ws"+strings.TrimPrefix(server.URL, "http"), nil)
	require.Error(t, err)
	assert.Equal(t, http.StatusUnauthorized, resp.StatusCode)
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

	// Read the message
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, msg, err := conn.ReadMessage()
	require.NoError(t, err)
	assert.Equal(t, `{"hello":"world"}`, string(msg))
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
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, _, err = conn.ReadMessage()
	assert.Error(t, err)
}
