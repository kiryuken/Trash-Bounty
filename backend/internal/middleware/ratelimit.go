package middleware

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"trashbounty/pkg/response"
)

type rateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*visitor
	stopCh   chan struct{}
	doneCh   chan struct{}
	stopOnce sync.Once
}

type visitor struct {
	tokens    int
	lastSeen  time.Time
}

func newRateLimiter() *rateLimiter {
	rl := &rateLimiter{
		visitors: make(map[string]*visitor),
		stopCh:   make(chan struct{}),
		doneCh:   make(chan struct{}),
	}

	go rl.cleanupLoop()

	return rl
}

func (rl *rateLimiter) cleanupLoop() {
	ticker := time.NewTicker(time.Minute)
	defer func() {
		ticker.Stop()
		close(rl.doneCh)
	}()

	for {
		select {
		case <-ticker.C:
			rl.mu.Lock()
			for ip, v := range rl.visitors {
				if time.Since(v.lastSeen) > 3*time.Minute {
					delete(rl.visitors, ip)
				}
			}
			rl.mu.Unlock()
		case <-rl.stopCh:
			return
		}
	}
}

func (rl *rateLimiter) shutdown() {
	rl.stopOnce.Do(func() {
		close(rl.stopCh)
		<-rl.doneCh
	})
}

func (rl *rateLimiter) allow(key string, maxTokens int, refillRate time.Duration) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	v, exists := rl.visitors[key]
	if !exists {
		rl.visitors[key] = &visitor{tokens: maxTokens - 1, lastSeen: time.Now()}
		return true
	}

	// Refill tokens based on time elapsed
	elapsed := time.Since(v.lastSeen)
	refillCount := int(elapsed / refillRate)
	if refillCount > 0 {
		v.tokens += refillCount
		if v.tokens > maxTokens {
			v.tokens = maxTokens
		}
		v.lastSeen = time.Now()
	}

	if v.tokens <= 0 {
		return false
	}

	v.tokens--
	return true
}

var globalLimiter = newRateLimiter()

func ShutdownRateLimiter() {
	globalLimiter.shutdown()
}

// RateLimit limits requests per IP. maxPerMinute controls the rate.
func RateLimit(maxPerMinute int) func(http.Handler) http.Handler {
	refillRate := time.Minute / time.Duration(maxPerMinute)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := clientIPFromRequest(r)

			if !globalLimiter.allow(ip, maxPerMinute, refillRate) {
				response.Error(w, http.StatusTooManyRequests, "terlalu banyak request, coba lagi nanti")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

func clientIPFromRequest(r *http.Request) string {
	remoteIP := parseIP(r.RemoteAddr)
	if remoteIP != nil && trustsForwardedHeaders(remoteIP) {
		if ip := firstForwardedIP(r.Header.Get("X-Forwarded-For")); ip != "" {
			return ip
		}
		if ip := firstForwardedIP(r.Header.Get("X-Real-IP")); ip != "" {
			return ip
		}
	}
	if remoteIP != nil {
		return remoteIP.String()
	}
	return strings.TrimSpace(r.RemoteAddr)
}

func firstForwardedIP(header string) string {
	for _, part := range strings.Split(header, ",") {
		if ip := parseIP(part); ip != nil {
			return ip.String()
		}
	}
	return ""
}

func parseIP(raw string) net.IP {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	if host, _, err := net.SplitHostPort(raw); err == nil {
		raw = host
	}
	raw = strings.Trim(raw, "[]")
	return net.ParseIP(raw)
}

func trustsForwardedHeaders(ip net.IP) bool {
	if ip.IsLoopback() {
		return true
	}
	if ip4 := ip.To4(); ip4 != nil {
		switch {
		case ip4[0] == 10:
			return true
		case ip4[0] == 172 && ip4[1] >= 16 && ip4[1] <= 31:
			return true
		case ip4[0] == 192 && ip4[1] == 168:
			return true
		default:
			return false
		}
	}
	return len(ip) == net.IPv6len && (ip[0]&0xfe) == 0xfc
}
