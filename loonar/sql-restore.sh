#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

set -euo pipefail

# Uso:
#   ./loonar/sql-restore.sh user@origem:/caminho/backup.sql.gz
#   ./loonar/sql-restore.sh user@origem:/caminho/backup.sql ./backup/local.sql
#
# Variáveis ajustáveis via ambiente:
#   COMPOSE_FILE (padrão: docker-compose-loonar.yml)
#   DB_SERVICE   (padrão: db)
#   DB_CONTAINER (padrão: superset_db)
#   DB_USER      (padrão: superset)
#   DB_NAME      (padrão: superset)

SRC_REMOTE=${1:-}
DEST_LOCAL=${2:-}
if [[ -z "${SRC_REMOTE}" ]]; then
  echo "Erro: informe o arquivo remoto (ex: user@host:/caminho/backup.sql.gz)"
  exit 1
fi

COMPOSE_FILE=${COMPOSE_FILE:-docker-compose-loonar.yml}
DB_SERVICE=${DB_SERVICE:-db}
DB_CONTAINER=${DB_CONTAINER:-superset_db}
DB_USER=${DB_USER:-superset}
DB_NAME=${DB_NAME:-superset}

if [[ -z "${DEST_LOCAL}" ]]; then
  DEST_LOCAL="/tmp/$(basename "${SRC_REMOTE}")"
fi

echo "📥 Copiando backup via SCP..."
scp "${SRC_REMOTE}" "${DEST_LOCAL}"

echo "⏹ Parando serviços de aplicação (mantendo o banco)..."
docker compose -f "${COMPOSE_FILE}" stop superset_app superset_worker superset_worker_beat superset_worker_beat || true

echo "🗄  Subindo o serviço de banco..."
docker compose -f "${COMPOSE_FILE}" up -d "${DB_SERVICE}"

echo "⌛ Aguardando banco ficar saudável..."
docker compose -f "${COMPOSE_FILE}" exec "${DB_SERVICE}" pg_isready -U "${DB_USER}"

RESTORE_CMD="psql -U ${DB_USER} ${DB_NAME}"
if [[ "${DEST_LOCAL}" == *.gz ]]; then
  echo "🔄 Restaurando (gzip)..."
  gunzip -c "${DEST_LOCAL}" | docker exec -i "${DB_CONTAINER}" ${RESTORE_CMD}
else
  echo "🔄 Restaurando..."
  cat "${DEST_LOCAL}" | docker exec -i "${DB_CONTAINER}" ${RESTORE_CMD}
fi

echo "🚀 Reiniciando todos os serviços..."
docker compose -f "${COMPOSE_FILE}" up -d

echo "✅ Restauração concluída a partir de: ${DEST_LOCAL}"
