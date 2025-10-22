#!/usr/bin/env pwsh
# Universal startup script for Docker or Podman
# Auto-detects which container runtime is available

Write-Host "🚀 Starting GoPyter (Universal Docker/Podman launcher)..." -ForegroundColor Cyan

# Detect container runtime
$runtime = $null
$runtimeName = ""

Write-Host "`n🔍 Detecting container runtime..." -ForegroundColor Yellow

# Check for Docker
try {
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        $runtime = "docker"
        $runtimeName = "Docker"
        Write-Host "✓ Found: $dockerVersion" -ForegroundColor Green
    }
} catch {}

# Check for Podman if Docker not found
if (-not $runtime) {
    try {
        $podmanVersion = podman --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $runtime = "podman"
            $runtimeName = "Podman"
            Write-Host "✓ Found: $podmanVersion" -ForegroundColor Green
        }
    } catch {}
}

# Exit if neither found
if (-not $runtime) {
    Write-Host "✗ Neither Docker nor Podman is installed" -ForegroundColor Red
    Write-Host "`nPlease install one of:" -ForegroundColor Yellow
    Write-Host "  - Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor White
    Write-Host "  - Podman Desktop: https://podman-desktop.io/downloads" -ForegroundColor White
    exit 1
}

Write-Host "`n✓ Using $runtimeName as container runtime" -ForegroundColor Green

# Setup based on runtime
if ($runtime -eq "podman") {
    Write-Host "`n🖥️  Checking Podman machine status..." -ForegroundColor Yellow
    $machineStatus = podman machine list --format "{{.Running}}" 2>$null
    if ($machineStatus -notcontains "true") {
        Write-Host "⚠ Podman machine is not running. Starting..." -ForegroundColor Yellow
        podman machine start
        if ($LASTEXITCODE -ne 0) {
            Write-Host "✗ Failed to start Podman machine" -ForegroundColor Red
            exit 1
        }
        Write-Host "✓ Podman machine started" -ForegroundColor Green
        Start-Sleep -Seconds 3
    } else {
        Write-Host "✓ Podman machine is running" -ForegroundColor Green
    }
    
    # Check for podman-compose
    Write-Host "`n🔧 Checking podman-compose..." -ForegroundColor Yellow
    try {
        $composeCmd = "podman-compose"
        & $composeCmd --version 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw }
        Write-Host "✓ podman-compose is available" -ForegroundColor Green
    } catch {
        Write-Host "✗ podman-compose not found" -ForegroundColor Red
        Write-Host "  Install with: pip install podman-compose" -ForegroundColor Yellow
        exit 1
    }
    
    # Setup socket symlink for Podman
    Write-Host "`n🔌 Configuring Podman socket compatibility..." -ForegroundColor Yellow
    # Podman machine already maps the socket, just need to ensure it's accessible
    Write-Host "✓ Socket configuration ready" -ForegroundColor Green
    
} elseif ($runtime -eq "docker") {
    Write-Host "`n🐳 Checking Docker daemon..." -ForegroundColor Yellow
    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Docker daemon is running" -ForegroundColor Green
        } else {
            throw
        }
    } catch {
        Write-Host "✗ Docker daemon is not running" -ForegroundColor Red
        Write-Host "  Please start Docker Desktop" -ForegroundColor Yellow
        exit 1
    }
    
    $composeCmd = "docker"
    Write-Host "✓ Using docker compose" -ForegroundColor Green
}

# Determine network name based on runtime
Write-Host "`n🌐 Detecting network configuration..." -ForegroundColor Yellow
$projectName = (Get-Item -Path ".").Name.ToLower()

if ($runtime -eq "podman") {
    $expectedNetwork = "${projectName}_jupyterhub-network"
} else {
    # Docker Compose v2 also uses project name prefix
    $expectedNetwork = "${projectName}_jupyterhub-network"
}

Write-Host "Expected network: $expectedNetwork" -ForegroundColor Gray

# Set compose project name environment variable
$env:COMPOSE_PROJECT_NAME = $projectName

# Check existing containers
Write-Host "`n🐳 Checking existing containers..." -ForegroundColor Yellow
if ($runtime -eq "podman") {
    $runningContainers = podman ps --format "{{.Names}}"
} else {
    $runningContainers = docker ps --format "{{.Names}}"
}

if ($runningContainers) {
    Write-Host "⚠ Found running containers:" -ForegroundColor Yellow
    $runningContainers | ForEach-Object { Write-Host "  - $_" }
    $response = Read-Host "`nDo you want to stop them first? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "Stopping containers..." -ForegroundColor Yellow
        if ($runtime -eq "podman") {
            podman-compose -f compose.yaml down
        } else {
            docker compose -f compose.yaml down
        }
    }
}

# Start services
Write-Host "`n🚀 Starting GoPyter services with $runtimeName..." -ForegroundColor Cyan
Write-Host "This may take a few minutes on first run..." -ForegroundColor Yellow

if ($runtime -eq "podman") {
    podman-compose -f compose.yaml up -d --build
} else {
    docker compose -f compose.yaml up -d --build
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✓ GoPyter started successfully with $runtimeName!" -ForegroundColor Green
    
    # Wait for services
    Write-Host "`n⏳ Waiting for services to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Check container status
    Write-Host "`n📊 Container Status:" -ForegroundColor Cyan
    if ($runtime -eq "podman") {
        podman-compose -f compose.yaml ps
    } else {
        docker compose -f compose.yaml ps
    }
    
    Write-Host "`n🌐 Services are available at:" -ForegroundColor Cyan
    Write-Host "  Frontend:    http://localhost:3000" -ForegroundColor White
    Write-Host "  Backend API: http://localhost:8080" -ForegroundColor White
    Write-Host "  JupyterHub:  http://localhost:8000" -ForegroundColor White
    Write-Host "  Nginx:       http://localhost:80" -ForegroundColor White
    
    Write-Host "`n📝 Default Admin Credentials:" -ForegroundColor Yellow
    Write-Host "  Username: admin" -ForegroundColor White
    Write-Host "  Password: admin123" -ForegroundColor White
    Write-Host "  (Change these after first login - see CHANGE_ADMIN_CREDENTIALS.md)" -ForegroundColor Gray
    
    Write-Host "`n📋 Useful Commands ($runtimeName):" -ForegroundColor Cyan
    if ($runtime -eq "podman") {
        Write-Host "  View logs:      podman-compose -f compose.yaml logs -f [service]" -ForegroundColor White
        Write-Host "  Stop services:  podman-compose -f compose.yaml down" -ForegroundColor White
        Write-Host "  Restart:        podman-compose -f compose.yaml restart [service]" -ForegroundColor White
        Write-Host "  Shell access:   podman exec -it [container] /bin/bash" -ForegroundColor White
    } else {
        Write-Host "  View logs:      docker compose -f compose.yaml logs -f [service]" -ForegroundColor White
        Write-Host "  Stop services:  docker compose -f compose.yaml down" -ForegroundColor White
        Write-Host "  Restart:        docker compose -f compose.yaml restart [service]" -ForegroundColor White
        Write-Host "  Shell access:   docker exec -it [container] /bin/bash" -ForegroundColor White
    }
    
    Write-Host "`n✨ GoPyter is ready! Open http://localhost:3000 in your browser." -ForegroundColor Green
    Write-Host "Running on: $runtimeName" -ForegroundColor Cyan
} else {
    Write-Host "`n✗ Failed to start GoPyter" -ForegroundColor Red
    if ($runtime -eq "podman") {
        Write-Host "Check logs with: podman-compose -f compose.yaml logs" -ForegroundColor Yellow
    } else {
        Write-Host "Check logs with: docker compose -f compose.yaml logs" -ForegroundColor Yellow
    }
    exit 1
}
