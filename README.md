# ADA - Service and Data Architecture

Final project integrating **Service Architecture** (Docker, Docker Compose, Nginx, CI/CD, DNS) and **Data Architecture** (Data Lake, Data Warehouse, Data Mart, SQL).

## Overview

End-to-end ecosystem with two areas:

1. **Products CRUD application** - Nginx reverse proxy + HTML/JS frontend + Java 26 REST API + PostgreSQL (OLTP).
2. **MovieFlix data ecosystem** - 3-layer architecture: Data Lake (CSV) -> Data Warehouse (PostgreSQL) -> Data Marts (SQL views) with analytical queries.

## Repository Structure

```text
.
+-- .github/workflows/       # CI/CD pipeline
+-- nginx/                   # Reverse proxy
+-- frontend/                # HTML/JS web interface
+-- backend/                 # Java 26 REST API (Products CRUD)
+-- data-ecosystem/
|   +-- datalake/            # Raw CSV files (movies, users, ratings)
|   +-- etl/                 # Python load scripts
|   +-- sql/                 # DW schema, data marts, analytics queries
+-- scripts/                 # Phase test scripts (PowerShell)
+-- docker-compose.yml
+-- README.md
```

## Getting Started

> Documentation in progress - will be completed as phases are implemented.

### CI/CD Secrets

Required in **Settings > Secrets and variables > Actions**:

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `DEPLOY_SSH_PRIVATE_KEY` | SSH key for server deployment |

## Deliverables

- [x] Phase 0: Project scaffolding
- [x] Phase 1: Backend API (Java 26 Products CRUD)
- [x] Phase 2: Frontend (HTML/JS)
- [x] Phase 3: Reverse proxy (Nginx)
- [x] Phase 4: docker-compose.yml orchestration
- [ ] Phase 5: Data ecosystem (MovieFlix)
- [x] Phase 6: CI/CD (GitHub Actions)
- [ ] Phase 7: DNS bonus + final README
