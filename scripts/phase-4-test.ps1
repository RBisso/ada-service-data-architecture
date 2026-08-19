param(
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase 4: Docker Compose Orchestration Test ===" -ForegroundColor Cyan

# --- Start all services ---
Write-Host "`n[1/4] Starting all services via Docker Compose..." -ForegroundColor Yellow
docker compose down -v 2>$null | Out-Null
docker compose up -d --build 2>&1 | Out-Null

Write-Host "Waiting for services to be ready..."
Start-Sleep -Seconds 10

$failures = 0

function Check-Container($name) {
    $running = docker inspect -f '{{.State.Running}}' $name 2>$null
    if ($running -eq "true") {
        Write-Host "  container $name  OK (running)" -ForegroundColor Green
    } else {
        Write-Host "  container $name  FAIL" -ForegroundColor Red
        $script:failures++
    }
}

try {
    Write-Host "`n[2/4] Verifying containers are running..." -ForegroundColor Yellow
    Check-Container "reverse_proxy"
    Check-Container "web_frontend"
    Check-Container "api_backend"
    Check-Container "db_oltp"

    Write-Host "`n[3/4] Verifying network and volume..." -ForegroundColor Yellow
    $net = docker network ls --format "{{.Name}}" | Select-String -Pattern "app-network"
    if ($net) {
        Write-Host "  network app-network  OK" -ForegroundColor Green
    } else {
        Write-Host "  network app-network  FAIL" -ForegroundColor Red
        $failures++
    }

    $vol = docker volume ls --format "{{.Name}}" | Select-String -Pattern "oltp_data"
    if ($vol) {
        Write-Host "  volume oltp_data     OK" -ForegroundColor Green
    } else {
        Write-Host "  volume oltp_data     FAIL" -ForegroundColor Red
        $failures++
    }

    Write-Host "`n[4/4] Testing endpoints through proxy (port 80)..." -ForegroundColor Yellow
    $bodyFile = "$env:TEMP\test-body.json"

    # Health check via proxy
    $resp = curl.exe -s http://localhost/health
    if ($resp -match '"status":"ok"') {
        Write-Host "  GET  /health              OK" -ForegroundColor Green
    } else {
        Write-Host "  GET  /health              FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # POST via proxy
    Set-Content -LiteralPath $bodyFile -Value '{"name":"Widget"}'
    $resp = curl.exe -s -X POST http://localhost/api/products -H "Content-Type: application/json" -d "@$bodyFile"
    if ($resp -match '"name":"Widget"') {
        Write-Host "  POST /api/products        OK" -ForegroundColor Green
    } else {
        Write-Host "  POST /api/products        FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    Start-Sleep -Milliseconds 500

    # GET all via proxy
    $resp = curl.exe -s http://localhost/api/products
    if ($resp -match '"name":"Widget"') {
        Write-Host "  GET  /api/products        OK" -ForegroundColor Green
    } else {
        Write-Host "  GET  /api/products        FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # GET by id via proxy
    $resp = curl.exe -s http://localhost/api/products/1
    if ($resp -match '"id":1' -and $resp -match '"name":"Widget"') {
        Write-Host "  GET  /api/products/1      OK" -ForegroundColor Green
    } else {
        Write-Host "  GET  /api/products/1      FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # PUT via proxy
    Set-Content -LiteralPath $bodyFile -Value '{"name":"Widget Pro"}'
    $resp = curl.exe -s -X PUT http://localhost/api/products/1 -H "Content-Type: application/json" -d "@$bodyFile"
    if ($resp -match '"name":"Widget Pro"') {
        Write-Host "  PUT  /api/products/1      OK" -ForegroundColor Green
    } else {
        Write-Host "  PUT  /api/products/1      FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # DELETE via proxy
    $resp = curl.exe -s -w "%{http_code}" -X DELETE http://localhost/api/products/1
    if ($resp -eq "204") {
        Write-Host "  DELETE /api/products/1    OK (204)" -ForegroundColor Green
    } else {
        Write-Host "  DELETE /api/products/1    FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # Frontend served via proxy
    $resp = curl.exe -s http://localhost/
    if ($resp -match "Products Manager" -and $resp -match "/api/products") {
        Write-Host "  GET  / (frontend)         OK" -ForegroundColor Green
    } else {
        Write-Host "  GET  / (frontend)         FAIL" -ForegroundColor Red
        $failures++
    }

    # --- Summary ---
    Write-Host "`nResults" -ForegroundColor Yellow
    if ($failures -eq 0) {
        Write-Host "All tests passed!" -ForegroundColor Green
    } else {
        Write-Host "$failures test(s) failed" -ForegroundColor Red
        exit 1
    }
} finally {
    if (-not $SkipCleanup) {
        Write-Host "`nCleaning up..." -ForegroundColor Yellow
        docker compose down -v 2>$null | Out-Null
        Remove-Item -LiteralPath $bodyFile -ErrorAction SilentlyContinue
    }
}
