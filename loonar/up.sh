#!/usr/bin/bash
#
# Script para iniciar o Superset Loonar
# Verifica e configura permissões dos volumes antes de iniciar
#

clear

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Iniciando Superset Loonar..."
echo ""

# Verificar se arquivos necessários existem no mesmo diretório do script
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "❌ Erro: Arquivo .env não encontrado em $SCRIPT_DIR/"
    echo "   O arquivo .env deve estar no mesmo diretório do script up.sh"
    exit 1
fi


# Verificar se volumes existem, senão criar com setup
if [ ! -d "$SCRIPT_DIR/volumes/superset_home" ] || \
   [ ! -d "$SCRIPT_DIR/volumes/db_home" ] || \
   [ ! -d "$SCRIPT_DIR/volumes/redis" ]; then
    echo "⚠️  Volumes não encontrados. Executando setup..."
    "$SCRIPT_DIR/setup-production.sh"
else
    # Garantir que as permissões estejam corretas
    echo "✓ Volumes encontrados. Verificando permissões..."
    sudo chown -R "$USER:$USER" "$SCRIPT_DIR/volumes/superset_home" "$SCRIPT_DIR/volumes/redis" 2>/dev/null || true
    sudo chown -R 999:999 "$SCRIPT_DIR/volumes/db_home" 2>/dev/null || true
    chmod 755 "$SCRIPT_DIR/volumes" "$SCRIPT_DIR/volumes"/* 2>/dev/null || true
fi

# Iniciar containers
echo "📦 Iniciando containers..."
cd "$PROJECT_ROOT"
docker compose --env-file=./loonar/.env -f docker-compose-loonar.yml up -d

echo ""
echo "✅ Containers iniciados!"
echo ""

# Aguardar banco de dados estar pronto
echo "⏳ Aguardando banco de dados estar pronto..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker exec superset_db pg_isready -U superset > /dev/null 2>&1; then
        echo "✓ Banco de dados pronto!"
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Timeout aguardando banco de dados"
    exit 1
fi

# Executar migrações do banco de dados
echo "🔧 Aplicando migrações do banco de dados..."
docker exec superset_app superset db upgrade

# Criar usuário admin se não existir
echo "👤 Verificando usuário admin..."
docker exec superset_app superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@superset.com \
    --password admin 2>/dev/null || echo "   Usuário admin já existe"

# Inicializar roles e permissões
echo "🔐 Inicializando roles e permissões..."
docker exec superset_app superset init

echo ""
echo "📊 Status dos containers:"
docker compose --env-file=./loonar/.env -f docker-compose-loonar.yml ps
echo ""
# Obter host configurado
HOST_URL=$(grep "^SUPERSET_HOST=" "$SCRIPT_DIR/.env" | cut -d '=' -f2)
[ -z "$HOST_URL" ] && HOST_URL="localhost"

echo "💡 Dicas:"
echo "   - Logs da inicialização: docker logs -f superset_init"
echo "   - Logs da aplicação: docker logs -f superset_app"
echo "   - Acesse em: http://$HOST_URL"
echo ""
