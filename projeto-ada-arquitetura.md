# Final Project: Service and Data Architecture

## Overview

This project aims to practically integrate the concepts of **Service Architecture** (Docker, Docker Compose, Nginx, CI/CD, DNS) and **Data Architecture** (Data Lake, Data Warehouse, Data Mart, SQL queries) into an end-to-end ecosystem.

---

## Groups

This project may be done in groups of up to 3 people.

---

## Part 1: Service and Application Architecture (Products CRUD)

The application ecosystem infrastructure will be orchestrated via Docker Compose and will contain **4 services**:

```text
[ Client / Browser ]
            |
            v
    [ Reverse Proxy ] (Nginx) - Porta 80
            |
            +---> [ Web Server / Frontend ] (HTML/JS)
            |
            +---> [ Application Server / API ] (Node, Python, Go, Java, etc)
                            |
                            v
                    [ OLTP Database ] (PostgreSQL/MySQL)
```

### Infrastructure Requirements

1. **Reverse Proxy (Nginx):**

    * Single point of entry on port`80`.
    * Redirects web requests to the Frontend container and `/api/*` calls to the API container.

2. **Web Server (Frontend):**

    * Interface web simples para gerenciamento de produtos (Listar, Adicionar, Editar e Deletar).

3. **Application Server (API REST):**

    * Mandatory endpoints:
    * `GET /api/products` - Lists all products
    * `GET /API/products/{id}` - Search product by Id
    * `POST /api/products` - Registers a new product
    * `PUT /api/products/{id}` - Updates a productby Id
    * `DELETE /api/produts/{id}` - Deletes a product Id

4. **Banco de dados Operacional (OLTP):**

    * Relational DBMS with table `products`:
        * `id` (INT, Primary Key, Auto Increment/Serial)
        * `name` (VARCHAR(50), NOT NULL)

---

## Parte 2: CI/CD Pipeline and Container Management

Set up an automated CI/CD pipeline (e.g., **GitHub Actions**).

### Pipeline Flow

* **Trigger:** Push to the repository.
* **Steps:**
    1. **Build:** Building the Docker images for the services.
    2. **Test:** Simple smoke test (e.g., verifying that containers start up and respond on the correct port).
    3. **Push:** Publishing the images to **Docker Hub**.

---

## Part 3: Data Ecossystem - MovieFlix

Simulate a 3-layer data architecture:

1. **Data Lake (Raw Data):** CSV files stored in a local directory/volume (`movies.csv`, `users.csv`, `ratings.csv`).
2. **Data Warehouse (Processed Data):** Analytical database (e.g., PostgreSQL) populated via load scripts (Python/SQL).
3. **Data Marts (Business Views):** Creation of SQL `VIEWS`:
    * **View 1:** Top 10 highest-rated movies by genre.
    * **View 2:** Average rating by user age group.
    * **View 3:** Number of ratings by country.

---

## Part 4: Analytical Queries (Business)

Direct SQL queries to answer:

1. What are the **5 most popular movies** (highest number of ratings)?
2. Which **genre** has the highest average rating?
3. Which **country** watches/rates the most movies?

---

## Part 5: Bonus (DNS)

* Pointing a free domain or subdomain (e.g., **DuckDNS**, **No-IP**) to the application.

---

## Project Deliverables

1. **GitHub Repository:** Source code, `Dockerfiles`, `docker-compose.yml`, CI/CD pipeline, load/SQL scripts, and an explanatory `README.md`.
2. **Practical Demonstration:** Functional pipeline on GitHub Actions, images on Docker Hub, application accessible via Proxy/DNS, and analytical query results.

---

## Recommended Folder Structure

```text
meu-projeto/
+-- .github/
|   +-- workflows/
|       +-- main.yml             # CI/CD Pipeline
+-- nginx/
|   +-- DockerFile
|   +-- nginx.conf               # Reverse proxy configuration
+-- frontend/
|   +-- Dockerfile
|   +-- index.html               # Simple web Interface (HTML/JS)
+-- backend/
|   +-- Dockerfile
|   +-- ....                     # API code (node, Python, etc)
+-- data-ecosystem/
|   +-- datalake/
|   |   +-- movies.csv
|   |   +-- users.csv
|   |   +-- ratings.csv
|   +-- etl/                     # Load script (ex: Python, Bash)
|   |   +-- load_dw.py
|   +-- sql/
|   |   +-- 01_dw_schema.sql
|   |   +-- 02_datamarts.sql
|   |   +-- 03_analytics.sql
+-- docker-compose.yml
+-- README.md
```

## Example of `docker-compose.yml` file

```yaml
version: '3.8'

services:
    #1. Reverse Proxy (Nginx)
    proxy:
        build: ./nginx
        container_name: reverse_proxy
        ports:
            - "80:80"
        depends_on:
            - frontend
            - backend
        networks:
            - app-network

    #2. Web Server (Fronted)
    frontend:
        build: ./frontend
        container_name: web_frontend
        networks:
            - app-network
    
    #3. Application Server (API REST)
    backend:
        build: /.backend
        container_name: api_backend
        environment:
            - DB_HOST=db_oltp
            - DB_USER=app_user
            - DB_PASSWORD=app_pass
            - DB_NAME=products_db
            - DB_PORT=5432
        depends_on:
            - db_oltp
        networks:
            - app-network
    
    #4 OPERATIONAL DATABASE (OLTP - PRODUCT Registration)
    db_oltp:
        image: postgres:15-alpine
        container_name: db_oltp
        environment:
            POSTGRES_USER: app_user
            POSTGRESS_PASSWORD: app_pass
            POSTGRES_DB: products_db
        ports:
            - "5432:5432"
        volumes:
            - oltp_data:/var/lib/postgresql/data
        networks:
            - app-network
    
    #5 ANALYTICAL DATABASE
    db_dw:
        image: postgres:15-alpine
        container_name: db_dw
        environment:
            POSTGRES_USER: dw_user
            POSTGRESS_PASSWORD: dw_pass
            POSTGRES_DB: movieflix_dw
        ports:
            - "5432:5432"
        volumes:
            - dw_data:/var/lib/postgresql/data
            - ./data-ecosystem/datalake:/datalake #Map the raw CSVs from Data Lake
        networks:
            - app-network

networks:
    app-network:
        driver: bridge

volumes:
    oltp_data:
    dw_data:

```

## Example of Reverse Proxy configuration (`nginx/nginx.conf)

```nginx
server {
    listen 80;
    #Frontend
    location / {
        proxy_pass http://frontend:80;
    }
    #Backend
    location /api/ {
        proxy_pass http://backend:3000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
