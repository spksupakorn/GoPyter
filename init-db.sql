-- Users table
CREATE TABLE
    IF NOT EXISTS users (
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
    IF NOT EXISTS jupyter_sessions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users (id) ON DELETE CASCADE,
        session_token VARCHAR(512) UNIQUE NOT NULL,
        jupyter_token VARCHAR(512),
        started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP,
        is_active BOOLEAN DEFAULT true
    );

-- Create indexes
CREATE INDEX idx_users_username ON users (username);

CREATE INDEX idx_users_email ON users (email);

CREATE INDEX idx_sessions_token ON jupyter_sessions (session_token);

CREATE INDEX idx_sessions_user_id ON jupyter_sessions (user_id);

-- Create admin user (password: admin123 - CHANGE THIS!)
INSERT INTO
    users (
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
        '$2a$10$8K1p/a0dL3LKzOWNk6Kv8.WYLqZqZ9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z',
        'Administrator',
        true
    );