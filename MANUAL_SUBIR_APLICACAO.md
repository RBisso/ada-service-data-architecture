# Manual para Subir a Aplicacao Localmente

Este documento descreve o passo a passo para iniciar a aplicacao localmente usando Docker Compose.

## Visao Geral

A aplicacao e composta por 6 servicos:

- `proxy`: Nginx responsavel por expor a aplicacao na porta `80`
- `frontend`: interface web estatica
- `backend`: API Java exposta internamente na porta `8080`
- `db_oltp`: banco PostgreSQL exposto na porta `5432`
- `db_dw`: Data Warehouse (PostgreSQL) exposto na porta `5433`
- `etl`: job one-shot que carrega o Data Warehouse (executa e encerra)

## Pre-requisitos

Antes de iniciar, confirme que voce possui:

- Docker Desktop instalado
- Docker Compose disponivel no terminal
- Porta `80` livre
- Porta `5432` livre
- Porta `5433` livre

Para validar:

```bash
docker --version
docker compose version
```

Se estiver no macOS, garanta que o Docker Desktop esteja aberto antes de subir a stack.

## Como subir a aplicacao

Na raiz do projeto, execute:

```bash
docker compose up --build -d
```

Esse comando:

- constroi as imagens de `frontend`, `backend` e `proxy`
- baixa a imagem do PostgreSQL, se necessario
- cria a rede da aplicacao
- cria o volume persistente do banco
- sobe todos os containers em segundo plano

## Como verificar se tudo subiu corretamente

### 1. Verificar o status dos containers

```bash
docker compose ps
```

O esperado e que os servicos abaixo estejam em execucao:

- `reverse_proxy`
- `web_frontend`
- `api_backend`
- `db_oltp`
- `db_dw`

O container `movieflix_etl` e um job one-shot: ele executa, carrega o Data Warehouse e encerra (status `Exited (0)`).

### 2. Validar o health check da aplicacao

```bash
curl http://localhost/health
```

Resposta esperada:

```json
{"status":"ok"}
```

### 3. Validar a API de produtos

```bash
curl http://localhost/api/products
```

Resposta esperada no ambiente inicial:

```json
[]
```

### 4. Acessar a interface web

Abra no navegador:

```text
http://localhost
```

## Endpoints uteis

- Aplicacao web: `http://localhost`
- Health check: `http://localhost/health`
- API de produtos: `http://localhost/api/products`
- OpenAPI JSON: `http://localhost/openapi.json`
- Swagger UI: `http://localhost/swagger`
- PostgreSQL local (OLTP): `localhost:5432`
- Data Warehouse (MovieFlix): `localhost:5433`

## Como validar o Data Warehouse

Para verificar que o ETL carregou os dados corretamente:

```bash
docker logs movieflix_etl
```

Para consultar as views analiticas do MovieFlix:

```bash
docker exec db_dw psql -U dw_user -d movieflix_dw -c "SELECT * FROM v_ratings_by_country;"
```

## Como parar a aplicacao

Para parar os containers sem remover os dados do banco:

```bash
docker compose down
```

Para parar os containers e remover tambem o volume do banco:

```bash
docker compose down -v
```

Use `-v` apenas quando quiser reiniciar completamente os dados locais.

## Como acompanhar logs

Para visualizar os logs de todos os servicos:

```bash
docker compose logs -f
```

Para visualizar apenas os logs do backend:

```bash
docker compose logs -f backend
```

Para visualizar apenas os logs do proxy:

```bash
docker compose logs -f proxy
```

## Problemas comuns

### Docker daemon nao esta em execucao

Sintoma:

```text
Cannot connect to the Docker daemon
```

Solucao:

- abra o Docker Desktop
- aguarde ele finalizar a inicializacao
- execute novamente `docker compose up --build -d`

### Porta 80 em uso

Sintoma:

```text
bind: address already in use
```

Solucao:

- pare o processo que ja esta usando a porta `80`
- ou ajuste o mapeamento da porta no `docker-compose.yml`

### Porta 5432 em uso

Se ja existir outro PostgreSQL rodando localmente, a subida do banco pode falhar.

Solucao:

- pare o PostgreSQL local que estiver usando a porta `5432`
- ou altere o mapeamento da porta no `docker-compose.yml`

## Observacoes

- O banco utiliza volume Docker para persistencia dos dados
- O backend depende do banco saudavel antes de iniciar
- O proxy depende do backend saudavel para ficar disponivel
