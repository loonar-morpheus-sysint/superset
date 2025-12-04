#!/usr/bin/bash
#
# Setup para instalação REMOTA via SSH
# Copia arquivos e executa setup no servidor remoto
#

set -euo pipefail

SSH_HOST="$1"
REMOTE_DIR="$2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🔐 Configurando Superset para deploy REMOTO via SSH${NC}"
echo -e "${CYAN}   SSH Host: $SSH_HOST${NC}"
echo -e "${CYAN}   Diretório remoto: $REMOTE_DIR${NC}"
echo ""

# 1. Verificar se servidor remoto tem Docker instalado
echo -e "${BLUE}🔍 Verificando requisitos no servidor remoto...${NC}"

if ! ssh "$SSH_HOST" "command -v docker &>/dev/null"; then
    echo -e "${RED}❌ Docker não está instalado no servidor remoto${NC}"
    echo -e "${YELLOW}   Instale o Docker no servidor antes de continuar${NC}"
    exit 1
fi

if ! ssh "$SSH_HOST" "command -v docker compose &>/dev/null && docker compose version &>/dev/null || docker-compose --version &>/dev/null"; then
    echo -e "${RED}❌ Docker Compose não está instalado ou não é a versão plugin${NC}"
    echo -e "${YELLOW}   Instale Docker Compose (plugin) no servidor${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker e Docker Compose disponíveis no servidor remoto${NC}"

# 2. Criar diretórios no servidor remoto
echo ""
echo -e "${BLUE}📁 Criando diretórios no servidor remoto...${NC}"

# Criar diretório base se não existir
if ! ssh "$SSH_HOST" "test -d $REMOTE_DIR" 2>/dev/null; then
    echo -e "${CYAN}   Criando diretório base: $REMOTE_DIR${NC}"
    if ! ssh "$SSH_HOST" "mkdir -p $REMOTE_DIR" 2>/dev/null; then
        echo -e "${RED}❌ Erro ao criar diretório base${NC}"
        echo -e "${YELLOW}   Você pode precisar de permissões sudo no servidor${NC}"
        echo ""
        read -p "Tentar com sudo? [s/N]: " USE_SUDO

        if [[ "$USE_SUDO" =~ ^[sS]$ ]]; then
            ssh "$SSH_HOST" "sudo mkdir -p $REMOTE_DIR && sudo chown \$USER:\$USER $REMOTE_DIR"
        else
            exit 1
        fi
    fi
fi

# Criar estrutura de volumes
ssh "$SSH_HOST" "mkdir -p $REMOTE_DIR/loonar/volumes/{db_home,redis,superset_home,nginx_logs}"

echo -e "${GREEN}✅ Diretórios criados${NC}"

# 3. Criar tarball com arquivos necessários
echo ""
echo -e "${BLUE}📦 Preparando arquivos para envio...${NC}"

TEMP_TAR="/tmp/superset-loonar-$$.tar.gz"

cd "$PROJECT_ROOT"
tar czf "$TEMP_TAR" \
    --exclude='loonar/volumes/*' \
    --exclude='superset-frontend/node_modules' \
    --exclude='superset-frontend/.npm' \
    --exclude='.git' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    --exclude='.pytest_cache' \
    .

echo -e "${GREEN}✅ Arquivos empacotados ($(du -h "$TEMP_TAR" | cut -f1))${NC}"

# 4. Enviar arquivos via SCP
echo ""
echo -e "${BLUE}📤 Enviando arquivos para servidor remoto...${NC}"
echo -e "${YELLOW}⚠️  Isso pode levar alguns minutos dependendo da conexão...${NC}"

scp "$TEMP_TAR" "$SSH_HOST:$REMOTE_DIR/superset.tar.gz"

# Limpar arquivo local
rm -f "$TEMP_TAR"

echo -e "${GREEN}✅ Arquivos enviados${NC}"

# 5. Extrair arquivos no servidor remoto
echo ""
echo -e "${BLUE}📂 Extraindo arquivos no servidor remoto...${NC}"

ssh "$SSH_HOST" "cd $REMOTE_DIR && tar xzf superset.tar.gz && rm superset.tar.gz"

echo -e "${GREEN}✅ Arquivos extraídos${NC}"

# 6. Configurar permissões no servidor remoto
echo ""
echo -e "${BLUE}🔒 Configurando permissões...${NC}"

ssh "$SSH_HOST" bash << 'REMOTE_PERMISSIONS'
set -e

REMOTE_DIR="$1"

# PostgreSQL e Redis (UID 999)
if command -v sudo &> /dev/null; then
    sudo chown -R 999:999 "$REMOTE_DIR/loonar/volumes/db_home" 2>/dev/null || chmod 755 "$REMOTE_DIR/loonar/volumes/db_home"
    sudo chmod 700 "$REMOTE_DIR/loonar/volumes/db_home" 2>/dev/null || true

    sudo chown -R 999:999 "$REMOTE_DIR/loonar/volumes/redis" 2>/dev/null || chmod 755 "$REMOTE_DIR/loonar/volumes/redis"
    sudo chmod 700 "$REMOTE_DIR/loonar/volumes/redis" 2>/dev/null || true
else
    chown -R 999:999 "$REMOTE_DIR/loonar/volumes/db_home" 2>/dev/null || chmod 755 "$REMOTE_DIR/loonar/volumes/db_home"
    chmod 700 "$REMOTE_DIR/loonar/volumes/db_home" 2>/dev/null || true

    chown -R 999:999 "$REMOTE_DIR/loonar/volumes/redis" 2>/dev/null || chmod 755 "$REMOTE_DIR/loonar/volumes/redis"
    chmod 700 "$REMOTE_DIR/loonar/volumes/redis" 2>/dev/null || true
fi

# Superset home e nginx logs
chmod 755 "$REMOTE_DIR/loonar/volumes/superset_home"
chmod 755 "$REMOTE_DIR/loonar/volumes/nginx_logs"

echo "Permissões configuradas"
REMOTE_PERMISSIONS

ssh "$SSH_HOST" "$(declare -f); bash -s" "$REMOTE_DIR" << 'REMOTE_PERMISSIONS'
set -e
REMOTE_DIR="$1"

if command -v sudo &> /dev/null; then
    sudo chown -R 999:999 "$REMOTE_DIR/loonar/volumes/db_home" 2>/dev/null || chmod 755 "$REMOTE_DIR/loonar/volumes/db_home"
    sudo chmod 700 "$REMOTE_DIR/loonar/volumes/db_home" 2>/dev/null || true
    sudo chown -R 999:999 "$REMOTE_DIR/loonar/volumes/redis" 2>/dev/null || chmod 755 "$REMOTE_DIR/loonar/volumes/redis"
    sudo chmod 700 "$REMOTE_DIR/loonar/volumes/redis" 2>/dev/null || true
else
    chmod 755 "$REMOTE_DIR/loonar/volumes/db_home" "$REMOTE_DIR/loonar/volumes/redis"
fi
chmod 755 "$REMOTE_DIR/loonar/volumes/superset_home" "$REMOTE_DIR/loonar/volumes/nginx_logs"
REMOTE_PERMISSIONS

echo -e "${GREEN}✅ Permissões configuradas${NC}"

# 7. Build das imagens no servidor remoto
echo ""
echo -e "${BLUE}🏗️  Construindo imagens Docker no servidor remoto...${NC}"
echo -e "${YELLOW}⚠️  Isso pode levar vários minutos...${NC}"

ssh "$SSH_HOST" bash << REMOTE_BUILD
set -e
cd "$REMOTE_DIR"

# Detectar comando docker compose
if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
elif docker-compose --version &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ Docker Compose não encontrado"
    exit 1
fi

echo "🏗️  Usando: \$COMPOSE_CMD"

\$COMPOSE_CMD --env-file=./loonar/.env -f docker-compose-loonar.yml build

echo "✅ Build concluído"
REMOTE_BUILD

echo -e "${GREEN}✅ Imagens construídas no servidor remoto${NC}"

# 8. Criar script de gerenciamento remoto
echo ""
echo -e "${BLUE}📝 Criando script de gerenciamento remoto...${NC}"

cat > "/tmp/remote-manage-$$.sh" << 'REMOTE_SCRIPT'
#!/bin/bash
# Script de gerenciamento do Superset no servidor remoto

set -e

REMOTE_DIR="__REMOTE_DIR__"
cd "$REMOTE_DIR"

# Detectar comando docker compose
if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
elif docker-compose --version &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ Docker Compose não encontrado"
    exit 1
fi

case "${1:-}" in
    start|up)
        echo "🚀 Iniciando Superset..."
        $COMPOSE_CMD --env-file=./loonar/.env -f docker-compose-loonar.yml up -d

        echo "⏳ Aguardando serviços..."
        sleep 10

        echo "🔧 Aplicando migrações..."
        docker exec superset_app superset db upgrade

        echo "👤 Criando usuário admin..."
        docker exec superset_app superset fab create-admin \
            --username admin \
            --firstname Admin \
            --lastname User \
            --email admin@superset.com \
            --password admin 2>/dev/null || echo "   Usuário já existe"

        echo "🔐 Inicializando..."
        docker exec superset_app superset init

        echo "✅ Superset iniciado!"
        $COMPOSE_CMD --env-file=./loonar/.env -f docker-compose-loonar.yml ps
        ;;

    stop|down)
        echo "🛑 Parando Superset..."
        $COMPOSE_CMD --env-file=./loonar/.env -f docker-compose-loonar.yml down
        echo "✅ Superset parado"
        ;;

    restart)
        echo "🔄 Reiniciando Superset..."
        $0 stop
        sleep 3
        $0 start
        ;;

    status|ps)
        $COMPOSE_CMD --env-file=./loonar/.env -f docker-compose-loonar.yml ps
        ;;

    logs)
        $COMPOSE_CMD --env-file=./loonar/.env -f docker-compose-loonar.yml logs -f "${2:-}"
        ;;

    *)
        echo "Uso: $0 {start|stop|restart|status|logs [service]}"
        exit 1
        ;;
esac
REMOTE_SCRIPT

# Substituir placeholder
sed -i "s|__REMOTE_DIR__|$REMOTE_DIR|g" "/tmp/remote-manage-$$.sh"

# Enviar script
scp "/tmp/remote-manage-$$.sh" "$SSH_HOST:$REMOTE_DIR/manage-superset.sh"
ssh "$SSH_HOST" "chmod +x $REMOTE_DIR/manage-superset.sh"

# Limpar arquivo local
rm -f "/tmp/remote-manage-$$.sh"

echo -e "${GREEN}✅ Script de gerenciamento criado${NC}"

# 9. Informações finais
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Setup remoto via SSH concluído!                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Próximos passos:${NC}"
echo ""
echo -e "${CYAN}No servidor remoto ($SSH_HOST):${NC}"
echo -e "  ${GREEN}Iniciar:${NC}    ${YELLOW}$REMOTE_DIR/manage-superset.sh start${NC}"
echo -e "  ${GREEN}Parar:${NC}      ${YELLOW}$REMOTE_DIR/manage-superset.sh stop${NC}"
echo -e "  ${GREEN}Status:${NC}     ${YELLOW}$REMOTE_DIR/manage-superset.sh status${NC}"
echo -e "  ${GREEN}Logs:${NC}       ${YELLOW}$REMOTE_DIR/manage-superset.sh logs${NC}"
echo ""
echo -e "${CYAN}Ou conecte via SSH:${NC}"
echo -e "  ${YELLOW}ssh $SSH_HOST${NC}"
echo -e "  ${YELLOW}cd $REMOTE_DIR${NC}"
echo -e "  ${YELLOW}./manage-superset.sh start${NC}"
echo ""
