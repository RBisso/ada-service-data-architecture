param(
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase 2: Frontend Test ===" -ForegroundColor Cyan

# --- Setup ---
Write-Host "`n[1/6] Starting PostgreSQL..." -ForegroundColor Yellow
docker rm -f test-oltp 2>$null | Out-Null
docker run --name test-oltp `
    -e POSTGRES_USER=app_user `
    -e POSTGRES_PASSWORD=app_pass `
    -e POSTGRES_DB=products_db `
    -p 5432:5432 `
    -d postgres:15-alpine | Out-Null
Start-Sleep -Seconds 5

# --- Compile backend ---
Write-Host "`n[2/6] Compiling backend..." -ForegroundColor Yellow
Remove-Item -LiteralPath "backend\out" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "backend\out" -Force | Out-Null
$javaFiles = Get-ChildItem -Path "backend\src\main\java" -Recurse -Filter "*.java" | Select-Object -ExpandProperty FullName
javac -cp "backend\lib\postgresql.jar" -d backend\out @($javaFiles)
if ($LASTEXITCODE -ne 0) { throw "Compilation failed" }

# --- Start backend ---
Write-Host "`n[3/6] Starting backend..." -ForegroundColor Yellow
$env:DB_HOST = "localhost"; $env:DB_PORT = "5432"; $env:DB_USER = "app_user"
$env:DB_PASSWORD = "app_pass"; $env:DB_NAME = "products_db"; $env:PORT = "8080"
$backendProc = Start-Process -FilePath "java" -ArgumentList "-cp", "backend\out;backend\lib\postgresql.jar", "com.products.App" -PassThru
Start-Sleep -Seconds 4

# --- Build frontend image ---
Write-Host "`n[4/6] Building frontend Docker image..." -ForegroundColor Yellow
docker build -t test-frontend ./frontend
if ($LASTEXITCODE -ne 0) { throw "Frontend build failed" }

# --- Start frontend ---
Write-Host "`n[5/6] Starting frontend (nginx)..." -ForegroundColor Yellow
docker rm -f test-frontend 2>$null | Out-Null
docker run --name test-frontend -p 8081:80 -d test-frontend | Out-Null
Start-Sleep -Seconds 2

$failures = 0

try {
    Write-Host "`n[6/6] Testing..." -ForegroundColor Yellow

    # Backend health check
    $resp = curl.exe -s http://localhost:8080/health
    if ($resp -match '"status":"ok"') {
        Write-Host "  Backend /health          OK" -ForegroundColor Green
    } else {
        Write-Host "  Backend /health          FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # Backend CRUD
    $bodyFile = "$env:TEMP\test-body.json"
    Set-Content -LiteralPath $bodyFile -Value '{"name":"Widget"}'
    $resp = curl.exe -s -X POST http://localhost:8080/api/products -H "Content-Type: application/json" -d "@$bodyFile"
    if ($resp -match '"name":"Widget"') {
        Write-Host "  Backend POST /products    OK" -ForegroundColor Green
    } else {
        Write-Host "  Backend POST /products    FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # Frontend serves HTML
    $resp = curl.exe -s http://localhost:8081/
    if ($resp -match "Products Manager" -and $resp -match "addProduct" -and $resp -match "/api/products") {
        Write-Host "  Frontend serves HTML      OK" -ForegroundColor Green
    } else {
        Write-Host "  Frontend serves HTML      FAIL" -ForegroundColor Red
        $failures++
    }

    # Frontend Dockerfile uses nginx:alpine
    $df = Get-Content -LiteralPath "frontend\Dockerfile" -Raw
    if ($df -match "nginx:alpine" -and $df -match "index.html") {
        Write-Host "  Frontend Dockerfile       OK" -ForegroundColor Green
    } else {
        Write-Host "  Frontend Dockerfile       FAIL" -ForegroundColor Red
        $failures++
    }

    # --- Summary ---
    Write-Host ""
    if ($failures -eq 0) {
        Write-Host "All tests passed!" -ForegroundColor Green
    } else {
        Write-Host "$failures test(s) failed" -ForegroundColor Red
        exit 1
    }
} finally {
    if (-not $SkipCleanup) {
        Write-Host "`nCleaning up..." -ForegroundColor Yellow
        Stop-Process -Id $backendProc.Id -Force -ErrorAction SilentlyContinue
        docker rm -f test-oltp 2>$null | Out-Null
        docker rm -f test-frontend 2>$null | Out-Null
        Remove-Item -LiteralPath $bodyFile -ErrorAction SilentlyContinue
    }
}
