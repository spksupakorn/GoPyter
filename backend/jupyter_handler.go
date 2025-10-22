package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

type JupyterHandler struct {
	db *sql.DB
}

func NewJupyterHandler(db *sql.DB) *JupyterHandler {
	return &JupyterHandler{db: db}
}

func (h *JupyterHandler) StartSession(c *gin.Context) {
	userID := c.GetInt("user_id")
	username := c.GetString("username")

	// Check if user already has an active session
	var existingSessionID int
	sessionErr := h.db.QueryRow(
		`SELECT id FROM backend.jupyter_sessions WHERE user_id = $1 AND is_active = true`,
		userID,
	).Scan(&existingSessionID)

	// Start JupyterHub server for user via API
	jupyterURL := os.Getenv("JUPYTERHUB_API_URL")
	apiToken := os.Getenv("JUPYTERHUB_API_TOKEN")

	// Create user in JupyterHub if not exists
	err := h.createJupyterUser(username, apiToken, jupyterURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user in JupyterHub"})
		return
	}

	// Start user's server (or ensure it's running)
	startURL := fmt.Sprintf("%s/hub/api/users/%s/server", jupyterURL, username)
	req, _ := http.NewRequest("POST", startURL, nil)
	req.Header.Set("Authorization", fmt.Sprintf("token %s", apiToken))

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if resp != nil {
		resp.Body.Close()
	}

	// Create or update session record - always create/update when starting Jupyter
	if sessionErr == sql.ErrNoRows {
		// No existing session, create new one
		sessionToken := generateSessionToken()
		_, _ = h.db.Exec(
			`INSERT INTO backend.jupyter_sessions (user_id, session_token, jupyter_token, expires_at, is_active)
			 VALUES ($1, $2, $3, $4, true)`,
			userID, sessionToken, "", time.Now().Add(24*time.Hour),
		)
	} else {
		// Update existing session
		_, _ = h.db.Exec(
			`UPDATE backend.jupyter_sessions 
			 SET is_active = true, last_activity = CURRENT_TIMESTAMP, expires_at = $2
			 WHERE user_id = $1`,
			userID, time.Now().Add(24*time.Hour),
		)
	}

	publicURL := os.Getenv("JUPYTERHUB_PUBLIC_URL")
	if publicURL == "" {
		publicURL = jupyterURL
	}

	// Create a JWT token for SSO login
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "your-super-secret-jwt-key-change-this"
	}

	claims := jwt.MapClaims{
		"username": username,
		"exp":      time.Now().Add(time.Minute * 5).Unix(),
	}

	loginToken := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	loginTokenString, err := loginToken.SignedString([]byte(secret))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create login token"})
		return
	}

	// Return the SSO login URL instead of direct JupyterHub URL
	ssoLoginURL := fmt.Sprintf("%s/hub/token-login?token=%s&next=/hub/spawn", publicURL, loginTokenString)

	c.JSON(http.StatusOK, JupyterStartResponse{
		JupyterURL:   ssoLoginURL,
		SessionToken: "",
		Message:      "Jupyter session started successfully. Redirecting to JupyterHub...",
	})
}

func (h *JupyterHandler) GetStatus(c *gin.Context) {
	userID := c.GetInt("user_id")

	var session JupyterSession
	err := h.db.QueryRow(
		`SELECT id, user_id, session_token, started_at, last_activity, expires_at, is_active
		 FROM backend.jupyter_sessions WHERE user_id = $1 AND is_active = true`,
		userID,
	).Scan(&session.ID, &session.UserID, &session.SessionToken, &session.StartedAt,
		&session.LastActivity, &session.ExpiresAt, &session.IsActive)

	if err == sql.ErrNoRows {
		c.JSON(http.StatusOK, gin.H{"status": "inactive", "message": "No active session"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch session"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "active",
		"session": session,
	})
}

func (h *JupyterHandler) StopSession(c *gin.Context) {
	userID := c.GetInt("user_id")
	username := c.GetString("username")

	// Stop JupyterHub server
	jupyterURL := os.Getenv("JUPYTERHUB_API_URL")
	apiToken := os.Getenv("JUPYTERHUB_API_TOKEN")

	stopURL := fmt.Sprintf("%s/hub/api/users/%s/server", jupyterURL, username)
	req, _ := http.NewRequest("DELETE", stopURL, nil)
	req.Header.Set("Authorization", fmt.Sprintf("token %s", apiToken))

	client := &http.Client{Timeout: 30 * time.Second}
	client.Do(req)

	// Deactivate session
	_, err := h.db.Exec(
		`UPDATE backend.jupyter_sessions SET is_active = false WHERE user_id = $1 AND is_active = true`,
		userID,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to stop session"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Session stopped successfully"})
}

func (h *JupyterHandler) GetToken(c *gin.Context) {
	userID := c.GetInt("user_id")

	var token string
	err := h.db.QueryRow(
		`SELECT jupyter_token FROM backend.jupyter_sessions WHERE user_id = $1 AND is_active = true`,
		userID,
	).Scan(&token)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "No active session"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": token})
}

func (h *JupyterHandler) ListSessions(c *gin.Context) {
	rows, err := h.db.Query(
		`SELECT js.id, js.user_id, u.username, js.session_token, js.started_at, 
		        js.last_activity, js.expires_at, js.is_active
		 FROM backend.jupyter_sessions js
		 JOIN backend.users u ON js.user_id = u.id
		 ORDER BY js.started_at DESC`,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch sessions"})
		return
	}
	defer rows.Close()

	var sessions []map[string]interface{}
	for rows.Next() {
		var session JupyterSession
		var username string
		err := rows.Scan(&session.ID, &session.UserID, &username, &session.SessionToken,
			&session.StartedAt, &session.LastActivity, &session.ExpiresAt, &session.IsActive)
		if err != nil {
			continue
		}
		sessions = append(sessions, map[string]interface{}{
			"session":  session,
			"username": username,
		})
	}

	c.JSON(http.StatusOK, sessions)
}

func (h *JupyterHandler) createJupyterUser(username, apiToken, jupyterURL string) error {
	userURL := fmt.Sprintf("%s/hub/api/users/%s", jupyterURL, username)

	userData := map[string]interface{}{
		"admin": false,
	}
	jsonData, _ := json.Marshal(userData)

	req, _ := http.NewRequest("POST", userURL, bytes.NewBuffer(jsonData))
	req.Header.Set("Authorization", fmt.Sprintf("token %s", apiToken))
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	return nil
}

func (h *JupyterHandler) createUserToken(username, apiToken, jupyterURL string) (string, error) {
	tokenURL := fmt.Sprintf("%s/hub/api/users/%s/tokens", jupyterURL, username)

	tokenData := map[string]interface{}{
		"note":       "Auto-generated token for backend access",
		"expires_in": 86400, // 24 hours
	}
	jsonData, _ := json.Marshal(tokenData)

	req, _ := http.NewRequest("POST", tokenURL, bytes.NewBuffer(jsonData))
	req.Header.Set("Authorization", fmt.Sprintf("token %s", apiToken))
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("HTTP request error: %v", err)
		return "", err
	}
	defer resp.Body.Close()

	// Read response body for debugging
	bodyBytes, _ := io.ReadAll(resp.Body)
	log.Printf("JupyterHub token creation response (status %d): %s", resp.StatusCode, string(bodyBytes))

	// Check status code
	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("JupyterHub API error: %d - %s", resp.StatusCode, string(bodyBytes))
	}

	var result map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &result); err != nil {
		log.Printf("JSON decode error: %v", err)
		return "", err
	}

	if token, ok := result["token"].(string); ok {
		log.Printf("Successfully created token for user: %s", username)
		return token, nil
	}

	return "", fmt.Errorf("failed to get token from response")
}

func generateSessionToken() string {
	return fmt.Sprintf("session_%d", time.Now().UnixNano())
}

// AutoLogin creates a session and redirects user to JupyterHub with auto-login
func (h *JupyterHandler) AutoLogin(c *gin.Context) {
	// Get token from query parameter or Authorization header
	var username string
	var userID int

	// Try to get from middleware context first (if Authorization header was used)
	username = c.GetString("username")
	userID = c.GetInt("user_id")

	// If not from middleware, try query parameter
	if username == "" {
		tokenString := c.Query("token")
		if tokenString != "" {
			// Validate JWT token
			secret := os.Getenv("JWT_SECRET")
			if secret == "" {
				secret = "your-super-secret-jwt-key-change-this"
			}

			token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
				return []byte(secret), nil
			})

			if err == nil && token.Valid {
				if claims, ok := token.Claims.(jwt.MapClaims); ok {
					username = claims["username"].(string)
					if uid, ok := claims["user_id"].(float64); ok {
						userID = int(uid)
					}
				}
			}
		}
	}

	if username == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or missing token"})
		return
	}

	// Start JupyterHub server for user via API
	jupyterURL := os.Getenv("JUPYTERHUB_API_URL")
	apiToken := os.Getenv("JUPYTERHUB_API_TOKEN")

	// Create user in JupyterHub if not exists
	err := h.createJupyterUser(username, apiToken, jupyterURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user in JupyterHub"})
		return
	}

	// Start user's server
	startURL := fmt.Sprintf("%s/hub/api/users/%s/server", jupyterURL, username)
	req, _ := http.NewRequest("POST", startURL, nil)
	req.Header.Set("Authorization", fmt.Sprintf("token %s", apiToken))

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err == nil {
		resp.Body.Close()
	}

	// Create a JupyterHub user token for this session
	jupyterToken, err := h.createUserToken(username, apiToken, jupyterURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create JupyterHub token"})
		return
	}

	// Create session record
	sessionToken := generateSessionToken()
	_, _ = h.db.Exec(
		`INSERT INTO backend.jupyter_sessions (user_id, session_token, jupyter_token, expires_at, is_active)
		 VALUES ($1, $2, $3, $4, true)
		 ON CONFLICT (user_id) WHERE is_active = true 
		 DO UPDATE SET jupyter_token = $3, expires_at = $4`,
		userID, sessionToken, jupyterToken, time.Now().Add(24*time.Hour),
	)

	publicURL := os.Getenv("JUPYTERHUB_PUBLIC_URL")
	if publicURL == "" {
		publicURL = jupyterURL
	}

	// Create a JWT token for JupyterHub's custom token-login handler
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "your-super-secret-jwt-key-change-this"
	}

	// Create a short-lived JWT for the login process
	claims := jwt.MapClaims{
		"username": username,
		"exp":      time.Now().Add(time.Minute * 5).Unix(),
	}

	loginToken := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	loginTokenString, err := loginToken.SignedString([]byte(secret))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create login token"})
		return
	}

	// Redirect to JupyterHub's custom token-login handler
	// Redirect to spawn page instead of directly to user server
	loginURL := fmt.Sprintf("%s/hub/token-login?token=%s&next=/hub/spawn",
		publicURL, loginTokenString)

	// Return HTML that redirects
	html := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="0; url=%s">
    <title>Redirecting to JupyterHub...</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            color: white;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.1);
            padding: 40px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        .spinner {
            border: 4px solid rgba(255, 255, 255, 0.3);
            border-top: 4px solid white;
            border-radius: 50%%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }
        @keyframes spin {
            0%% { transform: rotate(0deg); }
            100%% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>🚀 Launching JupyterHub</h2>
        <div class="spinner"></div>
        <p>Redirecting...</p>
        <p><small>If you are not redirected automatically, <a href="%s" style="color: white;">click here</a>.</small></p>
    </div>
    <script>
        window.location.href = '%s';
    </script>
</body>
</html>`, loginURL, loginURL, loginURL)

	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(html))
}
