#!/bin/bash
# GoPyter Podman Startup Script for Linux/Mac
# This script ensures proper setup before starting the containers

set -e

echo "🚀 Starting GoPyter with Podman..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if Podman is installed
echo -e "\n${YELLOW}📦 Checking Podman installation...${NC}"
if command -v podman &> /dev/null; then
    PODMAN_VERSION=$(podman --version)
    echo -e "${GREEN}✓ $PODMAN_VERSION${NC}"
else
    echo -e "${RED}✗ Podman is not installed${NC}"
    echo -e "${YELLOW}  Please install Podman: https://podman.io/getting-started/installation${NC}"
    exit 1
fi

# Check if podman-compose is installed
echo -e "\n${YELLOW}🔧 Checking podman-compose installation...${NC}"
if command -v podman-compose &> /dev/null; then
    COMPOSE_VERSION=$(podman-compose --version 2>&1 || echo "installed")
    echo -e "${GREEN}✓ $COMPOSE_VERSION${NC}"
else
    echo -e "${RED}✗ podman-compose is not installed${NC}"
    echo -e "${YELLOW}  Install with: pip3 install podman-compose${NC}"
    exit 1
fi

# Enable Podman socket for rootless mode (if not already enabled)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "\n${YELLOW}🔌 Checking Podman socket...${NC}"
    if systemctl --user is-active --quiet podman.socket; then
        echo -e "${GREEN}✓ Podman socket is active${NC}"
    else
        echo -e "${YELLOW}⚠ Enabling Podman socket...${NC}"
        systemctl --user enable --now podman.socket 2>/dev/null || true
        echo -e "${GREEN}✓ Podman socket enabled${NC}"
    fi
fi

# Check network configuration
echo -e "\n${YELLOW}🌐 Checking network configuration...${NC}"
EXPECTED_NETWORK="gopyter_jupyterhub-network"
if podman network ls --format "{{.Name}}" | grep -q "^${EXPECTED_NETWORK}$"; then
    echo -e "${GREEN}✓ Network '$EXPECTED_NETWORK' exists${NC}"
else
    echo -e "${YELLOW}⚠ Network '$EXPECTED_NETWORK' not found (will be created)${NC}"
fi

# Check if containers are already running
echo -e "\n${YELLOW}🐳 Checking existing containers...${NC}"
if podman ps --format "{{.Names}}" | grep -q "jupyterhub"; then
    echo -e "${YELLOW}⚠ Found running containers:${NC}"
    podman ps --format "  - {{.Names}}"
    read -p "Do you want to stop them first? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Stopping containers...${NC}"
        podman-compose -f compose.yaml down
    fi
fi

# Start the services
echo -e "\n${CYAN}🚀 Starting GoPyter services...${NC}"
echo -e "${YELLOW}This may take a few minutes on first run...${NC}"

podman-compose -f compose.yaml up -d

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ GoPyter started successfully!${NC}"
    
    # Wait for services to be ready
    echo -e "\n${YELLOW}⏳ Waiting for services to be ready...${NC}"
    sleep 10
    
    # Check container status
    echo -e "\n${CYAN}📊 Container Status:${NC}"
    podman-compose -f compose.yaml ps
    
    echo -e "\n${CYAN}🌐 Services are available at:${NC}"
    echo -e "  Frontend:    http://localhost:3000"
    echo -e "  Backend API: http://localhost:8080"
    echo -e "  JupyterHub:  http://localhost:8000"
    echo -e "  Nginx:       http://localhost:80"
    
    echo -e "\n${YELLOW}📝 Default Admin Credentials:${NC}"
    echo -e "  Username: admin"
    echo -e "  Password: admin123"
    echo -e "  ${CYAN}(Change these after first login - see CHANGE_ADMIN_CREDENTIALS.md)${NC}"
    
    echo -e "\n${CYAN}📋 Useful Commands:${NC}"
    echo -e "  View logs:      podman-compose -f compose.yaml logs -f [service]"
    echo -e "  Stop services:  podman-compose -f compose.yaml down"
    echo -e "  Restart:        podman-compose -f compose.yaml restart [service]"
    echo -e "  Shell access:   podman exec -it [container] /bin/bash"
    
    echo -e "\n${GREEN}✨ GoPyter is ready! Open http://localhost:3000 in your browser.${NC}"
else
    echo -e "\n${RED}✗ Failed to start GoPyter${NC}"
    echo -e "${YELLOW}Check logs with: podman-compose -f compose.yaml logs${NC}"
    exit 1
fi
