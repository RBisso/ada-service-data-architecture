# AI Log - Development Cycle

## Project

**Repository:** https://github.com/RBisso/ada-service-data-architecture.git
**Spec:** `projeto-ada-arquitetura.md`

## Tech Stack

- **Backend API:** Java 26, plain `com.sun.net.httpserver.HttpServer` + JDBC (no frameworks)
- **ETL / Load scripts:** Python
- **Infrastructure:** Docker Compose (5 services: proxy, frontend, backend, db_oltp, db_dw)
- **Database:** PostgreSQL (OLTP + Data Warehouse)

## Workflow

- **Environment:** Windows (PowerShell), Docker Desktop
- Branch structure: `main`, `develop`, `feature/0.X` (X = phase number)
- Commits to remote handled by user
- Phases implemented incrementally; phases marked as done in README checklist
- Test scripts in `scripts/phase-X-test.ps1`, created at the end of each phase

## CI/CD Requirements (GitHub)

Repo **Settings > Secrets and variables > Actions** — two secrets required before Phase 6:
- `DOCKERHUB_USERNAME` — Docker Hub username
- `DOCKERHUB_TOKEN` — Docker Hub access token (not password)

## Phases

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Scaffolding (folder structure, git init, .gitignore, README) | Done |
| 1 | Backend API (Java 26 Products CRUD) | Done |
| 2 | Frontend (HTML/JS) | Done |
| 3 | Reverse proxy (Nginx) | Done |
| 4 | docker-compose.yml orchestration | Done |
| 5 | Data ecosystem (MovieFlix: datalake, ETL, SQL) | Pending |
| 6 | CI/CD (GitHub Actions) | Pending |
| 7 | DNS bonus + final README | Pending |

## Conversation Log

### Session 1 - 2026-08-14

- Explored repo root, read `projeto-ada-arquitetura.md`, `src/Main.java`, `.gitignore`
- Decided backend approach: **Plain Java 26 + JDBC** (zero framework, `com.sun.net.httpserver`, guaranteed Java 26 compatible, tiny Docker image)
- Phase 0 completed:
  - Created folder structure per spec: `backend/src/main/java`, `backend/src/main/resources`, `frontend/`, `nginx/`, `data-ecosystem/{datalake,etl,sql}`, `.github/workflows/`
  - Deleted `src/` (IntelliJ template `Main.java`)
  - `git init` on branch `main`
  - Updated `.gitignore` (added `.idea/`, `*.iml`, `target/`, Python caches)
  - Updated `ada-arquitetura.iml` to point at `backend/src/main/java`
  - Created `README.md` skeleton with phase checklist
  - Note: spec has typos to avoid in implementation: `POSTGRESS_PASSWORD` -> `POSTGRES_PASSWORD`, `/.backend` -> `./backend`, `DELETE /api/produts/` -> `DELETE /api/products/`

### Session 2 - 2026-08-14

- Created GitHub repo: https://github.com/RBisso/ada-service-data-architecture.git
- Branch strategy: `main`, `develop`, `feature/0.X`
- User handles commits; CI/CD secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
- Created `ai-log.md` (this file)
- **Phase 1 completed:**
  - Backend API structure (`backend/src/main/java/com/products/`):
    - `App.java` — main entry, starts HttpServer on port 8080, DB retry loop (10 attempts, 2s delay), `/health` endpoint
    - `config/Config.java` — reads `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` from env vars
    - `model/Product.java` — immutable POJO with `toJson()` serialization
    - `repository/ProductRepository.java` — JDBC CRUD: `findAll`, `findById`, `save` (RETURNING), `update` (RETURNING), `delete`, `init` (CREATE TABLE IF NOT EXISTS)
    - `handler/ProductHandler.java` — HTTP routing via regex path matching, handles GET/POST/PUT/DELETE, manual JSON parsing/serialization
  - `backend/src/main/resources/init.sql` — reference DDL (app auto-creates table on startup)
  - `backend/Dockerfile` — multi-stage: eclipse-temurin:26-jdk (build) -> eclipse-temurin:26-jre-alpine (runtime), downloads PostgreSQL JDBC 42.7.4 at build time
  - Health check at `GET /health` (for CI smoke test in Phase 6)
  - Endpoint: `GET/POST/PUT/DELETE /api/products(/id)` — JSON responses, status codes 200/201/204/400/404/405/500
  - **Compilation fix:** `ProductHandler` methods needed `throws Exception` (not just `throws IOException`) since `ProductRepository` throws `SQLException` (checked)
  - **Testing note on Windows:** `curl -d '{"name":"X"}'` sends mangled JSON due to PowerShell quoting; use `Set-Content` + `curl -d "@file"` instead
  - **Test script:** `scripts/phase-1-test.ps1` — starts PostgreSQL, compiles, runs server, tests all 6 endpoints, cleans up. All tests passed.

- **Phase 2 completed:**
  - `frontend/index.html` — single-page UI: product table (list/add/edit/delete), vanilla HTML/CSS/JS, calls `GET/POST/PUT/DELETE /api/products`
  - `frontend/Dockerfile` — `nginx:alpine` serving static HTML on port 80
  - Frontend calls `/api/products` (relative path); integration with backend through Nginx reverse proxy (Phase 3)
  - **Test script:** `scripts/phase-2-test.ps1` — compiles backend, builds frontend Docker image, verifies nginx serves HTML, verifies backend CRUD. All tests passed.

- **Phase 3 completed:**
  - `nginx/nginx.conf` — reverse proxy: `/` → frontend:80, `/api/` → backend:8080, `/health` → backend:8080/health
  - `nginx/Dockerfile` — `nginx:alpine` with custom config
  - **Key learning:** Alpine's musl DNS resolver doesn't work with Docker Desktop's embedded DNS (127.0.0.11) on Windows. Fixed by using variables in `proxy_pass` (e.g. `set $backend_api http://backend:8080; proxy_pass $backend_api;`) which defers DNS resolution to request time.
  - **Key learning:** When `proxy_pass` uses a variable, nginx does NOT rewrite the URI — it appends the full original request URI. So `location /api/` + `proxy_pass $var/api/` doubles the path. Fix: use `proxy_pass $var;` without the trailing `/api/`.
  - `scripts/test-proxy/docker-compose.test.yml` — compose file for testing all services (db_oltp, backend, frontend, proxy)
  - **Test script:** `scripts/phase-3-test.ps1` — runs all services via Docker Compose, tests all CRUD endpoints through proxy on port 80. All tests passed.

### Session 4 - 2026-08-19

- **Phase 4 completed:**
  - Finalized root `docker-compose.yml` (4 CRUD services): added `healthcheck` to `backend` (`wget -qO- http://localhost:8080/health`), `proxy` now waits on `backend` via `condition: service_healthy`, added `restart: unless-stopped` to all services, quoted env values for consistency.
  - Verified `wget` is present in `eclipse-temurin:26-jre-alpine` (BusyBox v1.37.0).
  - `db_dw` (analytical DB) intentionally left out — belongs to Phase 5 (data ecosystem).
  - Omitted `version:` key (Compose v2 no longer needs it; avoids deprecation warning).
  - **Test scripts:** `scripts/phase-4-test.ps1` (asserts 4 containers running, verifies network + volume exist, smoke-tests CRUD + frontend through proxy) and `scripts/phase-4-test-manual.ps1`.
  - README checklist updated (Phase 4 marked done).
