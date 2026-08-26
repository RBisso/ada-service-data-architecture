param(
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase 6: CI/CD Pipeline Test ===" -ForegroundColor Cyan

$failures = 0

function Check-File($path, $description) {
    if (Test-Path -LiteralPath $path) {
        Write-Host "  $description  OK" -ForegroundColor Green
    } else {
        Write-Host "  $description  FAIL (not found)" -ForegroundColor Red
        $script:failures++
    }
}

function Check-Match($content, $pattern, $description) {
    if ($content -match $pattern) {
        Write-Host "  $description  OK" -ForegroundColor Green
    } else {
        Write-Host "  $description  FAIL" -ForegroundColor Red
        $script:failures++
    }
}

try {
    # --- Step 1: Verify workflow files ---
    Write-Host "`n[1/3] Checking workflow files..." -ForegroundColor Yellow
    Check-File ".github/workflows/ci.yml" "ci.yml exists"
    Check-File ".github/workflows/deploy.yml" "deploy.yml exists"

    if (Test-Path -LiteralPath ".github/workflows/ci.yml") {
        $ciContent = Get-Content -Raw -LiteralPath ".github/workflows/ci.yml"
        Check-Match $ciContent "docker compose" "ci.yml uses docker compose"
        Check-Match $ciContent "health" "ci.yml has smoke test"
        Check-Match $ciContent "docker/login-action" "ci.yml logs in to Docker Hub"
        Check-Match $ciContent "docker push" "ci.yml pushes images"
    }

    if (Test-Path -LiteralPath ".github/workflows/deploy.yml") {
        $deployContent = Get-Content -Raw -LiteralPath ".github/workflows/deploy.yml"
        Check-Match $deployContent "rsync" "deploy.yml syncs files to server"
        Check-Match $deployContent "deploy_remote.sh" "deploy.yml runs remote deploy script"
    }

    # --- Step 2: Build and start services ---
    Write-Host "`n[2/3] Building and starting services..." -ForegroundColor Yellow
    $ErrorActionPreference = "SilentlyContinue"
    docker compose down -v 2>$null
    docker compose up -d --build 2>$null
    $ErrorActionPreference = "Stop"

    Write-Host "Waiting for backend to be ready..."
    $ready = $false
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Seconds 3
        $health = curl.exe -s http://localhost/health 2>$null
        if ($health -match '"status":"ok"') {
            $ready = $true
            break
        }
    }

    if ($ready) {
        Write-Host "  Backend healthy  OK" -ForegroundColor Green
    } else {
        Write-Host "  Backend healthy  FAIL (timeout)" -ForegroundColor Red
        docker compose logs api_backend 2>$null
        $failures++
    }

    $bodyFile = "$env:TEMP\test-body.json"

    # Health check
    $resp = curl.exe -s http://localhost/health
    if ($resp -match '"status":"ok"') {
        Write-Host "  GET  /health         OK" -ForegroundColor Green
    } else {
        Write-Host "  GET  /health         FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # GET products
    $resp = curl.exe -s http://localhost/api/products
    if ($resp -match "\[") {
        Write-Host "  GET  /api/products   OK" -ForegroundColor Green
    } else {
        Write-Host "  GET  /api/products   FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # POST product
    Set-Content -LiteralPath $bodyFile -Value '{"name":"CI-Test"}'
    $resp = curl.exe -s -X POST http://localhost/api/products -H "Content-Type: application/json" -d "@$bodyFile"
    if ($resp -match '"name":"CI-Test"') {
        Write-Host "  POST /api/products   OK" -ForegroundColor Green
    } else {
        Write-Host "  POST /api/products   FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # --- Step 3: Summary ---
    Write-Host "`n[3/3] Results" -ForegroundColor Yellow
    if ($failures -eq 0) {
        Write-Host "All tests passed!" -ForegroundColor Green
    } else {
        Write-Host "$failures test(s) failed" -ForegroundColor Red
        exit 1
    }
} finally {
    if (-not $SkipCleanup) {
        Write-Host "`nCleaning up..." -ForegroundColor Yellow
        $ErrorActionPreference = "SilentlyContinue"
        docker compose down -v 2>$null
        if ($bodyFile) { Remove-Item -LiteralPath $bodyFile -ErrorAction SilentlyContinue }
        $ErrorActionPreference = "Stop"
    }
}
