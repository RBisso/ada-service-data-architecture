# ADA - Service and Data Architecture

Final project integrating **Service Architecture** (Docker, Docker Compose, Nginx, CI/CD, DNS) and **Data Architecture** (Data Lake, Data Warehouse, Data Mart, SQL).

## Overview

End-to-end ecosystem with two areas:

1. **Products CRUD application** - Nginx reverse proxy + HTML/JS frontend + Java 26 REST API + PostgreSQL (OLTP).
2. **MovieFlix data ecosystem** - 3-layer architecture: Data Lake (CSV) -> Data Warehouse (PostgreSQL) -> Data Marts (SQL views) with analytical queries.

## Architecture

### Current (Phases 0-4)

```
[ Client / Browser ]
          |
          v
  [ Reverse Proxy ]  (Nginx) - Port 80
          |
          +---> [ Web Server / Frontend ]  (HTML/JS - nginx:alpine)
          |
          +---> [ Application Server / API ]  (Java 26 - HttpServer + JDBC)
                        |
                        v
                [ OLTP Database ]  (PostgreSQL 15)
```

### Final (after Phase 5)

```
[ Client / Browser ]
          |
          v
  [ Reverse Proxy ]  (Nginx) - Port 80
          |
          +---> [ Web Server / Frontend ]  (HTML/JS)
          |
          +---> [ Application Server / API ]  (Java 26)
          |           |
          |           v
          |   [ OLTP Database ]  (PostgreSQL 15)
          |
          +---> [ Data Lake ]  (CSV: movies, users, ratings)
          |           |
          |           v
          |   [ Python ETL ]  (load_dw.py)
          |           |
          |           v
          |   [ Data Warehouse ]  (PostgreSQL 15)
          |           |
          |           v
          |   [ Data Marts ]  (SQL Views)
          |           |
          |           v
          |   [ Analytical Queries ]  (Business insights)
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend API | Java 26, `com.sun.net.httpserver.HttpServer`, JDBC |
| Frontend | HTML, CSS, JavaScript (vanilla) |
| Reverse Proxy | Nginx (Alpine) |
| OLTP Database | PostgreSQL 15 (Alpine) |
| Data Warehouse | PostgreSQL 15 (Alpine) |
| ETL Scripts | Python (psycopg2) |
| Orchestration | Docker Compose |
| CI/CD | GitHub Actions |

## Repository Structure

```text
.
+-- .github/workflows/       # CI/CD pipeline
+-- nginx/                   # Reverse proxy (Dockerfile + nginx.conf)
+-- frontend/                # HTML/JS web interface (Dockerfile + index.html)
+-- backend/                 # Java 26 REST API (Dockerfile + source code)
|   +-- src/main/java/       # Java source (com.products.*)
|   +-- src/main/resources/  # SQL init scripts
+-- data-ecosystem/
|   +-- datalake/            # Raw CSV files (movies, users, ratings)
|   +-- etl/                 # Python load scripts
|   +-- sql/                 # DW schema, data marts, analytics queries
+-- scripts/                 # Phase test scripts (PowerShell)
+-- docker-compose.yml       # Orchestration (all services)
+-- README.md
```

## Getting Started

### Prerequisites

- Docker and Docker Compose

### Run

```bash
docker compose up -d --build
```

The application will be available at:

| Service | URL |
|---------|-----|
| App (Frontend + API) | http://localhost |
| Health check | http://localhost/health |
| OLTP Database | localhost:5432 |

### Stop

```bash
docker compose down -v
```

## API Endpoints

| Method | Endpoint | Description | Status Code |
|--------|----------|-------------|-------------|
| `GET` | `/api/products` | List all products | 200 |
| `GET` | `/api/products/{id}` | Get product by ID | 200 / 404 |
| `POST` | `/api/products` | Create a new product | 201 |
| `PUT` | `/api/products/{id}` | Update a product | 200 / 404 |
| `DELETE` | `/api/products/{id}` | Delete a product | 204 / 404 |
| `GET` | `/health` | Health check | 200 |

### Request/Response examples

**Create product:**
```bash
curl -X POST http://localhost/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Notebook"}'
```
Response: `{"id":1,"name":"Notebook"}`

**List all products:**
```bash
curl http://localhost/api/products
```
Response: `[{"id":1,"name":"Notebook"},{"id":2,"name":"Mouse"}]`

## Test Scripts

Automated and manual test scripts are in the `scripts/` folder. All scripts handle setup, testing, and cleanup automatically.

### Phase 1 — Backend API

Compiles and runs the Java backend locally against a PostgreSQL Docker container. Tests all CRUD endpoints (`GET`, `POST`, `PUT`, `DELETE`) and the health check directly on port 8080.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\phase-1-test.ps1
```

### Phase 2 — Backend + Frontend

Same as Phase 1, plus builds the frontend Docker image and verifies that nginx serves the HTML page correctly. Tests backend and frontend independently (no reverse proxy).

```powershell
powershell -ExecutionPolicy Bypass -File scripts\phase-2-test.ps1
```

### Phase 3 — Full Integration

Runs all services via Docker Compose (proxy, frontend, backend, PostgreSQL). Tests all CRUD endpoints through the Nginx reverse proxy on port 80.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\phase-3-test.ps1
```

### Manual tests (browser)

Starts all services and opens the app at http://localhost for manual testing in the browser. Press any key in the terminal to stop and clean up.

```powershell
# Phase 2: Frontend only (backend local, frontend in Docker)
powershell -ExecutionPolicy Bypass -File scripts\phase-2-test-manual.ps1

# Phase 3: Full integration (all services in Docker)
powershell -ExecutionPolicy Bypass -File scripts\phase-3-test-manual.ps1
```

### Skip cleanup

All automated scripts support `-SkipCleanup` to keep services running after tests:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\phase-3-test.ps1 -SkipCleanup
```

## Deliverables

- [x] Phase 0: Project scaffolding
- [x] Phase 1: Backend API (Java 26 Products CRUD)
- [x] Phase 2: Frontend (HTML/JS)
- [x] Phase 3: Reverse proxy (Nginx)
- [x] Phase 4: docker-compose.yml orchestration
- [ ] Phase 5: Data ecosystem (MovieFlix)
- [ ] Phase 6: CI/CD (GitHub Actions)
- [ ] Phase 7: DNS bonus + final README
