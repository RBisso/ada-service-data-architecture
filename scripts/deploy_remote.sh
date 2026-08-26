#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_DIRECTORY="/opt/ada-service-data-architecture"
readonly DEPLOY_RUNTIME_DIRECTORY="/var/run/ada-service-data-architecture"
readonly DEPLOY_EXIT_CODE_FILE="${DEPLOY_RUNTIME_DIRECTORY}/deploy.exit"

deploy_status=1

mkdir -p "${DEPLOY_RUNTIME_DIRECTORY}"
rm -f "${DEPLOY_EXIT_CODE_FILE}"

trap 'printf "%s\n" "${deploy_status}" > "${DEPLOY_EXIT_CODE_FILE}"' EXIT

echo "Iniciando deploy em ${PROJECT_DIRECTORY}..."

mkdir -p "${PROJECT_DIRECTORY}"
cd "${PROJECT_DIRECTORY}"

export DOCKER_BUILDKIT=1
export COMPOSE_BAKE=true
export BUILDKIT_PROGRESS=plain

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker nao encontrado no servidor."
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  docker compose up --build -d
  docker compose ps
  deploy_status=0
  exit 0
fi

echo "Docker Compose plugin nao encontrado no servidor."
exit 1
