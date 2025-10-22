#!/bin/bash
# Universal startup script for Docker or Podman
# Auto-detects which container runtime is available

set -e

echo "🚀 Starting GoPyter (Universal Docker/Podman launcher)..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Detect container runtime
runtime=""
runtime_name=""

echo -e "\n${YELLOW}🔍 Detecting container runtime...${NC}"

# Check for Docker
if command -v docker &> /dev/null; then
    if docker info &> /dev/null 2>&1; then
        runtime="docker"
        runtime_name="Docker"
        docker_version=$(docker --version)
        echo -e "${GREEN}✓ Found: $docker_version${NC}"
    fi
fi

# Check for Podman if Docker not found or not running
if [ -z "$runtime" ]; then
    if command -v podman &> /dev/null; then
        runtime="podman"
        runtime_name="Podman"
        podman_version=$(podman --version)
        echo -e "${GREEN}✓ Found: $podman_version${NC}"
    fi
fi

# Exit if neither found
if [ -z "$runtime" ]; then
    echo -e "${RED}✗ Neither Docker nor Podman is installed or running${NC}"
    echo -e "\n${YELLOW}Please install one of:${NC}"
    echo -e "  - Docker: https://docs.docker.com/get-docker/"
    echo -e "  - Podman: https://podman.io/getting-started/installation"
    exit 1
fi

echo -e "\n${GREEN}✓ Using $runtime_name as container runtime${NC}"

# Setup based on runtime
if [ "$runtime" = "podman" ]; then
    # Check if podman-compose is installed
    echo -e "\n${YELLOW}🔧 Checking podman-compose...${NC}"
    if command -v podman-compose &> /dev/null; then
        compose_version=$(podman-compose --version 2>&1 || echo "installed")
        echo -e "${GREEN}✓ $compose_version${NC}"
        compose_cmd="podman-compose"
    else
        echo -e "${RED}✗ podman-compose is not installed${NC}"
        echo -e "${YELLOW}  Install with: pip3 install podman-compose${NC}"
        exit 1
    fi
    
    # Enable Podman socket for rootless mode (Linux only)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "\n${YELLOW}🔌 Checking Podman socket...${NC}"
        if systemctl --user is-active --quiet podman.socket 2>/dev/null; then
            echo -e "${GREEN}✓ Podman socket is active${NC}"
        else
            echo -e "${YELLOW}⚠ Enabling Podman socket...${NC}"
            systemctl --user enable --now podman.socket 2>/dev/null || true
            echo -e "${GREEN}✓ Podman socket enabled${NC}"
        fi
    fi
    
elif [ "$runtime" = "docker" ]; then
    echo -e "\n${YELLOW}🐳 Checking Docker daemon...${NC}"
    if docker info &> /dev/null; then
        echo -e "${GREEN}✓ Docker daemon is running${NC}"
    else
        echo -e "${RED}✗ Docker daemon is not running${NC}"
        echo -e "${YELLOW}  Please start Docker${NC}"
        exit 1
    fi
    compose_cmd="docker compose"
fi

# Determine network name based on runtime
echo -e "\n${YELLOW}🌐 Detecting network configuration...${NC}"
project_name=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')
expected_network="${project_name}_jupyterhub-network"
echo -e "${GRAY}Expected network: $expected_network${NC}"

# Set compose project name environment variable
export COMPOSE_PROJECT_NAME="$project_name"

# Check existing containers
echo -e "\n${YELLOW}🐳 Checking existing containers...${NC}"
if [ "$runtime" = "podman" ]; then
    running_containers=$(podman ps --format "{{.Names}}" 2>/dev/null || true)
else
    running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null || true)
fi

if [ -n "$running_containers" ]; then
    echo -e "${YELLOW}⚠ Found running containers:${NC}"
    echo "$running_containers" | sed 's/^/  - /'
    read -p "Do you want to stop them first? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Stopping containers...${NC}"
        $compose_cmd -f compose.yaml down
    fi
fi

# Start services
echo -e "\n${CYAN}🚀 Starting GoPyter services with $runtime_name...${NC}"
echo -e "${YELLOW}This may take a few minutes on first run...${NC}"

$compose_cmd -f compose.yaml up -d --build

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ GoPyter started successfully with $runtime_name!${NC}"
    
    # Wait for services
    echo -e "\n${YELLOW}⏳ Waiting for services to be ready...${NC}"
    sleep 10
    
    # Check container status
    echo -e "\n${CYAN}📊 Container Status:${NC}"
    $compose_cmd -f compose.yaml ps
    
    echo -e "\n${CYAN}🌐 Services are available at:${NC}"
    echo -e "  Frontend:    http://localhost:3000"
    echo -e "  Backend API: http://localhost:8080"
    echo -e "  JupyterHub:  http://localhost:8000"
    echo -e "  Nginx:       http://localhost:80"
    
    echo -e "\n${YELLOW}📝 Default Admin Credentials:${NC}"
    echo -e "  Username: admin"
    echo -e "  Password: admin123"
    echo -e "  ${GRAY}(Change these after first login - see CHANGE_ADMIN_CREDENTIALS.md)${NC}"
    
    echo -e "\n${CYAN}📋 Useful Commands ($runtime_name):${NC}"
    if [ "$runtime" = "podman" ]; then
        echo -e "  View logs:      podman-compose -f compose.yaml logs -f [service]"
        echo -e "  Stop services:  podman-compose -f compose.yaml down"
        echo -e "  Restart:        podman-compose -f compose.yaml restart [service]"
        echo -e "  Shell access:   podman exec -it [container] /bin/bash"
    else
        echo -e "  View logs:      docker compose -f compose.yaml logs -f [service]"
        echo -e "  Stop services:  docker compose -f compose.yaml down"
        echo -e "  Restart:        docker compose -f compose.yaml restart [service]"
        echo -e "  Shell access:   docker exec -it [container] /bin/bash"
    fi
    
    echo -e "\n${GREEN}✨ GoPyter is ready! Open http://localhost:3000 in your browser.${NC}"
    echo -e "${CYAN}Running on: $runtime_name${NC}"
else
    echo -e "\n${RED}✗ Failed to start GoPyter${NC}"
    echo -e "${YELLOW}Check logs with: $compose_cmd -f compose.yaml logs${NC}"
    exit 1
fi
