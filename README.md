# JupyterHub SSO Multi-User Platform

A production-ready, enterprise-grade JupyterHub platform with **Single Sign-On (SSO)** authentication, automatic resource management, and isolated Docker-based user environments. This system enables seamless integration between a custom frontend portal and JupyterHub, allowing users to access their personal Jupyter notebooks without re-authentication.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Key Features](#key-features)
4. [Technical Stack](#technical-stack)
5. [How It Works](#how-it-works)
6. [Prerequisites](#prerequisites)
7. [Quick Start](#quick-start)
8. [Configuration](#configuration)
9. [API Reference](#api-reference)
10. [Resource Management](#resource-management)
11. [Security](#security)
12. [Troubleshooting](#troubleshooting)
13. [For Learners](#for-learners)

---

## 📖 Overview

This project implements a **complete SSO solution** for JupyterHub, allowing users to:
- Register and login through a custom portal (Frontend + Backend)
- Automatically access JupyterHub without seeing the login screen
- Work in isolated Docker containers with resource limits
- Have their notebooks automatically stopped after idle timeout
- Manage multiple concurrent users efficiently

**Perfect for:** Educational platforms, corporate data science environments, research institutions, or any multi-user Jupyter deployment.

---

## 🏗️ Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Frontend  │────────▶│   Backend   │────────▶│ PostgreSQL  │
│   (React)   │  HTTP   │  (Go/Gin)   │  SQL    │  Database   │
└──────┬──────┘         └──────┬──────┘         └─────────────┘
       │                       │
       │ SSO Token             │ JWT + API Calls
       │                       │
       ▼                       ▼
┌─────────────────────────────────────────────────┐
│              JupyterHub                         │
│  ┌──────────────────────────────────────┐      │
│  │     Custom Token Login Handler       │      │
│  │  (Validates JWT → Sets Cookie)       │      │
│  └──────────────────────────────────────┘      │
│                                                  │
│  ┌──────────────────────────────────────┐      │
│  │      Docker Spawner                  │      │
│  │  (Creates user containers)           │      │
│  └──────────────────────────────────────┘      │
│                                                  │
│  ┌──────────────────────────────────────┐      │
│  │      Idle Culler Service             │      │
│  │  (Cleans up inactive servers)        │      │
│  └──────────────────────────────────────┘      │
└─────────────────────────────────────────────────┘
                    │
                    ▼
       ┌────────────────────────┐
       │   User Containers      │
       │  (JupyterLab + Python) │
       │   - user-admin         │
       │   - user-john          │
       │   - user-jane          │
       └────────────────────────┘
```

**Component Roles:**
- **Frontend**: User interface for registration, login, and accessing Jupyter
- **Backend**: Authentication server, JWT token generation, JupyterHub API integration
- **PostgreSQL**: Stores user credentials and session information
- **JupyterHub**: Orchestrates user notebook servers, handles SSO, manages resources
- **Docker Spawner**: Creates isolated containers for each user's notebook environment
- **Idle Culler**: Monitors and stops inactive notebook servers to free resources

---

## ✨ Key Features

### Authentication & Security
- 🔐 **JWT-based SSO** - Seamless single sign-on from frontend to JupyterHub
- 🔒 **Bcrypt Password Hashing** - Industry-standard password security
- 🎫 **Token-based Authentication** - No credentials stored in browser
- 🚪 **Custom Login Handler** - Bypasses default JupyterHub login screen

### Resource Management
- 💾 **Per-User Limits** - 2GB RAM and 1 CPU core per notebook (configurable)
- ⏱️ **Automatic Idle Timeout** - Stops servers after 1 hour of inactivity
- 👥 **Concurrent User Limits** - Supports 50 active servers, 10 concurrent spawns
- 🧹 **Automatic Cleanup** - Frees resources from inactive users

### Multi-User Support
- 🐳 **Docker Isolation** - Each user gets their own container
- 📦 **Persistent Storage** - User notebooks saved in Docker volumes
- 🔄 **Dynamic Scaling** - Containers created on-demand, destroyed when idle
- 📊 **Session Tracking** - Backend tracks active JupyterHub sessions

### Developer Experience
- 📝 **RESTful API** - Clean API design with JWT authentication
- 🚀 **Docker Compose** - One-command deployment
- 📚 **Comprehensive Documentation** - Guides for testing and resource management
- 🛠️ **Easy Configuration** - Environment variables for all settings

---

## 🛠️ Technical Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Backend** | Go + Gin | 1.23 | REST API, JWT auth, JupyterHub integration |
| **Frontend** | React | Latest | User interface |
| **Database** | PostgreSQL | 16 | User data, session management |
| **Notebook Server** | JupyterHub | Latest | Multi-user notebook orchestration |
| **Container Runtime** | Docker | Latest | User environment isolation |
| **Authenticator** | Custom Python | - | JWT validation, user management |
| **Spawner** | DockerSpawner | Latest | Container lifecycle management |
| **Resource Cleaner** | Idle Culler | Latest | Automatic server cleanup |

**Python Packages:**
- `jupyterhub` - Core JupyterHub functionality
- `dockerspawner` - Docker container management
- `psycopg2-binary` - PostgreSQL database connection
- `PyJWT` - JWT token validation
- `bcrypt` - Password hashing
- `jupyterhub-idle-culler` - Idle server cleanup

**Go Packages:**
- `gin-gonic/gin` - Web framework
- `golang-jwt/jwt` - JWT token generation
- `lib/pq` - PostgreSQL driver

---

## 🔄 How It Works

### Complete Authentication Flow (Step-by-Step)

#### 1. **User Registration**
```
User → Frontend → Backend → PostgreSQL
```
- User fills registration form (username, email, password)
- Frontend sends `POST /api/v1/register` to Backend
- Backend hashes password with bcrypt
- Backend stores user in `backend.users` table
- Returns success response

#### 2. **User Login**
```
User → Frontend → Backend → PostgreSQL → Frontend
```
- User enters credentials in login form
- Frontend sends `POST /api/v1/login` to Backend
- Backend validates password against database
- Backend generates JWT token (5-minute expiration)
- Frontend stores JWT token in memory/localStorage

#### 3. **Starting Jupyter Session (SSO)**
```
User → Frontend → Backend → JupyterHub
```
- User clicks "Open Jupyter" button
- Frontend sends `POST /api/v1/jupyter/start` with JWT in Authorization header
- Backend validates JWT token
- Backend generates new JWT with username claim
- Backend returns SSO URL: `http://localhost:8000/hub/token-login?token=JWT&next=/hub/spawn`

#### 4. **SSO Token Validation**
```
Frontend → JupyterHub Token Handler → Database → Cookie
```
- Frontend redirects browser to SSO URL
- JupyterHub `TokenLoginHandler` receives request
- Handler decodes JWT and validates signature (shared JWT_SECRET)
- Handler checks if user exists in `backend.users` table
- If user doesn't exist in JupyterHub, creates new user object
- Handler sets JupyterHub authentication cookie
- Redirects to `/hub/spawn` (or custom `next` URL)

#### 5. **Container Spawning**
```
JupyterHub → DockerSpawner → Docker Engine → User Container
```
- User arrives at `/hub/spawn` with valid cookie
- JupyterHub calls DockerSpawner to create container
- DockerSpawner pulls image (if not cached)
- Creates Docker container with:
  - Name: `jupyter-{username}`
  - Memory limit: 2GB
  - CPU limit: 1 core
  - Volume: `jupyterhub-user-{username}`
  - Network: `jupyterhub_jupyterhub-network`
- Starts JupyterLab server inside container
- JupyterHub proxies traffic to container

#### 6. **User Works in JupyterLab**
```
User ↔ JupyterHub Proxy ↔ User Container
```
- User accesses notebook at `http://localhost:8000/user/{username}/lab`
- All requests proxied through JupyterHub
- Work saved to persistent volume
- Idle Culler monitors last activity timestamp

#### 7. **Automatic Cleanup (Idle Timeout)**
```
Idle Culler → JupyterHub API → Docker
```
- Idle Culler checks every 10 minutes
- If server inactive for 1+ hour:
  - Calls JupyterHub API to stop server
  - DockerSpawner stops and removes container
  - Volume persists for next session
- Resources freed for other users

#### 8. **Manual Logout (Optional)**
```
User → Frontend → Backend → JupyterHub API
```
- User clicks logout in frontend
- Frontend calls `POST /api/v1/jupyter/stop`
- Backend calls JupyterHub API: `DELETE /hub/api/users/{username}/server`
- Container immediately stopped
- Database session marked as inactive

---

## 📋 Prerequisites

### Required Software
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+
- **Git**: For cloning repository

### System Requirements
- **RAM**: Minimum 4GB (8GB+ recommended for multiple concurrent users)
- **CPU**: 2+ cores recommended
- **Disk**: 10GB+ free space
- **OS**: Linux, macOS, or Windows with WSL2

### Network Requirements
- **Ports**: 3000, 8000, 8080, 5432 must be available
- **Internet**: Required for pulling Docker images

---

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone <your-repository-url>
cd jupyterhub
```

### 2. Configure Environment Variables
Update `compose.yaml` with your secrets (IMPORTANT for production):

```yaml
# Backend service
JWT_SECRET: "your-random-secret-here"  # Change this!
JUPYTERHUB_API_TOKEN: "your-api-token-here"  # Change this!

# PostgreSQL
POSTGRES_PASSWORD: "your-db-password-here"  # Change this!

# JupyterHub (⚠️ CRITICAL: Both tokens must be set!)
JUPYTERHUB_API_TOKEN: "your-api-token-here"  # Must be SAME as backend
JWT_SECRET: "your-random-secret-here"  # Must be SAME as backend
```

**⚠️ IMPORTANT**: The `JUPYTERHUB_API_TOKEN` **must be set in both backend AND JupyterHub** services with the **exact same value**. Missing this will cause "403 Forbidden" errors.

**Generate secure secrets:**
```bash
# For JWT_SECRET (32+ characters recommended)
openssl rand -hex 32

# For JUPYTERHUB_API_TOKEN (use same value in both services)
openssl rand -hex 16
```

### 3. Start All Services
```bash
docker compose up -d --build
```

This will:
- Build backend Go application
- Build JupyterHub with custom configuration
- Pull PostgreSQL and frontend images
- Create Docker network
- Initialize database schema
- Start all services

### 4. Verify Services are Running
```bash
docker compose ps
```

Expected output:
```
NAME                  STATUS      PORTS
jupyterhub-backend    Up          0.0.0.0:8080->8080/tcp
jupyterhub-db         Up          0.0.0.0:5432->5432/tcp
jupyterhub-frontend   Up          0.0.0.0:3000->3000/tcp
jupyterhub            Up          0.0.0.0:8000->8000/tcp
```

**⚠️ First-Time Setup Note:**
If JupyterHub shows "Exited" or keeps restarting, it may be due to leftover proxy pid files. Fix with:
```bash
docker compose down jupyterhub
docker volume rm jupyterhub_jupyterhub_data
docker compose up -d jupyterhub
```

### 5. Access the Application

- **Frontend Portal**: http://localhost:3000
- **Backend API**: http://localhost:8080
- **JupyterHub**: http://localhost:8000 (usually not accessed directly)
- **PostgreSQL**: localhost:5432

### 6. Create Your First User

**Option A: Via Frontend**
1. Open http://localhost:3000
2. Click "Register"
3. Fill in username, email, password
4. Submit form

**Option B: Via API**
```bash
curl -X POST http://localhost:8080/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123"
  }'
```

### 7. Test SSO Flow

1. Login through frontend (http://localhost:3000)
2. Click "Open Jupyter" button
3. Browser automatically redirects to JupyterHub
4. You'll be logged in without seeing login screen
5. JupyterLab opens at `http://localhost:8000/user/{username}/lab`

### 8. Verification Checklist

After starting all services, verify everything is configured correctly:

```bash
# ✅ Check all services are running
docker compose ps
# All services should show "Up" status

# ✅ Verify JupyterHub has API token environment variable
docker compose exec jupyterhub env | grep JUPYTERHUB_API_TOKEN
# Should output: JUPYTERHUB_API_TOKEN=your-token-value

# ✅ Verify backend has API token environment variable
docker compose exec backend env | grep JUPYTERHUB_API_TOKEN
# Should output: JUPYTERHUB_API_TOKEN=your-token-value (SAME as JupyterHub)

# ✅ Check backend-api service is registered
docker compose logs jupyterhub | grep "backend-api"
# Should see: "Adding API token for service: backend-api"

# ✅ Verify JupyterHub is running
docker compose logs jupyterhub | tail -5
# Should see: "JupyterHub is now running at http://0.0.0.0:8000/"
```

**If any checks fail**, refer to the [Troubleshooting](#-troubleshooting) section.

---

## ⚙️ Configuration


---

## ⚙️ Configuration

### Environment Variables

#### Backend (`compose.yaml` - backend service)
```yaml
DB_HOST: "jupyterhub-db"          # PostgreSQL hostname
DB_PORT: "5432"                    # PostgreSQL port
DB_USER: "postgres"                # Database user
DB_PASSWORD: "postgres"            # Database password (CHANGE THIS!)
DB_NAME: "postgres"                # Database name
JUPYTERHUB_URL: "http://jupyterhub:8000"  # JupyterHub internal URL
JUPYTERHUB_API_TOKEN: "your-token" # API token for JupyterHub (CHANGE THIS!)
JWT_SECRET: "your-secret"          # Secret for signing JWT tokens (CHANGE THIS!)
```

#### JupyterHub (`compose.yaml` - jupyterhub service)
```yaml
JUPYTERHUB_API_TOKEN: "your-token" # ⚠️ CRITICAL: Must match backend token exactly!
JWT_SECRET: "your-secret"          # Must match backend secret
DB_HOST: "jupyterhub-db"           # Database for user validation
DB_USER: "postgres"
DB_PASSWORD: "postgres"            # CHANGE THIS!
DB_NAME: "postgres"
DOCKER_NETWORK_NAME: "jupyterhub_jupyterhub-network"  # Docker network for spawned containers
```

**⚠️ CRITICAL**: The `JUPYTERHUB_API_TOKEN` environment variable **MUST** be set in the JupyterHub service. Without it, you'll get "403 Forbidden" errors when users try to start Jupyter. Both backend and JupyterHub must use the **same token value**.

### JupyterHub Configuration (`jupyterhub/jupyterhub_config.py`)

**Key Settings:**

```python
# Spawner Configuration (resource limits per user)
c.DockerSpawner.mem_limit = '2G'           # RAM per container
c.DockerSpawner.cpu_limit = 1.0            # CPU cores per container
c.DockerSpawner.image = 'jupyter/base-notebook:latest'  # Notebook image

# Concurrent Usage Limits
c.JupyterHub.active_server_limit = 50      # Max active servers
c.JupyterHub.concurrent_spawn_limit = 10   # Max simultaneous spawns

# Idle Culler (automatic cleanup)
c.JupyterHub.load_roles = [{
    'name': 'idle-culler',
    'scopes': [
        'read:users:activity',
        'servers',
        'admin:users',
    ],
    'services': ['idle-culler'],
}]

c.JupyterHub.services = [{
    'name': 'idle-culler',
    'command': [
        'python3', '-m', 'jupyterhub_idle_culler',
        '--timeout=3600',      # Stop after 1 hour idle (in seconds)
        '--cull-every=600',    # Check every 10 minutes
        '--cull-users=True',   # Also cull user objects (not just servers)
    ],
}]
```

**Adjusting Resource Limits:**

For different hardware configurations, modify these values:

```python
# For powerful servers (8GB+ RAM available)
c.DockerSpawner.mem_limit = '4G'
c.DockerSpawner.cpu_limit = 2.0
c.JupyterHub.active_server_limit = 100

# For limited resources (4GB RAM total)
c.DockerSpawner.mem_limit = '512M'
c.DockerSpawner.cpu_limit = 0.5
c.JupyterHub.active_server_limit = 10

# For long-running computations (adjust idle timeout)
'--timeout=14400',  # 4 hours in seconds
```

### API Token Scopes and Services

**IMPORTANT:** JupyterHub requires proper API token scopes to allow the backend to create users and start servers.

**In `jupyterhub_config.py`:**

```python
# Register backend API as a service with the API token
c.JupyterHub.services = [
    {
        'name': 'idle-culler',
        'admin': True,
        'command': [...],
    },
    {
        'name': 'backend-api',
        'api_token': os.environ.get('JUPYTERHUB_API_TOKEN'),
    }
]

# Define roles with proper scopes
c.JupyterHub.load_roles = [
    {
        'name': 'backend-api-role',
        'scopes': [
            'admin:users',      # Create and manage users
            'admin:servers',    # Start and stop servers
            'read:users',       # Read user information
            'read:servers',     # Read server information
            'servers',          # Access to server operations
            'access:servers',   # Access to spawn servers
        ],
        'services': ['backend-api'],
    },
    {
        'name': 'idle-culler',
        'scopes': [
            'read:users:activity',
            'servers',
            'admin:users',
        ],
        'services': ['idle-culler'],
    }
]

# Allow any authenticated user to access
c.Authenticator.allow_all = True
```

**Why this matters:**
- Without proper scopes, the backend cannot create users → **403 Forbidden** error
- The `backend-api` service registers the API token with necessary permissions
- Roles define what actions the API token can perform
- `allow_all = True` allows users authenticated via SSO to access JupyterHub

### Database Schema

The system uses two main tables:

**`backend.users`** (User authentication)
```sql
CREATE TABLE IF NOT EXISTS backend.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,  -- Bcrypt hashed
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**`backend.jupyter_sessions`** (Session tracking)
```sql
CREATE TABLE IF NOT EXISTS backend.jupyter_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES backend.users(id),
    jupyterhub_url VARCHAR(255),
    status VARCHAR(50),
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    stopped_at TIMESTAMP
);
```

Schema is automatically created by `init-backend-db.sql` on first run.

---

## 📡 API Reference

### Authentication Endpoints

#### Register User
```http
POST /api/v1/register
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "secure_password123"
}
```

**Response (201 Created):**
```json
{
  "message": "User created successfully"
}
```

#### Login
```http
POST /api/v1/login
Content-Type: application/json

{
  "username": "john_doe",
  "password": "secure_password123"
}
```

**Response (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "username": "john_doe",
    "email": "john@example.com"
  }
}
```

### Protected Endpoints (Require JWT Token)

**Include token in header:**
```http
Authorization: Bearer <your-jwt-token>
```

#### Get User Profile
```http
GET /api/v1/profile
Authorization: Bearer <token>
```

**Response:**
```json
{
  "id": 1,
  "username": "john_doe",
  "email": "john@example.com",
  "created_at": "2025-10-22T10:30:00Z"
}
```

#### Start Jupyter Session (SSO)
```http
POST /api/v1/jupyter/start
Authorization: Bearer <token>
```

**Response:**
```json
{
  "message": "Session started successfully",
  "sso_url": "http://localhost:8000/hub/token-login?token=eyJhbGc...&next=/hub/spawn",
  "session_id": 42
}
```

**Frontend should redirect browser to `sso_url` to complete SSO login.**

#### Get Session Status
```http
GET /api/v1/jupyter/status
Authorization: Bearer <token>
```

**Response:**
```json
{
  "status": "running",
  "jupyterhub_url": "http://localhost:8000/user/john_doe",
  "started_at": "2025-10-22T11:00:00Z"
}
```

#### Stop Jupyter Session
```http
POST /api/v1/jupyter/stop
Authorization: Bearer <token>
```

**Response:**
```json
{
  "message": "Session stopped successfully"
}
```

### Admin Endpoints

#### List All Users
```http
GET /api/v1/admin/users
Authorization: Bearer <admin-token>
```

#### List All Sessions
```http
GET /api/v1/admin/sessions
Authorization: Bearer <admin-token>
```

---

## 💾 Resource Management

### Automatic Idle Cleanup

The **Idle Culler** service automatically monitors and cleans up inactive notebook servers:

**How it works:**
1. Checks all running servers every 10 minutes (`--cull-every=600`)
2. Identifies servers with no activity for 1+ hour (`--timeout=3600`)
3. Calls JupyterHub API to stop idle servers
4. DockerSpawner removes the Docker container
5. User data persists in Docker volume
6. Next time user logs in, container is recreated

**Monitoring idle cleanup:**
```bash
# View idle-culler logs
docker compose logs jupyterhub -f | grep -i culler

# Check running containers
docker ps | grep jupyter

# View resource usage
docker stats
```

### Resource Limits Per User

Each user notebook server is limited to:
- **Memory**: 2GB (kills container if exceeded)
- **CPU**: 1 core (throttles if exceeded)
- **Disk**: Unlimited (constrained by host system)

**Why limits matter:**
- Prevents single user from consuming all resources
- Ensures fair distribution among concurrent users
- Protects host system from crashes

### Concurrent User Limits

**Active Server Limit**: 50
- Maximum number of notebook servers running simultaneously
- New spawn requests rejected if limit reached
- Users see "spawn failed" error

**Concurrent Spawn Limit**: 10
- Maximum number of containers starting at same time
- Additional spawn requests queued
- Prevents Docker daemon overload

**Adjusting for your needs:**

```python
# In jupyterhub_config.py

# For small teams (4GB RAM total)
c.JupyterHub.active_server_limit = 10
c.DockerSpawner.mem_limit = '256M'

# For large organizations (64GB+ RAM)
c.JupyterHub.active_server_limit = 200
c.DockerSpawner.mem_limit = '4G'
c.JupyterHub.concurrent_spawn_limit = 20
```

### Storage and Persistence

**Docker Volumes:**
- Each user gets persistent volume: `jupyterhub-user-{username}`
- Notebooks and files saved across container restarts
- Volume survives container deletion (idle cleanup)
- Manually delete with: `docker volume rm jupyterhub-user-{username}`

**Viewing user volumes:**
```bash
docker volume ls | grep jupyterhub-user
```

**Backing up user data:**
```bash
# Backup single user
docker run --rm \
  -v jupyterhub-user-john:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/john-backup.tar.gz /data

# Restore
docker run --rm \
  -v jupyterhub-user-john:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/john-backup.tar.gz -C /
```

---

## 🔒 Security

### Production Security Checklist

#### 1. Change All Default Secrets
```bash
# Generate secure secrets
openssl rand -hex 32  # For JWT_SECRET
openssl rand -hex 16  # For JUPYTERHUB_API_TOKEN
openssl rand -base64 32  # For POSTGRES_PASSWORD
```

Update in `compose.yaml`:
```yaml
JWT_SECRET: "<your-generated-secret>"
JUPYTERHUB_API_TOKEN: "<your-generated-token>"
POSTGRES_PASSWORD: "<your-generated-password>"
```

#### 2. Enable HTTPS/SSL

**Option A: Use Nginx Reverse Proxy**
```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:3000;
    }
    
    location /api/ {
        proxy_pass http://localhost:8080;
    }
    
    location /hub/ {
        proxy_pass http://localhost:8000;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Host $host;
    }
}
```

**Option B: Use Let's Encrypt**
```bash
# Install certbot
apt install certbot python3-certbot-nginx

# Generate certificate
certbot --nginx -d your-domain.com
```

#### 3. Firewall Configuration

```bash
# Allow only necessary ports
ufw allow 443/tcp   # HTTPS
ufw allow 22/tcp    # SSH
ufw deny 8080/tcp   # Block direct backend access
ufw deny 8000/tcp   # Block direct JupyterHub access
ufw enable
```

#### 4. Database Security

```bash
# In compose.yaml, don't expose PostgreSQL port externally
# Remove this line in production:
ports:
  - "5432:5432"  # DELETE THIS!

# Keep database internal:
# (no ports section = only accessible within Docker network)
```

#### 5. Rate Limiting

Add to backend (in `main.go`):
```go
import "github.com/gin-contrib/ratelimit"

// Limit to 100 requests per minute per IP
store := ratelimit.NewInMemoryStore(100, time.Minute)
r.Use(ratelimit.RateLimiter(store, &ratelimit.Options{
    ErrorHandler: func(c *gin.Context, info ratelimit.Info) {
        c.JSON(429, gin.H{"error": "Too many requests"})
    },
}))
```

#### 6. Security Headers

Add to backend responses:
```go
r.Use(func(c *gin.Context) {
    c.Header("X-Content-Type-Options", "nosniff")
    c.Header("X-Frame-Options", "DENY")
    c.Header("X-XSS-Protection", "1; mode=block")
    c.Header("Strict-Transport-Security", "max-age=31536000")
    c.Next()
})
```

#### 7. Regular Updates

```bash
# Update Docker images monthly
docker compose pull
docker compose up -d

# Update Go dependencies
cd backend && go get -u ./...

# Update Python packages
pip install --upgrade jupyterhub dockerspawner jupyterhub-idle-culler
```

### JWT Token Security

**Token Expiration:**
- Login tokens: 24 hours (adjustable in `backend/auth.go`)
- SSO tokens: 5 minutes (short-lived for security)

**Token Validation:**
- Signature verified on every request
- Shared secret between backend and JupyterHub
- Tokens cannot be forged without secret

**Best Practices:**
- Never log tokens
- Don't store tokens in localStorage (use httpOnly cookies)
- Rotate JWT_SECRET periodically
- Use short expiration times

---

## 🔧 Troubleshooting

### Problem: JupyterHub won't spawn containers

**Symptoms:**
- "Spawn failed" error in browser
- Logs show "network not found" or "permission denied"

**Solutions:**

1. **Check Docker socket permissions:**
```bash
# Inside JupyterHub container
docker compose exec jupyterhub ls -la /var/run/docker.sock
# Should show: srw-rw---- 1 root docker

# Fix permissions:
sudo chmod 666 /var/run/docker.sock  # Quick fix
# OR
sudo usermod -aG docker $USER  # Permanent fix
```

2. **Verify Docker network exists:**
```bash
docker network ls | grep jupyterhub
# Should show: jupyterhub_jupyterhub-network

# If missing, recreate:
docker compose down
docker compose up -d
```

3. **Check DockerSpawner configuration:**
```bash
docker compose logs jupyterhub | grep -i "spawn\|error"
```

### Problem: SSO redirect loop (keeps returning to login)

**Symptoms:**
- Token-login URL works but redirects back to `/hub/login`
- Cookie not being set

**Solutions:**

1. **Verify JWT_SECRET matches:**
```bash
# Check backend
docker compose exec backend env | grep JWT_SECRET

# Check JupyterHub
docker compose exec jupyterhub env | grep JWT_SECRET

# They must be identical!
```

2. **Check user exists in database:**
```bash
docker compose exec jupyterhub-db psql -U postgres -d postgres \
  -c "SELECT * FROM backend.users WHERE username='your-username';"
```

3. **View token-login handler logs:**
```bash
docker compose logs jupyterhub | grep -i "token-login"
```

### Problem: Backend can't connect to database

**Symptoms:**
- Backend logs show "connection refused" or "authentication failed"
- `/api/v1/register` returns 500 error

**Solutions:**

1. **Verify PostgreSQL is running:**
```bash
docker compose ps jupyterhub-db
# Status should be "Up"

# Check logs:
docker compose logs jupyterhub-db
```

2. **Test database connection:**
```bash
docker compose exec jupyterhub-db psql -U postgres -d postgres -c "SELECT 1;"
# Should return: 1
```

3. **Check connection string:**
```bash
docker compose exec backend env | grep DB_
# Verify all DB_* variables are correct
```

4. **Restart services:**
```bash
docker compose restart backend jupyterhub-db
```

### Problem: Frontend can't reach backend

**Symptoms:**
- Login button does nothing
- Browser console shows CORS error or network error

**Solutions:**

1. **Check CORS configuration in backend:**
```go
// In backend/main.go, should have:
r.Use(cors.New(cors.Config{
    AllowOrigins:     []string{"http://localhost:3000"},
    AllowMethods:     []string{"GET", "POST", "PUT", "DELETE"},
    AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
    AllowCredentials: true,
}))
```

2. **Verify backend is running:**
```bash
curl http://localhost:8080/health
# Should return: {"status": "ok"}
```

3. **Check frontend API URL:**
```javascript
// In frontend code, should use:
const API_URL = "http://localhost:8080/api/v1";
```

### Problem: Container memory/CPU limits exceeded

**Symptoms:**
- Notebook kernel keeps restarting
- Container disappears unexpectedly
- Slow performance

**Solutions:**

1. **Check current resource usage:**
```bash
docker stats --no-stream | grep jupyter
```

2. **Increase limits in `jupyterhub_config.py`:**
```python
c.DockerSpawner.mem_limit = '4G'  # Increase from 2G
c.DockerSpawner.cpu_limit = 2.0   # Increase from 1.0
```

3. **Restart JupyterHub:**
```bash
docker compose restart jupyterhub
```

### Problem: 403 Forbidden when starting Jupyter

**Symptoms:**
- New user registers and logs in successfully
- Clicking "Start Jupyter" shows: **403: Forbidden**
- Error messages in JupyterHub logs:
  - `403 POST /hub/api/users/{username}: Missing or invalid credentials`
  - `Action is not authorized with current scopes; requires any of [servers]`

**Root Causes:**
1. **Missing environment variable**: `JUPYTERHUB_API_TOKEN` not set in JupyterHub service
2. **Missing API token scopes**: Token not properly configured with required permissions

**Solutions:**

**STEP 1: Verify Environment Variable in `compose.yaml`**

The JupyterHub service MUST have the `JUPYTERHUB_API_TOKEN` environment variable:

```yaml
jupyterhub:
  environment:
    DOCKER_NETWORK_NAME: jupyterhub_jupyterhub-network
    POSTGRES_HOST: postgres
    POSTGRES_DB: jupyterhub
    POSTGRES_USER: jupyterhub
    POSTGRES_PASSWORD: your-password
    JWT_SECRET: your-jwt-secret
    JUPYTERHUB_API_TOKEN: your-api-token  # ← MUST BE SET!
```

**Important**: The token must be the **same value** in both backend and JupyterHub services.

**STEP 2: Verify API token service is configured in `jupyterhub_config.py`:**
```python
c.JupyterHub.services = [
    {
        'name': 'backend-api',
        'api_token': os.environ.get('JUPYTERHUB_API_TOKEN'),  # Reads from environment
    }
]
```

**STEP 3: Ensure roles with proper scopes are defined:**
```python
c.JupyterHub.load_roles = [
    {
        'name': 'backend-api-role',
        'scopes': [
            'admin:users',      # Required to create users
            'admin:servers',    # Required to start/stop servers
            'read:users',       # Required to read user info
            'read:servers',     # Required to read server info
            'servers',          # Required for server operations
            'access:servers',   # Required to spawn servers
        ],
        'services': ['backend-api'],
    }
]
```

**STEP 4: Verify `allow_all` is enabled:**
```python
c.Authenticator.allow_all = True
```

**STEP 5: Restart JupyterHub with clean state:**
```bash
# Stop and remove JupyterHub
docker compose down jupyterhub

# Remove old data volume (clears proxy pid issues)
docker volume rm jupyterhub_jupyterhub_data

# Restart JupyterHub
docker compose up -d jupyterhub
```

**STEP 6: Verify everything is working:**

```bash
# 1. Check environment variable is set
docker compose exec jupyterhub env | grep JUPYTERHUB_API_TOKEN
# Should output: JUPYTERHUB_API_TOKEN=your-token-value

# 2. Check service is registered
docker compose logs jupyterhub | grep -i "backend-api"
# Should see: "Adding API token for service: backend-api"

# 3. Check JupyterHub is running
docker compose logs jupyterhub | grep "JupyterHub is now running"
# Should see: "JupyterHub is now running at http://0.0.0.0:8000/"

# 4. Test API token manually
curl -X POST http://localhost:8000/hub/api/users/testuser \
  -H "Authorization: token YOUR_API_TOKEN"
# Should create user successfully (returns JSON with user info)
```

**Common Mistakes:**
- ❌ Forgetting to add `JUPYTERHUB_API_TOKEN` to JupyterHub environment variables
- ❌ Using different token values in backend vs JupyterHub
- ❌ Not restarting JupyterHub after configuration changes
- ❌ Old proxy pid file preventing restart (solved by removing volume)

**Note:** This is a common issue when migrating from older JupyterHub versions or when API tokens are configured incorrectly. The token must be:
1. Set as an environment variable in the JupyterHub container
2. Registered as a service in `jupyterhub_config.py`
3. Associated with proper role-based scopes

### Problem: Idle culler not working

**Symptoms:**
- Containers stay running after hours of inactivity
- Resources not being freed

**Solutions:**

1. **Check idle-culler service is running:**
```bash
docker compose logs jupyterhub | grep -i "idle-culler"
# Should see: "Creating service idle-culler"
```

2. **Verify culler configuration:**
```bash
docker compose exec jupyterhub cat /srv/jupyterhub/jupyterhub_config.py | grep -A 15 "idle-culler"
```

3. **Manually trigger cleanup:**
```bash
# List idle servers
docker compose exec jupyterhub jupyterhub token --help

# Force stop a server
curl -X DELETE http://localhost:8000/hub/api/users/{username}/server \
  -H "Authorization: token <JUPYTERHUB_API_TOKEN>"
```

### Getting Help

**Collect diagnostic information:**
```bash
# Save all logs
docker compose logs > debug-logs.txt

# Show system info
docker info > system-info.txt
docker compose config > config.txt

# List all containers and volumes
docker ps -a > containers.txt
docker volume ls > volumes.txt
```

**Common log locations:**
- Backend: `docker compose logs backend`
- JupyterHub: `docker compose logs jupyterhub`
- Database: `docker compose logs jupyterhub-db`
- Frontend: `docker compose logs frontend`

---

## 📚 For Learners

### Understanding the System Components

#### 1. **What is JWT (JSON Web Token)?**

JWT is a secure way to transmit information between parties. In our system:

```
Header.Payload.Signature
eyJhbGc...  .  eyJ1c2Vy...  .  SflKxwRJ...
```

**Structure:**
- **Header**: Algorithm used (HS256)
- **Payload**: User data (username, expiration)
- **Signature**: Cryptographic signature to verify authenticity

**Why we use it:**
- Stateless authentication (no server-side sessions)
- Can be validated by multiple services (backend + JupyterHub)
- Expires automatically (5 minutes for SSO tokens)
- Cannot be tampered with (signature verification)

**Example JWT payload:**
```json
{
  "username": "john_doe",
  "exp": 1729598400,  // Expiration timestamp
  "iat": 1729598100   // Issued at timestamp
}
```

#### 2. **What is SSO (Single Sign-On)?**

SSO allows users to log in once and access multiple systems without re-entering credentials.

**Traditional flow (without SSO):**
```
Login to Frontend → Access JupyterHub → Login again to JupyterHub ❌
```

**Our SSO flow:**
```
Login to Frontend → Access JupyterHub → Already logged in ✅
```

**How we achieve it:**
1. User authenticates with backend (username + password)
2. Backend generates JWT token with user identity
3. Backend returns special URL with token embedded
4. JupyterHub validates token and sets authentication cookie
5. User is now logged into JupyterHub (no password needed)

#### 3. **What is Docker Spawner?**

DockerSpawner is a JupyterHub plugin that creates isolated Docker containers for each user.

**Without DockerSpawner:**
- All users share same Jupyter server
- Can see each other's files
- One user can crash server for everyone

**With DockerSpawner:**
- Each user gets their own container
- Complete isolation (separate filesystem, processes)
- Resource limits prevent one user affecting others
- Container destroyed when not needed (saves resources)

**Container lifecycle:**
```
User requests Jupyter
    ↓
DockerSpawner pulls image (if needed)
    ↓
Creates container with user's volume
    ↓
Starts JupyterLab inside container
    ↓
User works in isolation
    ↓
After idle timeout, container stopped
    ↓
Volume persists (notebooks saved)
```

#### 4. **What is the Idle Culler?**

The Idle Culler is a background service that monitors notebook servers and stops inactive ones.

**Problem it solves:**
- Users open JupyterLab and forget to close it
- Containers keep running, consuming RAM/CPU
- Eventually run out of resources for new users

**How it works:**
```python
while True:
    for server in all_running_servers:
        if server.last_activity > 1_hour_ago:
            stop_server(server)
            free_resources()
    sleep(10_minutes)
```

**Why 1 hour timeout:**
- Balance between user convenience and resource efficiency
- Long enough for coffee breaks
- Short enough to free resources daily
- Configurable based on your needs

#### 5. **Understanding the Database Schema**

**`backend.users` table:**
```sql
id       | username  | email          | password (hashed)           | created_at
---------|-----------|----------------|-----------------------------|-----------
1        | john_doe  | john@email.com | $2a$10$encrypted_hash_here      | 2025-10-22
2        | jane_doe  | jane@email.com | $2a$10$another_encrypted_hash  | 2025-10-22
```

**Why we hash passwords:**
- Never store passwords in plain text
- If database is compromised, passwords are safe
- Bcrypt is slow on purpose (prevents brute force attacks)
- Even admins can't see user passwords

**`backend.jupyter_sessions` table:**
```sql
id | user_id | jupyterhub_url                    | status  | started_at          | stopped_at
---|---------|-----------------------------------|---------|---------------------|------------
1  | 1       | http://localhost:8000/user/john   | running | 2025-10-22 10:00:00 | NULL
2  | 2       | http://localhost:8000/user/jane   | stopped | 2025-10-22 09:00:00 | 2025-10-22 10:30:00
```

**Why track sessions:**
- Know which users have active notebooks
- Generate usage reports
- Cleanup orphaned sessions
- Debug connection issues

### Learning Exercises

#### Exercise 1: Trace the Authentication Flow

1. Register a new user and watch the logs:
```bash
# Terminal 1: Watch backend logs
docker compose logs -f backend

# Terminal 2: Register user
curl -X POST http://localhost:8080/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{"username":"learner1","email":"learner1@test.com","password":"test123"}'
```

**What to observe:**
- SQL INSERT statement in backend logs
- Password hash generation
- Database connection

2. Login and decode the JWT:
```bash
# Login
TOKEN=$(curl -X POST http://localhost:8080/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"username":"learner1","password":"test123"}' \
  | jq -r .token)

# Decode JWT (visit jwt.io and paste token)
echo $TOKEN
```

**What to observe:**
- Token structure (three parts separated by dots)
- Payload contains username
- Expiration time (exp field)

#### Exercise 2: Monitor Resource Usage

```bash
# Start Jupyter for a user
# (via frontend or API)

# Watch container resources
docker stats --no-stream

# Check memory limit
docker inspect jupyter-learner1 | grep -i memory

# Check CPU limit
docker inspect jupyter-learner1 | grep -i cpu
```

**What to observe:**
- Memory usage stays below 2GB limit
- Multiple containers can run simultaneously
- Each container isolated

#### Exercise 3: Test Idle Timeout

```bash
# Modify timeout to 1 minute for testing
# In jupyterhub_config.py:
'--timeout=60',  # 1 minute instead of 3600

# Rebuild JupyterHub
docker compose up -d --build jupyterhub

# Start Jupyter and wait 2 minutes
# Watch container disappear:
watch -n 5 "docker ps | grep jupyter"
```

**What to observe:**
- Container exists initially
- After idle timeout + cull interval, container stops
- Volume persists (check with `docker volume ls`)

#### Exercise 4: Understand Docker Networks

```bash
# Inspect the network
docker network inspect jupyterhub_jupyterhub-network

# See all containers on network
docker network inspect jupyterhub_jupyterhub-network \
  | jq '.[0].Containers'
```

**What to observe:**
- JupyterHub container connected
- All user containers connected
- Allows containers to communicate by name

### Key Concepts Summary

| Concept | Purpose | Benefit |
|---------|---------|---------|
| **JWT Tokens** | Stateless authentication | No server-side sessions needed |
| **SSO** | Single login for multiple systems | Better user experience |
| **Docker Isolation** | Separate containers per user | Security and resource control |
| **Resource Limits** | Cap memory/CPU per container | Fair resource distribution |
| **Idle Culler** | Auto-stop inactive servers | Efficient resource usage |
| **Persistent Volumes** | Save user data across restarts | Work is never lost |
| **Bcrypt Hashing** | Secure password storage | Protection against breaches |

### Next Steps for Learning

1. **Understand JupyterHub internals:**
   - Read: https://jupyterhub.readthedocs.io/
   - Learn about Authenticators, Spawners, and Proxies

2. **Study Docker networking:**
   - How containers communicate
   - Network isolation and security
   - Volume management

3. **Deep dive into JWT:**
   - Try different signing algorithms
   - Implement refresh tokens
   - Add additional claims (roles, permissions)

4. **Explore Go backend:**
   - Study Gin framework
   - Learn middleware patterns
   - Practice error handling

5. **Production deployment:**
   - Set up monitoring (Prometheus + Grafana)
   - Implement logging (ELK stack)
   - Add backup automation
   - Configure high availability

---

## 📖 Additional Documentation

- **[SSO_TESTING.md](./SSO_TESTING.md)** - Step-by-step guide for testing the SSO authentication flow
- **[RESOURCE_MANAGEMENT.md](./RESOURCE_MANAGEMENT.md)** - Detailed explanation of resource limits and idle timeout configuration

---

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

---

## 📄 License

MIT License - Feel free to use this project for learning or production purposes.

---

## 🙏 Acknowledgments

- **JupyterHub** - Multi-user notebook server
- **DockerSpawner** - Container orchestration
- **Gin** - Go web framework
- **PostgreSQL** - Database system

---

## 📧 Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review logs: `docker compose logs`
3. Open an issue on GitHub
4. Refer to official documentation

---

**Built with ❤️ for data science teams, educational platforms, and research institutions.**