# Podman Troubleshooting Guide

This guide helps you troubleshoot common issues when running GoPyter with Podman.

## Quick Diagnostics

Run these commands to check your setup:

```bash
# Check Podman version
podman --version

# Check Podman machine status (Windows/Mac)
podman machine list

# Check running containers
podman ps

# Check networks
podman network ls

# Check logs for specific service
podman-compose -f compose.yaml logs [service-name]
```

## Common Issues and Solutions

### 1. Network Not Found Error

**Symptom:**
```
Error: unable to find network with name or ID jupyterhub_jupyterhub-network: network not found
```

**Cause:** Podman uses different network naming (folder name prefix).

**Solution:**
1. Check actual network name:
   ```bash
   podman network ls
   ```
2. Update `DOCKER_NETWORK_NAME` in `compose.yaml` to match (e.g., `gopyter_jupyterhub-network`)
3. Restart JupyterHub:
   ```bash
   podman-compose -f compose.yaml restart jupyterhub
   ```

### 2. Socket Permission Denied

**Symptom:**
```
Error: Got permission denied while trying to connect to the Docker daemon socket
```

**Cause:** JupyterHub container cannot access Podman socket.

**Solution (Linux):**
```bash
# Enable Podman socket
systemctl --user enable --now podman.socket

# Check socket permissions
ls -l /run/podman/podman.sock

# Add SELinux context to volume mount (already in compose.yaml)
# volumes:
#   - /run/podman/podman.sock:/var/run/docker.sock:z
```

**Solution (Windows/Mac):**
```powershell
# Make sure Podman machine is running
podman machine start

# Restart containers
podman-compose -f compose.yaml restart jupyterhub
```

### 3. Container Already Exists

**Symptom:**
```
Error: container already exists
```

**Solution:**
```bash
# Remove existing containers
podman-compose -f compose.yaml down

# Or force remove specific container
podman rm -f container-name

# Start fresh
podman-compose -f compose.yaml up -d
```

### 4. JupyterHub Cannot Spawn User Containers

**Symptom:**
- 500 Internal Server Error when starting Jupyter
- "Unhandled error starting server" message
- Logs show: `unable to find network` or `permission denied`

**Solution:**

**Step 1:** Verify network configuration
```bash
# Check if network exists
podman network ls | grep jupyterhub

# Inspect network
podman network inspect gopyter_jupyterhub-network
```

**Step 2:** Check JupyterHub can access socket
```bash
# Enter JupyterHub container
podman exec -it jupyterhub bash

# Inside container, check socket
ls -l /var/run/docker.sock

# Try to list networks
docker network ls
```

**Step 3:** Verify privileged mode (should be in compose.yaml)
```yaml
jupyterhub:
  privileged: true  # This line is important
```

**Step 4:** Check spawner configuration
```bash
podman exec jupyterhub cat /srv/jupyterhub/jupyterhub_config.py | grep network_name
# Should output: gopyter_jupyterhub-network
```

**Step 5:** Restart with full rebuild
```bash
podman-compose -f compose.yaml down
podman-compose -f compose.yaml up -d --build
```

### 5. Podman Machine Not Running (Windows/Mac)

**Symptom:**
```
Error: cannot connect to Podman
```

**Solution:**
```powershell
# Check machine status
podman machine list

# Start machine
podman machine start

# If machine doesn't exist, create one
podman machine init
podman machine start

# Set as default
podman machine set --default podman-machine-default
```

### 6. API Version Mismatch

**Symptom:**
```
docker.errors.InvalidVersion: API version is too old
```

**Solution:**
The config already has auto-negotiation:
```python
c.DockerSpawner.client_kwargs = {'version': 'auto'}
```

If still failing, manually check:
```bash
# Check Podman API version
podman version

# Inside JupyterHub container
podman exec jupyterhub python -c "import docker; print(docker.from_env().version())"
```

### 7. Volume Mount Issues

**Symptom:**
- Files not appearing in containers
- Permission errors on mounted files

**Solution (Linux with SELinux):**
```bash
# Use :z flag for SELinux contexts (already in compose.yaml)
volumes:
  - /run/podman/podman.sock:/var/run/docker.sock:z
```

**Solution (Windows/Mac):**
```powershell
# Ensure path exists in Podman machine
podman machine ssh
ls -l /run/podman/podman.sock
exit

# If missing, restart machine
podman machine stop
podman machine start
```

### 8. User Container Cannot Connect to Database

**Symptom:**
- Spawned Jupyter notebook cannot connect to PostgreSQL
- Network timeout errors

**Solution:**
Ensure spawned containers use the same network (already configured):
```python
# In jupyterhub_config.py
c.DockerSpawner.network_name = os.environ.get('DOCKER_NETWORK_NAME', 'gopyter_jupyterhub-network')
c.DockerSpawner.extra_host_config = {
    'network_mode': os.environ.get('DOCKER_NETWORK_NAME', 'gopyter_jupyterhub-network')
}
```

Verify network connectivity:
```bash
# From inside user container
podman exec jupyter-<username> ping postgres
```

### 9. Idle Culler Service Not Working

**Symptom:**
- Containers not being stopped after idle period
- Idle culler service crashes

**Solution:**
```bash
# Check idle culler logs
podman exec jupyterhub journalctl -u idle-culler

# Or check JupyterHub logs for idle-culler messages
podman logs jupyterhub | grep idle-culler

# Restart if needed
podman-compose -f compose.yaml restart jupyterhub
```

### 10. Port Already in Use

**Symptom:**
```
Error: cannot listen on the TCP port: address already in use
```

**Solution:**
```bash
# Find process using port (Windows)
netstat -ano | findstr :8000

# Find process using port (Linux/Mac)
lsof -i :8000

# Kill process or change port in compose.yaml
```

## Verification Checklist

After fixing issues, verify everything works:

- [ ] Podman machine is running (Windows/Mac)
- [ ] All containers are running: `podman ps`
- [ ] Network exists: `podman network ls | grep jupyterhub`
- [ ] JupyterHub is accessible: http://localhost:8000
- [ ] Backend API is accessible: http://localhost:8080/health
- [ ] Frontend is accessible: http://localhost:3000
- [ ] Can log in to frontend
- [ ] Can spawn Jupyter server successfully
- [ ] Jupyter notebook can access internet
- [ ] Idle timeout works (optional, wait 1 hour)

## Debug Mode

Enable more verbose logging:

**For JupyterHub:**
```python
# In jupyterhub_config.py
c.JupyterHub.log_level = 'DEBUG'
c.Spawner.log_level = 'DEBUG'
c.DockerSpawner.debug = True
```

**For Backend:**
```yaml
# In compose.yaml backend service
environment:
  GIN_MODE: debug  # Change from 'release'
```

**View logs:**
```bash
# Follow all logs
podman-compose -f compose.yaml logs -f

# Follow specific service
podman-compose -f compose.yaml logs -f jupyterhub

# Save logs to file
podman-compose -f compose.yaml logs > gopyter-logs.txt
```

## Performance Optimization

### If containers are slow to start:

1. **Increase timeout:**
   ```python
   # In jupyterhub_config.py
   c.DockerSpawner.start_timeout = 120  # Increase from 60
   ```

2. **Pre-pull images:**
   ```bash
   podman pull jupyter/scipy-notebook:latest
   ```

3. **Use local image cache:**
   ```python
   c.DockerSpawner.pull_policy = 'ifnotpresent'
   ```

### If system is using too much memory:

1. **Reduce user limits:**
   ```python
   c.DockerSpawner.mem_limit = '1G'  # Reduce from 2G
   c.DockerSpawner.cpu_limit = 0.5   # Reduce from 1.0
   ```

2. **Limit concurrent users:**
   ```python
   c.JupyterHub.active_server_limit = 20  # Reduce from 50
   ```

## Getting Help

If you still have issues:

1. **Collect information:**
   ```bash
   podman version > debug-info.txt
   podman-compose version >> debug-info.txt
   podman ps -a >> debug-info.txt
   podman network ls >> debug-info.txt
   podman-compose -f compose.yaml logs >> debug-info.txt
   ```

2. **Check Podman GitHub issues:**
   - https://github.com/containers/podman/issues
   - https://github.com/containers/podman-compose/issues

3. **Check JupyterHub DockerSpawner docs:**
   - https://jupyterhub-dockerspawner.readthedocs.io/

4. **Create an issue with:**
   - Your OS and Podman version
   - Complete error message
   - Relevant logs
   - Steps to reproduce

## Additional Resources

- [Podman Documentation](https://docs.podman.io/)
- [Podman Desktop](https://podman-desktop.io/)
- [Docker to Podman Migration](https://docs.podman.io/en/latest/markdown/podman-compose.1.html)
- [JupyterHub Documentation](https://jupyterhub.readthedocs.io/)
