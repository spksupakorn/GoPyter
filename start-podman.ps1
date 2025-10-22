#!/usr/bin/env pwsh
# GoPyter Podman Startup Script for Windows
# This script ensures proper setup before starting the containers

Write-Host "🚀 Starting GoPyter with Podman..." -ForegroundColor Cyan

# Check if Podman is installed
Write-Host "`n📦 Checking Podman installation..." -ForegroundColor Yellow
try {
    $podmanVersion = podman --version
    Write-Host "✓ $podmanVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Podman is not installed or not in PATH" -ForegroundColor Red
    Write-Host "  Please install Podman Desktop: https://podman-desktop.io/downloads" -ForegroundColor Yellow
    exit 1
}

# Check if Podman machine is running (Windows/Mac requirement)
Write-Host "`n🖥️  Checking Podman machine status..." -ForegroundColor Yellow
$machineStatus = podman machine list --format "{{.Running}}" 2>$null
if ($machineStatus -notcontains "true") {
    Write-Host "✗ Podman machine is not running" -ForegroundColor Red
    Write-Host "  Starting Podman machine..." -ForegroundColor Yellow
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

# Check if podman-compose is installed
Write-Host "`n🔧 Checking podman-compose installation..." -ForegroundColor Yellow
try {
    $composeVersion = podman-compose --version 2>&1
    Write-Host "✓ $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ podman-compose is not installed" -ForegroundColor Red
    Write-Host "  Install with: pip install podman-compose" -ForegroundColor Yellow
    exit 1
}

# Check network configuration
Write-Host "`n🌐 Checking network configuration..." -ForegroundColor Yellow
$networks = podman network ls --format "{{.Name}}"
$expectedNetwork = "gopyter_jupyterhub-network"
if ($networks -contains $expectedNetwork) {
    Write-Host "✓ Network '$expectedNetwork' exists" -ForegroundColor Green
} else {
    Write-Host "⚠ Network '$expectedNetwork' not found (will be created)" -ForegroundColor Yellow
}

# Check if containers are already running
Write-Host "`n🐳 Checking existing containers..." -ForegroundColor Yellow
$runningContainers = podman ps --format "{{.Names}}"
if ($runningContainers) {
    Write-Host "⚠ Found running containers:" -ForegroundColor Yellow
    $runningContainers | ForEach-Object { Write-Host "  - $_" }
    $response = Read-Host "`nDo you want to stop them first? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "Stopping containers..." -ForegroundColor Yellow
        podman-compose -f compose.yaml down
    }
}

# Start the services
Write-Host "`n🚀 Starting GoPyter services..." -ForegroundColor Cyan
Write-Host "This may take a few minutes on first run..." -ForegroundColor Yellow

podman-compose -f compose.yaml up -d

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✓ GoPyter started successfully!" -ForegroundColor Green
    
    # Wait for services to be ready
    Write-Host "`n⏳ Waiting for services to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Check container status
    Write-Host "`n📊 Container Status:" -ForegroundColor Cyan
    podman-compose -f compose.yaml ps
    
    Write-Host "`n🌐 Services are available at:" -ForegroundColor Cyan
    Write-Host "  Frontend:    http://localhost:3000" -ForegroundColor White
    Write-Host "  Backend API: http://localhost:8080" -ForegroundColor White
    Write-Host "  JupyterHub:  http://localhost:8000" -ForegroundColor White
    Write-Host "  Nginx:       http://localhost:80" -ForegroundColor White
    
    Write-Host "`n📝 Default Admin Credentials:" -ForegroundColor Yellow
    Write-Host "  Username: admin" -ForegroundColor White
    Write-Host "  Password: admin123" -ForegroundColor White
    Write-Host "  (Change these after first login - see CHANGE_ADMIN_CREDENTIALS.md)" -ForegroundColor Gray
    
    Write-Host "`n📋 Useful Commands:" -ForegroundColor Cyan
    Write-Host "  View logs:      podman-compose -f compose.yaml logs -f [service]" -ForegroundColor White
    Write-Host "  Stop services:  podman-compose -f compose.yaml down" -ForegroundColor White
    Write-Host "  Restart:        podman-compose -f compose.yaml restart [service]" -ForegroundColor White
    Write-Host "  Shell access:   podman exec -it [container] /bin/bash" -ForegroundColor White
    
    Write-Host "`n✨ GoPyter is ready! Open http://localhost:3000 in your browser." -ForegroundColor Green
} else {
    Write-Host "`n✗ Failed to start GoPyter" -ForegroundColor Red
    Write-Host "Check logs with: podman-compose -f compose.yaml logs" -ForegroundColor Yellow
    exit 1
}
