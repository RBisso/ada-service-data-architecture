param(
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase 5: Data Ecosystem (MovieFlix) Test ===" -ForegroundColor Cyan

# --- Start all services ---
Write-Host "`n[1/5] Starting all services via Docker Compose..." -ForegroundColor Yellow
docker compose down -v 2>$null | Out-Null
docker compose up -d --build 2>&1 | Out-Null

Write-Host "Waiting for the ETL job to finish..."
$etlStatus = ""
$etlExitCode = ""
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 2
    $etlStatus = docker inspect -f '{{.State.Status}}' movieflix_etl 2>$null
    if ($etlStatus -eq "exited") {
        $etlExitCode = docker inspect -f '{{.State.ExitCode}}' movieflix_etl 2>$null
        break
    }
}

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

function Check-Exited($name, $expectedExitCode) {
    $status = docker inspect -f '{{.State.Status}}' $name 2>$null
    $exitCode = docker inspect -f '{{.State.ExitCode}}' $name 2>$null
    if ($status -eq "exited" -and $exitCode -eq "$expectedExitCode") {
        Write-Host "  container $name  OK (exited $exitCode)" -ForegroundColor Green
    } else {
        Write-Host "  container $name  FAIL (status=$status, exit=$exitCode)" -ForegroundColor Red
        $script:failures++
    }
}

function Invoke-DwQuery($sql) {
    return docker exec db_dw psql -U dw_user -d movieflix_dw -t -A -c $sql 2>$null
}

try {
    Write-Host "`n[2/5] Verifying containers..." -ForegroundColor Yellow
    Check-Container "reverse_proxy"
    Check-Container "web_frontend"
    Check-Container "api_backend"
    Check-Container "db_oltp"
    Check-Container "db_dw"
    Check-Exited "movieflix_etl" 0

    Write-Host "`n[3/5] Verifying Data Warehouse row counts..." -ForegroundColor Yellow
    $movies = (Invoke-DwQuery "SELECT COUNT(*) FROM dim_movies;").Trim()
    $users = (Invoke-DwQuery "SELECT COUNT(*) FROM dim_users;").Trim()
    $genres = (Invoke-DwQuery "SELECT COUNT(*) FROM dim_genres;").Trim()
    $ratings = (Invoke-DwQuery "SELECT COUNT(*) FROM fact_ratings;").Trim()

    if ($movies -eq "40") { Write-Host "  dim_movies    OK ($movies)" -ForegroundColor Green }
    else { Write-Host "  dim_movies    FAIL ($movies)" -ForegroundColor Red; $failures++ }
    if ($users -eq "60") { Write-Host "  dim_users     OK ($users)" -ForegroundColor Green }
    else { Write-Host "  dim_users     FAIL ($users)" -ForegroundColor Red; $failures++ }
    if ($genres -eq "13") { Write-Host "  dim_genres    OK ($genres)" -ForegroundColor Green }
    else { Write-Host "  dim_genres    FAIL ($genres)" -ForegroundColor Red; $failures++ }
    if ($ratings -eq "1047") { Write-Host "  fact_ratings  OK ($ratings)" -ForegroundColor Green }
    else { Write-Host "  fact_ratings  FAIL ($ratings)" -ForegroundColor Red; $failures++ }

    Write-Host "`n[4/5] Verifying Data Mart views..." -ForegroundColor Yellow
    foreach ($view in @("v_top10_movies_by_genre", "v_avg_rating_by_age_group", "v_ratings_by_country")) {
        $exists = (Invoke-DwQuery "SELECT COUNT(*) FROM information_schema.views WHERE table_name = '$view';").Trim()
        if ($exists -eq "1") { Write-Host "  view $view  OK" -ForegroundColor Green }
        else { Write-Host "  view $view  FAIL" -ForegroundColor Red; $failures++ }
    }

    Write-Host "`n[5/5] Verifying analytical queries..." -ForegroundColor Yellow
    $q1 = Invoke-DwQuery "SELECT m.title, COUNT(r.rating_id) AS num_ratings FROM fact_ratings r JOIN dim_movies m ON r.movie_id = m.movie_id GROUP BY m.movie_id, m.title ORDER BY num_ratings DESC, m.title LIMIT 5;"
    if ($q1 -match "Nixon" -and $q1 -match "Get Shorty") {
        Write-Host "  Query 1 (5 most popular)       OK" -ForegroundColor Green
    } else {
        Write-Host "  Query 1 (5 most popular)       FAIL`n$q1" -ForegroundColor Red
        $failures++
    }

    $q2 = Invoke-DwQuery "SELECT g.genre FROM fact_ratings r JOIN movie_genres mg ON r.movie_id = mg.movie_id JOIN dim_genres g ON mg.genre_id = g.genre_id GROUP BY g.genre ORDER BY ROUND(AVG(r.rating),2) DESC, COUNT(r.rating_id) DESC, g.genre LIMIT 1;"
    if ($q2 -match "Sci-Fi") {
        Write-Host "  Query 2 (top genre)            OK" -ForegroundColor Green
    } else {
        Write-Host "  Query 2 (top genre)            FAIL ($q2)" -ForegroundColor Red
        $failures++
    }

    $q3 = Invoke-DwQuery "SELECT u.country, COUNT(r.rating_id) AS num_ratings FROM fact_ratings r JOIN dim_users u ON r.user_id = u.user_id GROUP BY u.country ORDER BY num_ratings DESC, u.country LIMIT 1;"
    if ($q3 -match "Brazil") {
        Write-Host "  Query 3 (top country)          OK" -ForegroundColor Green
    } else {
        Write-Host "  Query 3 (top country)          FAIL ($q3)" -ForegroundColor Red
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
    }
}
