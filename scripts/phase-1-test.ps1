param(
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase 1: Backend API Test ===" -ForegroundColor Cyan

# --- Setup ---
Write-Host "`n[1/5] Starting PostgreSQL..." -ForegroundColor Yellow
docker rm -f test-oltp 2>$null | Out-Null
docker run --name test-oltp `
    -e POSTGRES_USER=app_user `
    -e POSTGRES_PASSWORD=app_pass `
    -e POSTGRES_DB=products_db `
    -p 5432:5432 `
    -d postgres:15-alpine | Out-Null

Write-Host "Waiting for database..."
Start-Sleep -Seconds 5

# --- Compile ---
Write-Host "`n[2/5] Compiling backend..." -ForegroundColor Yellow
if (!(Test-Path -LiteralPath "backend\lib\postgresql.jar")) {
    New-Item -ItemType Directory -Path "backend\lib" -Force | Out-Null
    Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar" -OutFile "backend\lib\postgresql.jar"
}

Remove-Item -LiteralPath "backend\out" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "backend\out" -Force | Out-Null
$javaFiles = Get-ChildItem -Path "backend\src\main\java" -Recurse -Filter "*.java" | Select-Object -ExpandProperty FullName
javac -cp "backend\lib\postgresql.jar" -d backend\out @($javaFiles)
if ($LASTEXITCODE -ne 0) { throw "Compilation failed" }

# --- Start server ---
Write-Host "`n[3/5] Starting server..." -ForegroundColor Yellow
$env:DB_HOST = "localhost"
$env:DB_PORT = "5432"
$env:DB_USER = "app_user"
$env:DB_PASSWORD = "app_pass"
$env:DB_NAME = "products_db"
$env:PORT = "8080"

$proc = Start-Process -FilePath "java" -ArgumentList "-cp", "backend\out;backend\lib\postgresql.jar", "com.products.App" -PassThru
Start-Sleep -Seconds 4

try {
    # --- Test endpoints ---
    Write-Host "`n[4/5] Testing endpoints..." -ForegroundColor Yellow
    $bodyFile = "$env:TEMP\test-body.json"
    $failures = 0

    # Health
    $resp = curl.exe -s http://localhost:8080/health
    if ($resp -match '"status":"ok"') {
        Write-Host "  GET /health              OK" -ForegroundColor Green
    } else {
        Write-Host "  GET /health              FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # POST
    Set-Content -LiteralPath $bodyFile -Value '{"name":"Notebook"}'
    $resp = curl.exe -s -X POST http://localhost:8080/api/products -H "Content-Type: application/json" -d "@$bodyFile"
    if ($resp -match '"id":1' -and $resp -match '"name":"Notebook"') {
        Write-Host "  POST /api/products       OK ($resp)" -ForegroundColor Green
    } else {
        Write-Host "  POST /api/products       FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # GET all
    Start-Sleep -Milliseconds 500
    $resp = curl.exe -s http://localhost:8080/api/products
    if ($resp -match '"name":"Notebook"') {
        Write-Host "  GET  /api/products       OK ($resp)" -ForegroundColor Green
    } else {
        Write-Host "  GET  /api/products       FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # GET by id
    $resp = curl.exe -s http://localhost:8080/api/products/1
    if ($resp -match '"id":1' -and $resp -match '"name":"Notebook"') {
        Write-Host "  GET  /api/products/1     OK ($resp)" -ForegroundColor Green
    } else {
        Write-Host "  GET  /api/products/1     FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # PUT
    Set-Content -LiteralPath $bodyFile -Value '{"name":"Notebook Pro"}'
    $resp = curl.exe -s -X PUT http://localhost:8080/api/products/1 -H "Content-Type: application/json" -d "@$bodyFile"
    if ($resp -match '"name":"Notebook Pro"') {
        Write-Host "  PUT  /api/products/1     OK ($resp)" -ForegroundColor Green
    } else {
        Write-Host "  PUT  /api/products/1     FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # DELETE
    $resp = curl.exe -s -w "%{http_code}" -X DELETE http://localhost:8080/api/products/1
    if ($resp -eq "204") {
        Write-Host "  DELETE /api/products/1   OK (204)" -ForegroundColor Green
    } else {
        Write-Host "  DELETE /api/products/1   FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # Verify empty
    Start-Sleep -Milliseconds 500
    $resp = curl.exe -s http://localhost:8080/api/products
    if ($resp -eq "[]") {
        Write-Host "  GET  /api/products (empty) OK" -ForegroundColor Green
    } else {
        Write-Host "  GET  /api/products (empty) FAIL ($resp)" -ForegroundColor Red
        $failures++
    }

    # --- Summary ---
    Write-Host "`n[5/5] Results" -ForegroundColor Yellow
    if ($failures -eq 0) {
        Write-Host "All tests passed!" -ForegroundColor Green
    } else {
        Write-Host "$failures test(s) failed" -ForegroundColor Red
        exit 1
    }
} finally {
    if (-not $SkipCleanup) {
        Write-Host "`nCleaning up..." -ForegroundColor Yellow
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        docker rm -f test-oltp 2>$null | Out-Null
        Remove-Item -LiteralPath $bodyFile -ErrorAction SilentlyContinue
    }
}
