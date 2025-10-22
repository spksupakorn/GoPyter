# How to Change Default Admin User and Password

This guide explains how to change the default admin credentials (`admin/admin123`) in your JupyterHub deployment.

---

## ⚠️ Important Security Warning

**Always change the default admin credentials before deploying to production!** The default username `admin` and password `admin123` are well-known and insecure.

---

## 📍 Two Places to Update

You need to update the admin user in **two locations**:

1. **Database initialization file** (`init-backend-db.sql`)
2. **JupyterHub configuration** (`jupyterhub/jupyterhub_config.py`)

---

## Method 1: Change Before First Start (Recommended)

This method is best if you haven't started the system yet or don't mind recreating the database.

### Step 1: Generate Password Hash

You need to create a bcrypt hash of your new password:

**Option A: Using Python (recommended)**
```bash
python3 -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_NEW_PASSWORD', bcrypt.gensalt()).decode())"
```

**Option B: Using Online Tool**
- Visit: https://bcrypt-generator.com/
- Enter your password
- Use cost factor: 10
- Copy the generated hash

**Example:**
```bash
# Generate hash for password "SecurePass123!"
python3 -c "import bcrypt; print(bcrypt.hashpw(b'SecurePass123!', bcrypt.gensalt()).decode())"

# Output (yours will be different):
$2b$10$AbCdEfGhIjKlMnOpQrStUvWxYz1234567890ABCDEFGHIJKLMNOPQRS
```

### Step 2: Update Database Initialization File

**File:** `init-backend-db.sql`

Find this section (around line 41-59):

```sql
-- Create admin user (password: admin123 - CHANGE THIS!)
-- Password hash for 'admin123'
INSERT INTO
    backend.users (
        username,
        email,
        password_hash,
        full_name,
        is_admin
    )
VALUES
    (
        'admin',
        'admin@example.com',
        '$2a$10$HxLkBMX0KsZX4Hc6qAFhse8uc7B6MwPdmPiTPnm80eSQBS7lXGKo.',
        'Admin User',
        true
    ) ON CONFLICT (username) DO NOTHING;
```

**Change to:**

```sql
-- Create admin user (CUSTOM PASSWORD)
-- Replace with your own username and password hash
INSERT INTO
    backend.users (
        username,
        email,
        password_hash,
        full_name,
        is_admin
    )
VALUES
    (
        'myadmin',                                              -- ← Your new username
        'myadmin@yourcompany.com',                             -- ← Your new email
        '$2b$10$YOUR_GENERATED_HASH_GOES_HERE',                -- ← Your password hash
        'System Administrator',                                 -- ← Display name
        true
    ) ON CONFLICT (username) DO NOTHING;
```

### Step 3: Update JupyterHub Configuration

**File:** `jupyterhub/jupyterhub_config.py`

Find this line (around line 177):

```python
c.Authenticator.admin_users = {'admin'}
```

**Change to:**

```python
c.Authenticator.admin_users = {'myadmin'}  # Match your new username from Step 2
```

### Step 4: Start or Restart Services

**If starting for the first time:**
```bash
docker compose up -d --build
```

**If system is already running:**
```bash
# Stop all services
docker compose down

# Remove database volume (⚠️ WARNING: This deletes ALL user data!)
docker volume rm jupyterhub_postgres_data

# Rebuild and restart
docker compose up -d --build
```

### Step 5: Verify New Credentials

Test the new admin login:

```bash
curl -X POST http://localhost:8080/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "myadmin",
    "password": "YOUR_NEW_PASSWORD"
  }'
```

**Expected response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "username": "myadmin",
    "email": "myadmin@yourcompany.com",
    "full_name": "System Administrator",
    "is_active": true,
    "is_admin": true
  }
}
```

---

## Method 2: Change After System is Running

Use this method if you already have users and data you want to keep.

### Option A: Change Password Only

**Step 1: Generate new password hash**
```bash
python3 -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_NEW_PASSWORD', bcrypt.gensalt()).decode())"
```

**Step 2: Update password in database**
```bash
# Save the hash to a variable (replace with your actual hash)
NEW_HASH='$2b$10$YOUR_GENERATED_HASH_HERE'

# Update the admin user's password
docker compose exec postgres psql -U jupyterhub -d jupyterhub -c \
  "UPDATE backend.users SET password_hash='$NEW_HASH' WHERE username='admin';"
```

**Step 3: Verify**
```bash
curl -X POST http://localhost:8080/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "YOUR_NEW_PASSWORD"
  }'
```

### Option B: Change Username and Password

**Step 1: Generate new password hash**
```bash
python3 -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_NEW_PASSWORD', bcrypt.gensalt()).decode())"
```

**Step 2: Update username, email, and password in database**
```bash
NEW_HASH='$2b$10$YOUR_GENERATED_HASH_HERE'

docker compose exec postgres psql -U jupyterhub -d jupyterhub -c \
  "UPDATE backend.users 
   SET username='myadmin', 
       email='myadmin@yourcompany.com', 
       password_hash='$NEW_HASH',
       full_name='System Administrator'
   WHERE username='admin';"
```

**Step 3: Update JupyterHub config**

Edit `jupyterhub/jupyterhub_config.py`:
```python
c.Authenticator.admin_users = {'myadmin'}  # Change from 'admin' to your new username
```

**Step 4: Restart JupyterHub**
```bash
docker compose restart jupyterhub
```

**Step 5: Verify**
```bash
curl -X POST http://localhost:8080/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "myadmin",
    "password": "YOUR_NEW_PASSWORD"
  }'
```

---

## Method 3: Create Additional Admin Users

You can have multiple admin users in the system.

### Step 1: Register new user via frontend or API

**Via API:**
```bash
curl -X POST http://localhost:8080/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newadmin",
    "email": "newadmin@example.com",
    "password": "SecurePassword123!",
    "full_name": "New Admin User"
  }'
```

### Step 2: Promote user to admin in database

```bash
docker compose exec postgres psql -U jupyterhub -d jupyterhub -c \
  "UPDATE backend.users SET is_admin=true WHERE username='newadmin';"
```

### Step 3: Add to JupyterHub admin users

Edit `jupyterhub/jupyterhub_config.py`:
```python
c.Authenticator.admin_users = {'admin', 'newadmin'}  # Multiple admins
```

### Step 4: Restart JupyterHub

```bash
docker compose restart jupyterhub
```

---

## 🔍 Troubleshooting

### Password doesn't work after changing

**Check the hash was properly set:**
```bash
docker compose exec postgres psql -U jupyterhub -d jupyterhub -c \
  "SELECT username, password_hash FROM backend.users WHERE is_admin=true;"
```

**Verify the hash format:**
- Should start with `$2a$`, `$2b$`, or `$2y$`
- Should be around 60 characters long
- Example: `$2b$10$AbCdEfGhIjKlMnOpQrStUvWxYz1234567890ABCDEFGHIJKLMNOPQRS`

### Cannot login to JupyterHub with admin user

**Check JupyterHub admin users config:**
```bash
docker compose exec jupyterhub cat /srv/jupyterhub/jupyterhub_config.py | grep admin_users
```

**Restart JupyterHub:**
```bash
docker compose restart jupyterhub
```

### User not found in database

**List all users:**
```bash
docker compose exec postgres psql -U jupyterhub -d jupyterhub -c \
  "SELECT id, username, email, is_admin, created_at FROM backend.users ORDER BY id;"
```

---

## 📝 Quick Reference

### Generate Password Hash
```bash
python3 -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_PASSWORD', bcrypt.gensalt()).decode())"
```

### Update Password Only
```bash
NEW_HASH='$2b$10$YOUR_HASH'
docker compose exec postgres psql -U jupyterhub -d jupyterhub -c \
  "UPDATE backend.users SET password_hash='$NEW_HASH' WHERE username='admin';"
```

### Update Username and Password
```bash
NEW_HASH='$2b$10$YOUR_HASH'
docker compose exec postgres psql -U jupyterhub -d jupyterhub -c \
  "UPDATE backend.users SET username='newadmin', password_hash='$NEW_HASH' WHERE username='admin';"
```

### Check Current Admin Users
```bash
docker compose exec postgres psql -U jupyterhub -d jupyterhub -c \
  "SELECT username, email, is_admin FROM backend.users WHERE is_admin=true;"
```

### Test Login
```bash
curl -X POST http://localhost:8080/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"username":"YOUR_USERNAME","password":"YOUR_PASSWORD"}'
```

---

## 🔐 Security Best Practices

1. **Use Strong Passwords**
   - Minimum 12 characters
   - Mix of uppercase, lowercase, numbers, and symbols
   - Don't use common words or patterns

2. **Change Immediately in Production**
   - Never use default credentials in production
   - Change passwords during initial setup

3. **Limit Admin Access**
   - Only give admin privileges to trusted users
   - Use regular user accounts for daily work

4. **Rotate Credentials Regularly**
   - Change admin passwords periodically (every 90 days recommended)
   - Update immediately if credentials may be compromised

5. **Secure Environment Variables**
   - Don't commit passwords to version control
   - Use secrets management tools in production
   - Restrict access to `compose.yaml` file

6. **Enable Audit Logging**
   - Monitor admin login attempts
   - Track admin actions
   - Set up alerts for suspicious activity

---

## 📚 Related Documentation

- [README.md](./README.md) - Main project documentation
- [REGISTRATION_GUIDE.md](./REGISTRATION_GUIDE.md) - User registration guide
- [RESOURCE_MANAGEMENT.md](./RESOURCE_MANAGEMENT.md) - Resource limits and idle timeout
- [SSO_TESTING.md](./SSO_TESTING.md) - SSO authentication testing

---

## ❓ Need Help?

If you encounter issues:

1. Check the [Troubleshooting](#-troubleshooting) section above
2. Review logs: `docker compose logs backend` and `docker compose logs jupyterhub`
3. Verify database connection: `docker compose exec postgres psql -U jupyterhub -d jupyterhub -c "\dt backend.*"`
4. Ensure all services are running: `docker compose ps`

---

**Remember**: Security is critical! Always change default credentials and follow best practices for password management.
