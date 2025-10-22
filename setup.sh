#!/bin/bash

echo "Setting up JupyterHub Multi-User Application..."

# Create necessary directories
mkdir -p jupyterhub backend frontend nginx/ssl

# Generate self-signed SSL certificates (for development)
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#   -keyout nginx/ssl/nginx.key -out nginx/ssl/nginx.crt

# Set proper permissions
chmod +x setup.sh

# Build and start services
echo "Building and starting services..."
docker-compose up --build -d

echo "Waiting for services to be ready..."
sleep 30

echo "Setup complete!"
echo "Access the application at:"
echo "  Frontend: http://localhost:3000"
echo "  Backend API: http://localhost:8080"
echo "  JupyterHub: http://localhost:8000"
echo ""
echo "Default admin credentials:"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "IMPORTANT: Change default passwords and secrets in production!"