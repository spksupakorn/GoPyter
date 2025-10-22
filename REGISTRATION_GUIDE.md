# User Registration Guide

## ✅ Registration Feature Added!

Your frontend now includes a complete user registration system.

---

## 📸 What You'll See

### Login Page (Default View)
- Username field
- Password field
- **Login** button
- **"Don't have an account? Create Account"** link at the bottom

### Registration Page
- Username field
- Email field
- Full Name field (optional)
- Password field (minimum 6 characters)
- **Register** button
- **"Already have an account? Back to Login"** link at the bottom

---

## 🔄 User Flow

### New User Registration:

1. **Navigate to:** http://localhost:3000
2. **Click:** "Create Account" link
3. **Fill in the form:**
   - Username: `newuser` (required)
   - Email: `newuser@example.com` (required)
   - Full Name: `New User` (optional)
   - Password: `password123` (min 6 characters)
4. **Click:** "Register" button
5. **Automatic login:** After successful registration, you're automatically logged in
6. **Access Jupyter:** Click "Start Jupyter" to launch your notebook

### Existing User Login:

1. **Navigate to:** http://localhost:3000
2. **Enter credentials:**
   - Username
   - Password
3. **Click:** "Login" button
4. **Access dashboard**

---

## 🎨 Features

### Registration Form
- ✅ Email validation (must be valid email format)
- ✅ Password validation (minimum 6 characters)
- ✅ All fields validated before submission
- ✅ Error messages displayed if registration fails
- ✅ Automatic login after successful registration
- ✅ Toggle between login and registration views

### Security
- ✅ Passwords hashed with bcrypt (backend)
- ✅ JWT token-based authentication
- ✅ All new users created as normal users (is_admin = false)
- ✅ Validation against duplicate usernames/emails

### User Experience
- ✅ Clean, modern UI with gradient background
- ✅ Responsive form design
- ✅ Clear error messages
- ✅ Smooth transitions between login/register
- ✅ No page reloads needed

---

## 🧪 Test the Registration

### Via Frontend:
```
1. Open: http://localhost:3000
2. Click: "Create Account"
3. Fill form and submit
4. You'll be automatically logged in
```

### Via API (for testing):
```bash
curl -X POST http://localhost:8080/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "testuser@example.com",
    "password": "password123",
    "full_name": "Test User"
  }'
```

---

## 📝 Database Verification

Check registered users:
```bash
docker compose exec postgres psql -U jupyterhub -d jupyterhub \
  -c "SELECT id, username, email, full_name, is_active, is_admin, created_at FROM backend.users;"
```

Example output:
```
 id | username  | email                  | full_name | is_active | is_admin | created_at
----+-----------+------------------------+-----------+-----------+----------+------------
  1 | admin     | admin@example.com      | Admin     | t         | t        | 2025-10-22
  2 | newuser   | newuser@example.com    | New User  | t         | f        | 2025-10-22
```

---

## 🔧 Technical Details

### Files Modified:
1. **frontend/src/App.js**
   - Added registration state management
   - Added `handleRegister()` function
   - Added registration form UI
   - Added toggle between login/register views

2. **frontend/src/App.css**
   - Added styles for registration form
   - Added styles for toggle links
   - Improved form responsiveness

### API Endpoint Used:
```
POST /api/v1/register
Content-Type: application/json

Request Body:
{
  "username": "string",
  "email": "string",
  "password": "string",
  "full_name": "string" (optional)
}

Response (201 Created):
{
  "message": "User created successfully",
  "user_id": 2
}
```

### Auto-Login Flow:
1. User submits registration form
2. Backend creates user account
3. Frontend automatically calls login API
4. JWT token stored in localStorage
5. User redirected to dashboard

---

## 🚀 What Users Can Do

After registration, normal users can:
- ✅ Login to the portal
- ✅ Start their own Jupyter notebook server
- ✅ Access JupyterLab in isolated container
- ✅ Save notebooks (persistent storage)
- ✅ Stop their Jupyter session
- ✅ Automatic idle timeout after 1 hour
- ✅ Resource limits: 2GB RAM, 1 CPU core

Normal users CANNOT:
- ❌ Access admin endpoints
- ❌ View/modify other users
- ❌ Change system settings

---

## 🎉 Success!

Your GoPyter Portal now has a complete user registration system! Users can:
1. Self-register through the frontend
2. Automatically get access to Jupyter notebooks
3. Work in isolated, resource-limited environments
4. Have their work automatically saved

**Next Steps:**
- Test the registration flow
- Customize the styling if needed
- Add password reset functionality (optional)
- Add email verification (optional for production)
