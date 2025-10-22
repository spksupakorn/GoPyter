import os
import sys
from jupyterhub.auth import Authenticator
from tornado import gen
import requests
import psycopg2
from psycopg2 import pool
import bcrypt

# Custom Authenticator that validates against our backend database
class CustomAuthenticator(Authenticator):
    """
    Custom authenticator that validates users from our backend database
    """
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Create database connection pool
        self.db_pool = psycopg2.pool.SimpleConnectionPool(
            1, 10,
            host=os.environ.get('POSTGRES_HOST', 'postgres'),
            database=os.environ.get('POSTGRES_DB', 'jupyterhub'),
            user=os.environ.get('POSTGRES_USER', 'jupyterhub'),
            password=os.environ.get('POSTGRES_PASSWORD', 'jupyterhub_password')
        )
    
    async def authenticate(self, handler, data):
        """
        Authenticate user against backend database or JWT token
        """
        # Check if token is provided (for SSO)
        token = data.get('token', '') or handler.get_argument('token', '')
        
        if token:
            # Try JWT token authentication
            try:
                import jwt
                jwt_secret = os.environ.get('JWT_SECRET', 'your-super-secret-jwt-key-change-this')
                payload = jwt.decode(token, jwt_secret, algorithms=['HS256'])
                username = payload.get('username')
                
                if username:
                    self.log.info(f"Authenticated user via JWT: {username}")
                    return username
            except Exception as e:
                self.log.error(f"JWT authentication failed: {str(e)}")
        
        # Fall back to username/password authentication
        username = data.get('username', '')
        password = data.get('password', '')
        
        if not username or not password:
            self.log.error("Username or password not provided")
            return None
        
        try:
            # Get connection from pool
            conn = self.db_pool.getconn()
            cursor = conn.cursor()
            
            # Query user from backend schema
            cursor.execute(
                "SELECT username, password_hash, is_active FROM backend.users WHERE username = %s",
                (username,)
            )
            result = cursor.fetchone()
            
            # Return connection to pool
            self.db_pool.putconn(conn)
            
            if not result:
                self.log.error(f"User not found: {username}")
                return None
            
            db_username, password_hash, is_active = result
            
            if not is_active:
                self.log.error(f"User account is disabled: {username}")
                return None
            
            # Verify password
            if bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8')):
                self.log.info(f"Successfully authenticated user: {username}")
                return username
            else:
                self.log.error(f"Invalid password for user: {username}")
                return None
                
        except Exception as e:
            self.log.error(f"Authentication failed: {str(e)}")
            return None

# JupyterHub configuration
c = get_config()

# Use custom authenticator
c.JupyterHub.authenticator_class = CustomAuthenticator

# Use DockerSpawner for user notebooks
c.JupyterHub.spawner_class = 'dockerspawner.DockerSpawner'

# Docker configuration
c.DockerSpawner.image = 'jupyter/scipy-notebook:latest'
c.DockerSpawner.network_name = os.environ.get('DOCKER_NETWORK_NAME', 'jupyterhub-network')
c.DockerSpawner.remove = True
c.DockerSpawner.debug = True

# Notebook directory
c.DockerSpawner.notebook_dir = '/home/jovyan/work'
c.DockerSpawner.volumes = {
    'jupyterhub-user-{username}': '/home/jovyan/work'
}

# Resource limits per user
c.DockerSpawner.mem_limit = '2G'  # 2GB RAM per user
c.DockerSpawner.cpu_limit = 1.0   # 1 CPU core per user

# Idle timeout - automatically shutdown inactive servers
# Users inactive for this duration will have their server stopped
c.JupyterHub.services = [
    {
        'name': 'idle-culler',
        'admin': True,
        'command': [
            'python3', '-m', 'jupyterhub_idle_culler',
            '--timeout=3600',  # Cull after 1 hour of inactivity (in seconds)
            '--cull-every=600',  # Check for idle servers every 10 minutes
            '--cull-users',  # Also cull idle users (not just servers)
            '--remove-named-servers',  # Remove named servers when culling
            '--max-age=0',  # Don't cull based on age, only inactivity
        ],
    },
    {
        'name': 'backend-api',
        'api_token': os.environ.get('JUPYTERHUB_API_TOKEN', 'your-jupyterhub-api-token-change-this'),
    }
]

# Define roles with proper scopes for the API token
c.JupyterHub.load_roles = [
    {
        'name': 'backend-api-role',
        'scopes': [
            'admin:users',  # Create and manage users
            'admin:servers',  # Start and stop servers
            'read:users',  # Read user information
            'read:servers',  # Read server information
            'servers',  # Access to server operations
            'access:servers',  # Access to spawn servers
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

# Concurrent spawn limit - prevents too many servers starting at once
c.JupyterHub.concurrent_spawn_limit = 10

# Active server limit - max number of servers running simultaneously
# Set to 0 for unlimited, or a number based on your resources
c.JupyterHub.active_server_limit = 50  # Maximum 50 concurrent users

# Hub configuration
c.JupyterHub.hub_ip = '0.0.0.0'
c.JupyterHub.ip = '0.0.0.0'
c.JupyterHub.port = 8000

# Admin users
c.Authenticator.admin_users = {'admin'}

# Allow users to be created via API
c.JupyterHub.allow_named_servers = False
c.Authenticator.allow_all = True  # Allow any authenticated user

# Database
postgres_host = os.environ.get('POSTGRES_HOST', 'postgres')
postgres_db = os.environ.get('POSTGRES_DB', 'jupyterhub')
postgres_user = os.environ.get('POSTGRES_USER', 'jupyterhub')
postgres_password = os.environ.get('POSTGRES_PASSWORD', 'jupyterhub_password')

c.JupyterHub.db_url = f'postgresql://{postgres_user}:{postgres_password}@{postgres_host}/{postgres_db}'

# Logging
c.JupyterHub.log_level = 'INFO'
c.Spawner.log_level = 'INFO'

# CORS settings for API access
c.JupyterHub.tornado_settings = {
    'headers': {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
    'cookie_options': {
        'samesite': 'Lax'
    }
}

# Custom handlers for token-based login
from jupyterhub.handlers import BaseHandler
from tornado import web
import jwt as pyjwt

class TokenLoginHandler(BaseHandler):
    """Handler for token-based SSO login"""
    
    async def get(self):
        token = self.get_argument('token', '')
        next_url = self.get_argument('next', '')
        
        if not token:
            self.log.warning("No token provided to token-login handler")
            self.redirect('/hub/login')
            return
            
        # Validate token using JWT
        jwt_secret = os.environ.get('JWT_SECRET', 'your-super-secret-jwt-key-change-this')
        
        try:
            payload = pyjwt.decode(token, jwt_secret, algorithms=['HS256'])
            username = payload.get('username')
            
            if not username:
                self.log.error("No username in token payload")
                self.redirect('/hub/login')
                return
            
            self.log.info(f"Token login attempt for user: {username}")
            
            # Get the user from the database or create if not exists
            user = self.find_user(username)
            if not user:
                self.log.info(f"User {username} not found, creating new user")
                # Use the proper JupyterHub API to create user
                from jupyterhub import orm
                user = orm.User(name=username)
                self.db.add(user)
                self.db.commit()
                self.log.info(f"Created user: {username}")
            
            # Set authentication cookie
            self.set_login_cookie(user)
            self.log.info(f"Login cookie set for user: {username}")
            
            # Redirect to hub/spawn to ensure server starts
            if not next_url:
                next_url = f'/hub/spawn'
                
            self.log.info(f"Redirecting {username} to: {next_url}")
            self.redirect(next_url)
            return
            
        except pyjwt.ExpiredSignatureError:
            self.log.error("Token has expired")
            self.redirect('/hub/login')
        except pyjwt.InvalidTokenError as e:
            self.log.error(f"Invalid token: {e}")
            self.redirect('/hub/login')
        except Exception as e:
            self.log.error(f"Token validation failed: {e}", exc_info=True)
            self.redirect('/hub/login')
            
        # If we get here, authentication failed
        self.redirect('/hub/login')

# Register the custom handler
c.JupyterHub.extra_handlers = [
    (r'/token-login', TokenLoginHandler),
]