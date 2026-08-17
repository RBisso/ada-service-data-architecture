Write-Host "=== Phase 2: Frontend Manual Test ===" -ForegroundColor Cyan
Write-Host "Starting all services. Press any key to stop and clean up.`n" -ForegroundColor DarkGray

# Cleanup previous runs
docker compose -f scripts/test-proxy/docker-compose.test.yml down -v 2>$null | Out-Null

# --- Start all services ---
Write-Host "[1/2] Starting all services via Docker Compose..." -ForegroundColor Yellow
docker compose -f scripts/test-proxy/docker-compose.test.yml up -d --build 2>&1 | Out-Null

Write-Host "Waiting for services to be ready..."
Start-Sleep -Seconds 8

# --- Seed some data ---
Write-Host "[2/2] Seeding sample products..." -ForegroundColor Yellow
$bodyFile = "$env:TEMP\test-body.json"
foreach ($name in @("Notebook", "Mouse", "Keyboard")) {
    Set-Content -LiteralPath $bodyFile -Value "{`"name`":`"$name`"}"
    curl.exe -s -X POST http://localhost/api/products -H "Content-Type: application/json" -d "@$bodyFile" | Out-Null
}

# --- Status ---
$health = curl.exe -s http://localhost/health
if ($health -match '"status":"ok"') {
    Write-Host "`n=== All Services Running ===" -ForegroundColor Green
} else {
    Write-Host "`n=== Services Started (some may need time) ===" -ForegroundColor Yellow
}

Write-Host "  App:       http://localhost        (Frontend + API via proxy)"
Write-Host "  Health:    http://localhost/health"
Write-Host "`nPress any key to stop..." -ForegroundColor DarkGray

try {
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} finally {
    Write-Host "`nCleaning up..." -ForegroundColor Yellow
    docker compose -f scripts/test-proxy/docker-compose.test.yml down -v 2>$null | Out-Null
    Remove-Item -LiteralPath $bodyFile -ErrorAction SilentlyContinue
    Write-Host "Done." -ForegroundColor Green
}
