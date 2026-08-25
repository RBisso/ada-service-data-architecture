#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_DIRECTORY="/opt/ada-service-data-architecture"

echo "Iniciando deploy em ${PROJECT_DIRECTORY}..."

mkdir -p "${PROJECT_DIRECTORY}"
cd "${PROJECT_DIRECTORY}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker nao encontrado no servidor."
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  docker compose up --build -d
  docker compose ps
  exit 0
fi

echo "Docker Compose plugin nao encontrado no servidor."
exit 1
