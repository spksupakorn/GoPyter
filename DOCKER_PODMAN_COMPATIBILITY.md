# Docker & Podman Compatibility Guide

GoPyter is designed to work seamlessly with **both Docker and Podman** without requiring separate configurations or manual adjustments.

## 🎯 How It Works

The system automatically:
1. **Detects** which container runtime you're using (Docker or Podman)
2. **Configures** the correct network name based on the project folder
3. **Maps** the appropriate socket path for your runtime
4. **Adapts** to platform differences (Linux, Windows, macOS)

## 🚀 Quick Start (Universal)

### Recommended: Use the Universal Startup Script

**Windows (PowerShell):**
```powershell
.\start.ps1
```

**Linux/Mac:**
```bash
chmod +x start.sh
./start.sh
```

The script will:
- ✅ Detect Docker or Podman automatically
- ✅ Check if the daemon/machine is running
- ✅ Configure the correct network name
- ✅ Start all services
- ✅ Display service URLs

### Manual Start

You can also use the native commands:

**With Docker:**
```bash
docker compose up -d --build
```

**With Podman:**
```bash
podman-compose up -d --build
```

## 🔧 Technical Details

### Network Name Auto-Detection

The configuration uses the `COMPOSE_PROJECT_NAME` environment variable:

```yaml
environment:
  DOCKER_NETWORK_NAME: ${COMPOSE_PROJECT_NAME:-gopyter}_jupyterhub-network
```

This automatically resolves to:
- **Docker Compose v2**: `gopyter_jupyterhub-network`
- **Podman Compose**: `gopyter_jupyterhub-network`
- **Custom project**: `yourproject_jupyterhub-network`

### Socket Mapping

The socket mount works for both runtimes:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:z
```

**How it works:**
- **Docker**: Direct socket mount (`/var/run/docker.sock`)
- **Podman (Linux)**: Symlink or direct socket (`/var/run/docker.sock` → `/run/podman/podman.sock`)
- **Podman (Windows/Mac)**: Podman machine automatically maps the socket
- **SELinux**: The `:z` flag ensures proper context labeling

### API Version Compatibility

JupyterHub's DockerSpawner auto-negotiates the API version:

```python
c.DockerSpawner.client_kwargs = {'version': 'auto'}
```

This works with:
- Docker API v1.41+
- Podman API (Docker-compatible)

## 🔄 Switching Between Docker and Podman

You can switch runtimes without changing any configuration:

### From Docker to Podman:
```bash
# Stop Docker containers
docker compose down

# Install Podman
# (see https://podman-desktop.io/downloads)

# Start with Podman
podman-compose up -d
```

### From Podman to Docker:
```bash
# Stop Podman containers
podman-compose down

# Install Docker
# (see https://www.docker.com/products/docker-desktop)

# Start with Docker
docker compose up -d
```

The same `compose.yaml` works for both!

## 🌐 Network Compatibility

Both runtimes create compatible networks:

```bash
# Docker
docker network ls
# Output: gopyter_jupyterhub-network

# Podman
podman network ls
# Output: gopyter_jupyterhub-network
```

The spawned user containers can communicate with all services (PostgreSQL, Backend, etc.) regardless of runtime.

## 📋 Feature Compatibility Matrix

| Feature | Docker | Podman | Notes |
|---------|--------|--------|-------|
| Container spawning | ✅ | ✅ | Both work identically |
| Custom networks | ✅ | ✅ | Auto-detected naming |
| Volume mounting | ✅ | ✅ | Same syntax |
| Resource limits | ✅ | ✅ | CPU/Memory limits work |
| Privileged mode | ✅ | ✅ | Required for spawning |
| Socket access | ✅ | ✅ | Auto-mapped |
| Health checks | ✅ | ✅ | Compose syntax works |
| Build cache | ✅ | ✅ | Similar performance |
| Rootless mode | ⚠️ | ✅ | Podman-specific feature |
| Windows support | ✅ | ✅ | Via Docker Desktop or Podman Machine |
| macOS support | ✅ | ✅ | Via Docker Desktop or Podman Machine |
| Linux support | ✅ | ✅ | Native on both |

Legend: ✅ Fully supported | ⚠️ Limited/requires root | ❌ Not supported

## 🐛 Runtime-Specific Troubleshooting

### Docker Issues

**Problem:** "Cannot connect to Docker daemon"
```bash
# Windows/Mac: Start Docker Desktop
# Linux: Start Docker service
sudo systemctl start docker
```

**Problem:** "Port already in use"
```bash
# Find what's using the port
docker ps
# Stop conflicting containers
docker stop <container_name>
```

### Podman Issues

**Problem:** "Podman machine not running" (Windows/Mac)
```bash
podman machine start
```

**Problem:** "Socket permission denied" (Linux)
```bash
# Enable rootless socket
systemctl --user enable --now podman.socket
```

### Both Runtimes

**Problem:** "Network not found"
```bash
# Check actual network name
docker network ls  # or: podman network ls

# Restart services to recreate network
docker compose restart  # or: podman-compose restart
```

## 🔍 Verification Commands

### Check which runtime you're using:
```bash
# Check for Docker
docker --version && docker ps

# Check for Podman
podman --version && podman ps
```

### Verify network configuration:
```bash
# Docker
docker network inspect gopyter_jupyterhub-network

# Podman
podman network inspect gopyter_jupyterhub-network
```

### Test spawner can access socket:
```bash
# Docker
docker exec jupyterhub docker ps

# Podman
podman exec jupyterhub docker ps
# (Yes, 'docker' command works inside Podman containers!)
```

## 💡 Best Practices

### 1. Use the Universal Startup Script
Always use `start.ps1` (Windows) or `start.sh` (Linux/Mac) for hassle-free setup.

### 2. Set COMPOSE_PROJECT_NAME (Optional)
For custom project names:
```bash
export COMPOSE_PROJECT_NAME="myproject"
docker compose up -d
```

### 3. Keep Compose Syntax Compatible
When modifying `compose.yaml`, ensure compatibility:
- ✅ Use standard Compose v3.8 syntax
- ✅ Avoid Docker-specific extensions
- ✅ Test with both runtimes if possible

### 4. Document Runtime Choice
In production, document which runtime you're using:
```bash
# Create a marker file
echo "docker" > .container-runtime  # or "podman"
```

## 🎓 Why This Matters

### For Users:
- **Flexibility**: Choose your preferred container runtime
- **No lock-in**: Easy to switch between Docker and Podman
- **Compatibility**: Works on any platform

### For Developers:
- **Single codebase**: Maintain one configuration
- **Easier testing**: Test with both runtimes
- **Future-proof**: Not tied to a specific vendor

### For Organizations:
- **Cost savings**: Podman is free and open source
- **Security**: Podman's rootless mode for better isolation
- **Compliance**: More control over container runtime choice

## 🔗 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Podman Documentation](https://docs.podman.io/)
- [Docker to Podman Migration](https://docs.podman.io/en/latest/markdown/podman.1.html#docker-compatibility)
- [Compose Specification](https://compose-spec.io/)

## 📝 Summary

**GoPyter is fully compatible with both Docker and Podman:**

✅ **No manual configuration required**  
✅ **Automatic runtime detection**  
✅ **Same compose.yaml for both**  
✅ **Platform-independent**  
✅ **Easy to switch between runtimes**

Just run `./start.ps1` or `./start.sh` and you're good to go! 🚀
