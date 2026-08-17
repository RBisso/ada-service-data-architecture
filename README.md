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
+-- docker-compose.yml
+-- README.md
```

## Getting Started

> Documentation in progress - will be completed as phases are implemented.

## Deliverables

- [x] Phase 0: Project scaffolding
- [ ] Part 1: Service & Application Architecture (Products CRUD)
- [ ] Part 2: CI/CD Pipeline and Container Management
- [ ] Part 3: Data Ecosystem - MovieFlix
- [ ] Part 4: Analytical Queries
- [ ] Part 5: Bonus - DNS
