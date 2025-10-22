# Podman Compatibility Guide for GoPyter

This document explains the adjustments made for Podman compatibility and how to properly run the GoPyter system with Podman instead of Docker.

## Key Differences Between Podman and Docker

1. **Network Naming**: Podman Compose prefixes network names with the folder name
   - Docker: `jupyterhub-network`
   - Podman: `gopyter_jupyterhub-network` (folder name + network name)

2. **Socket Location**: Podman uses a different socket path
   - Docker: `/var/run/docker.sock`
   - Podman (Linux): `/run/podman/podman.sock`
   - Podman (Windows): Named pipe or TCP socket

3. **Rootless Mode**: Podman can run rootless, but JupyterHub spawning requires special handling

## Changes Made for Podman Compatibility

### 1. Network Name Configuration
Updated `compose.yaml` to use the correct network name:
```yaml
environment:
  DOCKER_NETWORK_NAME: gopyter_jupyterhub-network
```

### 2. Socket Mounting
Modified the JupyterHub service to mount the Podman socket:
```yaml
volumes:
  - /run/podman/podman.sock:/var/run/docker.sock:z
```
The `:z` flag is important for SELinux contexts in Podman.

### 3. Privileged Mode
Added `privileged: true` to JupyterHub to allow container spawning:
```yaml
privileged: true
```

### 4. Docker Host Environment Variable
Set the DOCKER_HOST to ensure DockerSpawner uses the correct socket:
```yaml
environment:
  DOCKER_HOST: unix:///var/run/docker.sock
```

## Platform-Specific Setup

### Windows with Podman Machine

1. Ensure Podman machine is running:
   ```powershell
   podman machine list
   podman machine start
   ```

2. Enable Podman socket (if not already enabled):
   ```powershell
   podman machine ssh
   sudo systemctl enable --now podman.socket
   exit
   ```

3. The compose file should work with the mounted socket inside the VM.

### Linux with Podman

1. Enable and start Podman socket:
   ```bash
   systemctl --user enable --now podman.socket
   ```

2. Make sure the socket is accessible:
   ```bash
   ls -l /run/podman/podman.sock
   ```

3. Run with rootless Podman:
   ```bash
   podman-compose up -d
   ```

## Verification Steps

1. **Check Network Creation**:
   ```bash
   podman network ls
   ```
   Should show: `gopyter_jupyterhub-network`

2. **Verify JupyterHub Can Access Socket**:
   ```bash
   podman exec jupyterhub ls -l /var/run/docker.sock
   ```

3. **Test Container Spawning**:
   - Log in to JupyterHub at http://localhost:8000
   - Start a server
   - Check if the user container is created:
     ```bash
     podman ps | grep jupyter-
     ```

## Troubleshooting

### Error: "network not found"
**Symptom**: `unable to find network with name or ID jupyterhub_jupyterhub-network`

**Solution**: Update `DOCKER_NETWORK_NAME` in compose.yaml to match your actual network name:
```bash
podman network ls  # Find the actual network name
```

### Error: "permission denied" when accessing socket
**Symptom**: JupyterHub cannot create containers

**Solutions**:
1. Run with `privileged: true` in compose.yaml
2. For rootless Podman, ensure user has permissions:
   ```bash
   sudo usermod -aG podman $USER
   ```
3. Use correct SELinux context (`:z` flag in volume mount)

### Error: "API version mismatch"
**Symptom**: Docker client version incompatibility

**Solution**: DockerSpawner should auto-negotiate, but you can set explicitly in `jupyterhub_config.py`:
```python
c.DockerSpawner.client_kwargs = {'version': 'auto'}
```

### Spawned Containers Cannot Reach Network
**Symptom**: User notebooks can't connect to services

**Solution**: Ensure spawned containers use the same network:
- Already configured in `jupyterhub_config.py`:
  ```python
  c.DockerSpawner.network_name = os.environ.get('DOCKER_NETWORK_NAME', 'gopyter_jupyterhub-network')
  ```

## Performance Considerations

1. **Volume Performance**: Podman volumes may have different performance characteristics
   - Use native volumes instead of bind mounts where possible
   - For Windows, consider performance impact of VM layer

2. **Resource Limits**: Podman handles cgroups differently
   - Memory and CPU limits work similarly but may behave differently in rootless mode
   - Test resource limits: `podman stats`

3. **Container Startup Time**: Podman may have slightly different startup times
   - Adjust `c.DockerSpawner.start_timeout` if needed (currently 60 seconds default)

## Security Benefits of Podman

1. **Rootless by Default**: Improved security without requiring root privileges
2. **No Daemon**: No central daemon running as root
3. **Better SELinux Integration**: Native support for SELinux contexts
4. **Fork/Exec Model**: Each container runs as a separate process

## Migration from Docker

If migrating an existing Docker setup:

1. Stop all Docker containers
2. Export volumes if needed:
   ```bash
   docker volume ls
   docker run --rm -v volume_name:/data -v $(pwd):/backup alpine tar czf /backup/volume_backup.tar.gz -C /data .
   ```
3. Import to Podman volumes if needed
4. Update compose.yaml with Podman-specific changes (as documented above)
5. Run with podman-compose

## Additional Resources

- [Podman Documentation](https://docs.podman.io/)
- [Podman Compose](https://github.com/containers/podman-compose)
- [JupyterHub DockerSpawner](https://jupyterhub-dockerspawner.readthedocs.io/)
- [Podman Desktop](https://podman-desktop.io/) - GUI alternative to Docker Desktop

## Known Limitations

1. **BuildKit Support**: Podman build doesn't fully support all BuildKit features
2. **Compose Compatibility**: Some Docker Compose features may not work identically
3. **Windows Named Pipes**: Named pipe support may differ from Docker Desktop
4. **Mac Support**: Podman Desktop for Mac is newer and may have different behaviors

## Support

For issues specific to this setup:
- Check JupyterHub logs: `podman-compose logs jupyterhub`
- Check spawner logs: `podman logs jupyter-<username>`
- Verify network: `podman network inspect gopyter_jupyterhub-network`
