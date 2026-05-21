#!/bin/bash

# Navega para o diretório base (onde estão os arquivos loonar)
cd "$(dirname "$0")" || exit 1

if [ "$#" -lt 1 ]; then
    echo "Uso: $0 -d <NomeDoDatabase> [-s <Schema>] [-c <Catalog>]"
    echo "Exemplo: $0 -d 'Morpheus DB' -s 'public'"
    exit 1
fi

COMPOSE_FILE="../docker-compose-loonar.yml"

echo "================================================="
echo "1. Copiando script para o container..."
echo "================================================="
docker cp sync_datasets.py superset_app:/tmp/sync_datasets.py

if [ $? -ne 0 ]; then
    echo "Erro ao copiar o script. O container 'superset_app' está rodando?"
    exit 1
fi

echo "================================================="
echo "2. Executando sincronização dentro do container..."
echo "================================================="
docker exec superset_app python /tmp/sync_datasets.py "$@"

echo "================================================="
echo "Finalizado."
echo "================================================="
