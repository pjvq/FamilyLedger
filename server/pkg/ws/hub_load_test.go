package ws

import (
	"math/rand"
	"net/http"
	"runtime"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestHub_Load_100Clients_Connect(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	const clientCount = 100

	tokenPair, err := hub.jwtManager.GenerateTokenPair("load-user")
	require.NoError(t, err)

	conns := make([]*websocket.Conn, clientCount)
	var wg sync.WaitGroup
	wg.Add(clientCount)

	var connectErrors int32

	for i := 0; i < clientCount; i++ {
		go func(idx int) {
			defer wg.Done()
			dialer := websocket.Dialer{}
			conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
			if err != nil {
				atomic.AddInt32(&connectErrors, 1)
				return
			}
			conns[idx] = conn
		}(i)
	}

	wg.Wait()

	assert.Equal(t, int32(0), connectErrors, "some connections failed")

	// Give server a moment to register all clients
	time.Sleep(100 * time.Millisecond)

	hub.mu.RLock()
	clientsForUser := len(hub.clients["load-user"])
	hub.mu.RUnlock()

	assert.Equal(t, clientCount, clientsForUser,
		"expected %d registered clients, got %d", clientCount, clientsForUser)

	// Cleanup
	for _, conn := range conns {
		if conn != nil {
			conn.Close()
		}
	}
}

func TestHub_Load_BroadcastToAll(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	const clientCount = 50
	const userID = "broadcast-user"

	tokenPair, err := hub.jwtManager.GenerateTokenPair(userID)
	require.NoError(t, err)

	conns := make([]*websocket.Conn, clientCount)
	for i := 0; i < clientCount; i++ {
		dialer := websocket.Dialer{}
		conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
		require.NoError(t, err)
		conns[i] = conn
	}
	defer func() {
		for _, conn := range conns {
			if conn != nil {
				conn.Close()
			}
		}
	}()

	// Wait for all clients to be registered
	time.Sleep(100 * time.Millisecond)

	// Broadcast a message
	message := []byte(`{"event":"sync","entity":"transaction","id":"abc123"}`)
	hub.BroadcastToUser(userID, message)

	// Verify all clients received the message
	var received int32
	var wg sync.WaitGroup
	wg.Add(clientCount)

	for i := 0; i < clientCount; i++ {
		go func(idx int) {
			defer wg.Done()
			conns[idx].SetReadDeadline(time.Now().Add(5 * time.Second))
			_, msg, err := conns[idx].ReadMessage()
			if err == nil && string(msg) == string(message) {
				atomic.AddInt32(&received, 1)
			}
		}(i)
	}

	wg.Wait()

	assert.Equal(t, int32(clientCount), received,
		"expected all %d clients to receive the broadcast, got %d", clientCount, received)
}

func TestHub_Load_ClientDisconnect_Cleanup(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	const clientCount = 30
	const userID = "disconnect-user"

	tokenPair, err := hub.jwtManager.GenerateTokenPair(userID)
	require.NoError(t, err)

	conns := make([]*websocket.Conn, clientCount)
	for i := 0; i < clientCount; i++ {
		dialer := websocket.Dialer{}
		conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
		require.NoError(t, err)
		conns[i] = conn
	}

	// Wait for registration
	time.Sleep(100 * time.Millisecond)

	hub.mu.RLock()
	initialCount := len(hub.clients[userID])
	hub.mu.RUnlock()
	assert.Equal(t, clientCount, initialCount)

	// Close half the connections
	halfCount := clientCount / 2
	for i := 0; i < halfCount; i++ {
		conns[i].Close()
	}

	// Wait for server to process disconnections
	time.Sleep(500 * time.Millisecond)

	hub.mu.RLock()
	remainingCount := len(hub.clients[userID])
	hub.mu.RUnlock()

	assert.Equal(t, clientCount-halfCount, remainingCount,
		"expected %d clients after closing %d, got %d",
		clientCount-halfCount, halfCount, remainingCount)

	// Cleanup remaining
	for i := halfCount; i < clientCount; i++ {
		conns[i].Close()
	}

	// Wait and verify full cleanup
	time.Sleep(500 * time.Millisecond)

	hub.mu.RLock()
	finalCount := len(hub.clients[userID])
	hub.mu.RUnlock()

	assert.Equal(t, 0, finalCount, "expected 0 clients after all disconnected")
}

func TestHub_Load_ConcurrentConnectDisconnect_NoPanic(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	const iterations = 50
	const userID = "chaos-user"

	tokenPair, err := hub.jwtManager.GenerateTokenPair(userID)
	require.NoError(t, err)

	var wg sync.WaitGroup
	panicCaught := make(chan string, iterations*2)

	// Spawn goroutines that connect and immediately disconnect
	for i := 0; i < iterations; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer func() {
				if r := recover(); r != nil {
					panicCaught <- "connect/disconnect panic"
				}
			}()

			dialer := websocket.Dialer{}
			conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
			if err != nil {
				return
			}
			// Randomly delay before close to create interleaving
			time.Sleep(time.Duration(1+time.Now().UnixNano()%10) * time.Millisecond)
			conn.Close()
		}()
	}

	// Also broadcast concurrently
	for i := 0; i < iterations; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer func() {
				if r := recover(); r != nil {
					panicCaught <- "broadcast panic"
				}
			}()
			hub.BroadcastToUser(userID, []byte(`{"ping":"pong"}`))
		}()
	}

	wg.Wait()
	close(panicCaught)

	for p := range panicCaught {
		t.Fatalf("caught panic: %s", p)
	}
}

func TestHub_Load_MultipleUsers_Isolation(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	const usersCount = 10
	const clientsPerUser = 5

	type userConns struct {
		userID string
		conns  []*websocket.Conn
	}

	users := make([]userConns, usersCount)

	for u := 0; u < usersCount; u++ {
		userID := "multi-user-" + string(rune('A'+u))
		tokenPair, err := hub.jwtManager.GenerateTokenPair(userID)
		require.NoError(t, err)

		users[u] = userConns{userID: userID, conns: make([]*websocket.Conn, clientsPerUser)}
		for c := 0; c < clientsPerUser; c++ {
			dialer := websocket.Dialer{}
			conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
			require.NoError(t, err)
			users[u].conns[c] = conn
		}
	}
	defer func() {
		for _, u := range users {
			for _, conn := range u.conns {
				if conn != nil {
					conn.Close()
				}
			}
		}
	}()

	time.Sleep(100 * time.Millisecond)

	// Send a message to user[0] only
	targetUser := users[0].userID
	hub.BroadcastToUser(targetUser, []byte(`{"target":"only-me"}`))

	// Verify user[0] receives it
	for _, conn := range users[0].conns {
		conn.SetReadDeadline(time.Now().Add(2 * time.Second))
		_, msg, err := conn.ReadMessage()
		require.NoError(t, err)
		assert.Equal(t, `{"target":"only-me"}`, string(msg))
	}

	// Verify other users do NOT receive it (read should timeout)
	for u := 1; u < usersCount; u++ {
		conn := users[u].conns[0]
		conn.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
		_, _, err := conn.ReadMessage()
		assert.Error(t, err, "user %s should not have received the message", users[u].userID)
	}
}

func TestHub_Load_HandleWebSocket_Unauthorized_UnderLoad(t *testing.T) {
	_, server := setupTestHub()
	defer server.Close()

	// Spam unauthorized connection attempts
	const attempts = 50
	var wg sync.WaitGroup
	wg.Add(attempts)

	var failCount int32
	for i := 0; i < attempts; i++ {
		go func() {
			defer wg.Done()
			dialer := websocket.Dialer{}
			_, resp, err := dialer.Dial(wsURL(server, "invalid-token"), nil)
			if err != nil && resp != nil && resp.StatusCode == http.StatusUnauthorized {
				atomic.AddInt32(&failCount, 1)
			}
		}()
	}

	wg.Wait()
	assert.Equal(t, int32(attempts), failCount,
		"all unauthorized attempts should be rejected")
}

func TestHub_Load_BroadcastToNonexistentUser_NoPanic(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	// Should not panic when broadcasting to a user with no connections
	var wg sync.WaitGroup
	const iterations = 100
	wg.Add(iterations)

	for i := 0; i < iterations; i++ {
		go func() {
			defer wg.Done()
			hub.BroadcastToUser("nonexistent-user", []byte(`{"hello":"nobody"}`))
		}()
	}

	wg.Wait()
	// If we get here without panic, the test passes
}

// ═══════════════════════════════════════════════════════════════════════════════
// W13: 100 Clients + 10% Random Disconnect During Broadcast
// ═══════════════════════════════════════════════════════════════════════════════

func TestHub_Load_100Clients_RandomDisconnect(t *testing.T) {
	hub, server := setupTestHub()
	defer server.Close()

	const clientCount = 100
	const disconnectCount = 10
	const userID = "random-disconnect-user"

	tokenPair, err := hub.jwtManager.GenerateTokenPair(userID)
	require.NoError(t, err)

	// Connect 100 clients
	conns := make([]*websocket.Conn, clientCount)
	for i := 0; i < clientCount; i++ {
		dialer := websocket.Dialer{}
		conn, _, err := dialer.Dial(wsURL(server, tokenPair.AccessToken), nil)
		require.NoError(t, err)
		conns[i] = conn
	}

	// Wait for all clients to be registered
	time.Sleep(200 * time.Millisecond)

	hub.mu.RLock()
	initialCount := len(hub.clients[userID])
	hub.mu.RUnlock()
	assert.Equal(t, clientCount, initialCount, "all 100 clients should be registered")

	// Record goroutine count before disconnect
	goroutinesBefore := runtime.NumGoroutine()

	// Randomly select 10 clients to disconnect
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	perm := rng.Perm(clientCount)
	disconnectedSet := make(map[int]bool)
	for i := 0; i < disconnectCount; i++ {
		disconnectedSet[perm[i]] = true
	}

	// Disconnect the selected 10 clients
	for idx := range disconnectedSet {
		conns[idx].Close()
	}

	// Wait for server to process disconnections
	time.Sleep(500 * time.Millisecond)

	// Broadcast a message
	message := []byte(`{"event":"sync","entity":"transaction","id":"w13-test"}`)
	hub.BroadcastToUser(userID, message)

	// Verify remaining 90 clients receive the broadcast
	var received int32
	var wg sync.WaitGroup

	for i := 0; i < clientCount; i++ {
		if disconnectedSet[i] {
			continue // skip disconnected clients
		}
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			conns[idx].SetReadDeadline(time.Now().Add(5 * time.Second))
			_, msg, err := conns[idx].ReadMessage()
			if err == nil && string(msg) == string(message) {
				atomic.AddInt32(&received, 1)
			}
		}(i)
	}

	wg.Wait()

	expectedReceived := int32(clientCount - disconnectCount)
	assert.Equal(t, expectedReceived, received,
		"expected %d clients to receive broadcast, got %d", expectedReceived, received)

	// Verify disconnected clients are cleaned up
	hub.mu.RLock()
	remainingCount := len(hub.clients[userID])
	hub.mu.RUnlock()
	assert.Equal(t, clientCount-disconnectCount, remainingCount,
		"expected %d remaining clients, got %d", clientCount-disconnectCount, remainingCount)

	// Cleanup remaining connections
	for i := 0; i < clientCount; i++ {
		if !disconnectedSet[i] {
			conns[i].Close()
		}
	}

	// Wait for cleanup and check for goroutine leaks
	time.Sleep(500 * time.Millisecond)

	hub.mu.RLock()
	finalCount := len(hub.clients[userID])
	hub.mu.RUnlock()
	assert.Equal(t, 0, finalCount, "all clients should be cleaned up")

	// Check goroutine count didn't grow significantly
	time.Sleep(200 * time.Millisecond)
	goroutinesAfter := runtime.NumGoroutine()
	// Allow some slack for background goroutines
	assert.Less(t, goroutinesAfter, goroutinesBefore+10,
		"goroutine leak detected: before=%d after=%d", goroutinesBefore, goroutinesAfter)

	t.Logf("W13 WS PASS: %d/%d clients received broadcast, %d disconnected cleaned up, goroutines before=%d after=%d",
		received, expectedReceived, disconnectCount, goroutinesBefore, goroutinesAfter)
}
