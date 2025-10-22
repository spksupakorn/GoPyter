-- Create users table in public schema for backend authentication
-- Note: JupyterHub uses its own tables managed by alembic migrations
CREATE SCHEMA IF NOT EXISTS backend;

-- Users table for the backend authentication
CREATE TABLE
    IF NOT EXISTS backend.users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        full_name VARCHAR(255),
        is_active BOOLEAN DEFAULT true,
        is_admin BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

-- JupyterHub sessions table
CREATE TABLE
    IF NOT EXISTS backend.jupyter_sessions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES backend.users (id) ON DELETE CASCADE,
        session_token VARCHAR(512) UNIQUE NOT NULL,
        jupyter_token VARCHAR(512),
        started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP,
        is_active BOOLEAN DEFAULT true
    );

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_username ON backend.users (username);

CREATE INDEX IF NOT EXISTS idx_users_email ON backend.users (email);

CREATE INDEX IF NOT EXISTS idx_sessions_token ON backend.jupyter_sessions (session_token);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON backend.jupyter_sessions (user_id);

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