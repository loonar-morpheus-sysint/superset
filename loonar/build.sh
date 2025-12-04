#!/usr/bin/bash

clear

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verificar existência dos arquivos necessários
REQUIRED_FILES=(
    "$SCRIPT_DIR/.env"
    "../docker-compose-loonar.yml"
)

MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$(basename "$file")")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo "❌ Erro: Os seguintes arquivos não foram encontrados em $SCRIPT_DIR/:"
    for file in "${MISSING_FILES[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

# Verificar se volumes existem, senão criar com setup
if [ ! -d "$SCRIPT_DIR/volumes/superset_home" ] || \
   [ ! -d "$SCRIPT_DIR/volumes/db_home" ] || \
   [ ! -d "$SCRIPT_DIR/volumes/redis" ]; then
    echo "⚠️  Volumes não encontrados. Executando setup..."
    "$SCRIPT_DIR/setup.sh"
fi

echo "✓ Todos os arquivos necessários encontrados. Iniciando build..."

cd "$SCRIPT_DIR" || exit
cd .. # Navegar para o diretório pai onde o docker-compose-loonar.yml está localizado
docker compose --env-file=./loonar/.env -f ./loonar/docker-compose-loonar.yml build --no-cache
