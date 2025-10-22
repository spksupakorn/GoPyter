# JupyterHub Resource Management Guide

## Overview
Your JupyterHub setup now includes comprehensive resource management for multiple concurrent users with automatic cleanup and resource limits.

---

## Current Resource Configuration

### 1. **Per-User Resource Limits**

Each user gets their own isolated Jupyter container with:
- **Memory Limit**: 2GB RAM per user
- **CPU Limit**: 1 CPU core per user
- **Storage**: Persistent volume (`jupyterhub-user-{username}`)

```python
# In jupyterhub_config.py
c.DockerSpawner.mem_limit = '2G'
c.DockerSpawner.cpu_limit = 1.0
```

### 2. **Automatic Idle Timeout (Idle Culler)**

✅ **Now Active!** Automatically stops inactive servers to free resources.

**Configuration:**
- **Idle Timeout**: 1 hour (3600 seconds)
- **Check Interval**: Every 10 minutes (600 seconds)
- **Behavior**: Stops both idle servers AND culls idle users

```python
'--timeout=3600',      # Stop after 1 hour of inactivity
'--cull-every=600',    # Check every 10 minutes
'--cull-users',        # Remove idle users from active list
```

**What triggers "idle"?**
- No code execution in notebooks
- No browser activity/interaction
- No API calls to the server

**What happens when idle?**
1. After 1 hour of inactivity → Server is stopped
2. Container is removed
3. Resources (CPU/RAM) are freed
4. User data is preserved in persistent volume
5. User can start a new server anytime

### 3. **Concurrent Usage Limits**

Prevents system overload during peak times:

```python
# Maximum servers starting at once
c.JupyterHub.concurrent_spawn_limit = 10

# Maximum total active users
c.JupyterHub.active_server_limit = 50
```

**What this means:**
- Max 10 users can start servers simultaneously
- Max 50 users can have active servers running
- When limit is reached, new users wait in queue

---

## Resource Management Scenarios

### Scenario 1: User Logs Out
**Current Behavior:**
- User closes browser → Server keeps running
- After 1 hour idle → Automatically stopped by idle-culler

**To manually stop on logout:**
Call the backend API from your frontend:
```javascript
// When user logs out
await fetch('http://localhost:8080/api/v1/jupyter/stop', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${jwtToken}`
  }
});
```

### Scenario 2: User Closes Browser Tab
**Behavior:**
- Server continues running
- Idle-culler monitors activity
- After 1 hour idle → Stopped automatically

### Scenario 3: User Inactive but Browser Open
**Behavior:**
- If no notebook activity for 1 hour → Stopped
- User sees "Server stopped" message
- Click "Start My Server" to restart

### Scenario 4: System Resource Full
**Behavior:**
- If 50 active users limit reached
- New users see: "Active server limit reached"
- They wait until a slot opens (someone's server stops)

---

## Monitoring & Management

### Check Active Sessions

**Via Backend API:**
```bash
curl -H "Authorization: Bearer <ADMIN_TOKEN>" \
  http://localhost:8080/api/v1/admin/sessions
```

**Via JupyterHub Admin Panel:**
1. Login as admin user
2. Go to: http://localhost:8000/hub/admin
3. See all active users and servers

### Check Resource Usage

**Docker stats:**
```bash
# See all running Jupyter containers
docker ps | grep jupyter-

# Live resource usage
docker stats $(docker ps -q --filter "name=jupyter-")
```

### Manually Stop User Server

**Via Backend API:**
```bash
curl -X POST -H "Authorization: Bearer <USER_TOKEN>" \
  http://localhost:8080/api/v1/jupyter/stop
```

**Via JupyterHub Admin:**
1. Admin panel → Users
2. Find user → Click "Stop Server"

---

## Adjusting Resource Limits

### Increase Memory per User
```python
# jupyterhub_config.py
c.DockerSpawner.mem_limit = '4G'  # 4GB instead of 2GB
```

### Increase CPU per User
```python
c.DockerSpawner.cpu_limit = 2.0  # 2 cores instead of 1
```

### Change Idle Timeout
```python
# More aggressive (30 min)
'--timeout=1800'

# More lenient (2 hours)
'--timeout=7200'

# Disable idle timeout
# Remove idle-culler service entirely
```

### Change Concurrent User Limit
```python
# Allow 100 concurrent users
c.JupyterHub.active_server_limit = 100

# Unlimited (not recommended for production)
c.JupyterHub.active_server_limit = 0
```

---

## Best Practices

### 1. **Set Appropriate Limits Based on Hardware**

**Example for 32GB RAM, 16 CPU server:**
```python
# Allow ~12 users (2GB each = 24GB + 8GB for system)
c.DockerSpawner.mem_limit = '2G'
c.JupyterHub.active_server_limit = 12

# 1 CPU each = 16 users max (conservative)
c.DockerSpawner.cpu_limit = 1.0
```

### 2. **Monitor and Adjust Idle Timeout**

- **Short timeout (30 min)**: Good for high-traffic, limited resources
- **Long timeout (2-4 hours)**: Good for development/research work
- **Very long (8+ hours)**: For long-running computations

### 3. **Implement Frontend Logout Handler**

Add this to your frontend when user logs out:

```javascript
// In your logout function
async function logout() {
  try {
    // Stop Jupyter server
    await fetch('http://localhost:8080/api/v1/jupyter/stop', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('jwt_token')}`
      }
    });
    
    // Clear local storage
    localStorage.removeItem('jwt_token');
    localStorage.removeItem('user');
    
    // Redirect to login
    window.location.href = '/login';
  } catch (error) {
    console.error('Logout error:', error);
  }
}
```

### 4. **Use Named Servers for Advanced Use Cases**

Allow users to have multiple servers:
```python
c.JupyterHub.allow_named_servers = True
c.JupyterHub.named_server_limit_per_user = 2
```

---

## Resource Cleanup

### Clean Up Old Volumes
```bash
# List all user volumes
docker volume ls | grep jupyterhub-user

# Remove volume for specific user (CAUTION: Deletes data!)
docker volume rm jupyterhub-user-{username}

# Clean up unused volumes
docker volume prune
```

### Clean Up Stopped Containers
```bash
# Remove all stopped Jupyter containers
docker container prune -f --filter "label=jupyterhub"
```

---

## Troubleshooting

### Issue: Users Can't Start Servers
**Cause**: Active server limit reached
**Solution**: 
1. Check current active users: `docker ps | grep jupyter-`
2. Increase limit or wait for idle servers to stop
3. Manually stop inactive servers via admin panel

### Issue: Servers Not Stopping After Idle
**Cause**: Idle-culler service not running
**Check**: `docker compose logs jupyterhub | grep idle-culler`
**Solution**: Rebuild JupyterHub (already done!)

### Issue: High Memory Usage
**Cause**: Too many concurrent users or memory leaks
**Solution**:
1. Check active containers: `docker stats`
2. Reduce `active_server_limit`
3. Reduce `mem_limit` per user
4. Reduce idle timeout

---

## Production Recommendations

For production deployment with many users:

```python
# jupyterhub_config.py

# Conservative per-user limits
c.DockerSpawner.mem_limit = '1G'      # 1GB per user
c.DockerSpawner.cpu_limit = 0.5       # 0.5 CPU per user

# Aggressive idle management
'--timeout=1800',      # 30 min idle timeout
'--cull-every=300',    # Check every 5 min

# Scale based on your hardware
c.JupyterHub.active_server_limit = 50   # Adjust based on total RAM
c.JupyterHub.concurrent_spawn_limit = 5  # Prevent spawn storms

# Enable monitoring
c.JupyterHub.log_level = 'INFO'
```

---

## Summary

✅ **What's Now Enabled:**
- ✅ 2GB RAM + 1 CPU per user
- ✅ Automatic idle timeout (1 hour)
- ✅ Max 50 concurrent users
- ✅ Max 10 simultaneous server starts
- ✅ Automatic resource cleanup
- ✅ Persistent user data (volumes)

⚠️ **What You Should Add:**
- Implement logout handler in frontend
- Monitor resource usage regularly
- Adjust limits based on actual usage patterns
- Consider adding disk quotas per user

🎯 **Your system is now ready for multi-user concurrent usage with automatic resource management!**
