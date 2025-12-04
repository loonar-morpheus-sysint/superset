#!/usr/bin/bash
#
# Setup para instalação REMOTA via Docker Context
# Requer Docker Context remoto já configurado
#

set -euo pipefail

DOCKER_CONTEXT="$1"
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

echo -e "${BLUE}🌐 Configurando Superset para deploy REMOTO via Docker Context${NC}"
echo -e "${CYAN}   Contexto: $DOCKER_CONTEXT${NC}"
echo -e "${CYAN}   Diretório remoto: $REMOTE_DIR${NC}"
echo ""

# Verificar contexto atual
CURRENT_CONTEXT=$(docker context show)
NEED_SWITCH=false

if [ "$CURRENT_CONTEXT" != "$DOCKER_CONTEXT" ]; then
    echo -e "${YELLOW}🔄 Mudando contexto Docker para: $DOCKER_CONTEXT${NC}"
    docker context use "$DOCKER_CONTEXT"
    NEED_SWITCH=true
fi

# Função para restaurar contexto ao sair
cleanup() {
    if [ "$NEED_SWITCH" = true ] && [ -n "$CURRENT_CONTEXT" ]; then
        echo ""
        echo -e "${YELLOW}🔄 Restaurando contexto Docker para: $CURRENT_CONTEXT${NC}"
        docker context use "$CURRENT_CONTEXT"
    fi
}
trap cleanup EXIT

# 1. Verificar e criar diretórios no servidor remoto via container temporário
echo -e "${BLUE}📁 Verificando e criando diretórios no servidor remoto...${NC}"

# Criar toda a estrutura de diretórios de uma vez
echo -e "${CYAN}   Criando estrutura completa de diretórios...${NC}"
if ! docker run --rm \
    -v "$REMOTE_DIR:/remote" \
    alpine:latest \
    sh -c "
        mkdir -p /remote/loonar/volumes/db_home && \
        mkdir -p /remote/loonar/volumes/redis && \
        mkdir -p /remote/loonar/volumes/superset_home && \
        mkdir -p /remote/loonar/volumes/nginx_logs && \
        chmod -R 755 /remote/loonar/volumes/superset_home && \
        chmod -R 755 /remote/loonar/volumes/nginx_logs && \
        echo 'OK'
    "; then
    echo -e "${RED}❌ Erro ao criar diretórios no servidor remoto${NC}"
    echo -e "${YELLOW}   Verifique se:${NC}"
    echo -e "${YELLOW}   - O contexto Docker está correto${NC}"
    echo -e "${YELLOW}   - Você tem permissões no servidor remoto${NC}"
    echo -e "${YELLOW}   - O caminho $REMOTE_DIR é válido${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Diretórios criados no servidor remoto${NC}"

# 2. Copiar arquivos necessários para o contexto remoto
echo ""
echo -e "${BLUE}📦 Preparando arquivos para deploy...${NC}"

# Criar tarball temporário com arquivos necessários para BUILD
TEMP_TAR="/tmp/superset-loonar-deploy-$$.tar.gz"

cd "$PROJECT_ROOT"
tar czf "$TEMP_TAR" \
    --exclude='loonar/volumes/*' \
    --exclude='superset-frontend/node_modules' \
    --exclude='superset-frontend/.npm' \
    --exclude='.git' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    --exclude='.pytest_cache' \
    --exclude='volumes' \
    .

TARBALL_SIZE=$(du -h "$TEMP_TAR" | cut -f1)
echo -e "${GREEN}✅ Arquivos empacotados ($TARBALL_SIZE)${NC}"

# 3. Extrair no servidor remoto usando pipe stdin
echo ""
echo -e "${BLUE}📤 Enviando arquivos para servidor remoto...${NC}"

# Usar pipe para evitar problemas com volumes montados
if ! cat "$TEMP_TAR" | docker run --rm \
    -v "$REMOTE_DIR:/remote" \
    -i \
    alpine:latest \
    sh -c "
        cd /remote && \
        tar xzf - && \
        echo 'OK'
    "; then
    echo -e "${RED}❌ Erro ao extrair arquivos no servidor remoto${NC}"
    rm -f "$TEMP_TAR"
    exit 1
fi

# Limpar arquivo temporário
rm -f "$TEMP_TAR"

echo -e "${GREEN}✅ Arquivos enviados para $REMOTE_DIR${NC}"

# 4. Configurar permissões específicas via container
echo ""
echo -e "${BLUE}🔒 Configurando permissões...${NC}"

if ! docker run --rm \
    -v "$REMOTE_DIR/loonar/volumes:/volumes" \
    alpine:latest \
    sh -c "
        chown -R 999:999 /volumes/db_home 2>/dev/null || chmod -R 755 /volumes/db_home
        chown -R 999:999 /volumes/redis 2>/dev/null || chmod -R 755 /volumes/redis
        chmod 700 /volumes/db_home /volumes/redis 2>/dev/null || true
        chmod -R 755 /volumes/superset_home /volumes/nginx_logs
        echo 'OK'
    "; then
    echo -e "${YELLOW}⚠️  Algumas permissões podem não ter sido configuradas corretamente${NC}"
    echo -e "${YELLOW}   Isso pode requerer ajuste manual no servidor${NC}"
fi

echo -e "${GREEN}✅ Permissões configuradas${NC}"

# 5. Atualizar .env para usar caminhos remotos
echo ""
echo -e "${BLUE}📝 Ajustando configuração do .env...${NC}"

# Verificar se .env existe
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado em $SCRIPT_DIR/${NC}"
    exit 1
fi

# Ler arquivo .env
ENV_CONTENT=$(cat "$SCRIPT_DIR/.env")

# Adicionar/atualizar SUPERSET_VOLUMES_PATH
if echo "$ENV_CONTENT" | grep -q "^SUPERSET_VOLUMES_PATH="; then
    ENV_CONTENT=$(echo "$ENV_CONTENT" | sed "s|^SUPERSET_VOLUMES_PATH=.*|SUPERSET_VOLUMES_PATH=$REMOTE_DIR/loonar/volumes|g")
else
    ENV_CONTENT="${ENV_CONTENT}
SUPERSET_VOLUMES_PATH=$REMOTE_DIR/loonar/volumes"
fi

# Enviar para servidor remoto via stdin
echo "$ENV_CONTENT" | docker run --rm \
    -v "$REMOTE_DIR:/remote" \
    -i \
    alpine:latest \
    sh -c "cat > /remote/loonar/.env"

# Verificar se foi criado
if ! docker run --rm \
    -v "$REMOTE_DIR:/remote" \
    alpine:latest \
    test -f /remote/loonar/.env; then
    echo -e "${RED}❌ Erro ao copiar .env para servidor remoto${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuração ajustada${NC}"

# 6. Build das imagens no contexto remoto
echo ""
echo -e "${BLUE}🏗️  Construindo imagens no servidor remoto...${NC}"
echo -e "${YELLOW}⚠️  Isso pode levar alguns minutos...${NC}"

# Mudar para o diretório do projeto no contexto remoto e fazer build
if ! docker compose \
    -f "$REMOTE_DIR/docker-compose-loonar.yml" \
    --env-file "$REMOTE_DIR/loonar/.env" \
    build; then
    echo -e "${RED}❌ Erro ao construir imagens${NC}"
    echo -e "${YELLOW}   Você pode tentar construir manualmente depois:${NC}"
    echo -e "${YELLOW}   docker context use $DOCKER_CONTEXT${NC}"
    echo -e "${YELLOW}   docker compose -f $REMOTE_DIR/docker-compose-loonar.yml --env-file $REMOTE_DIR/loonar/.env build${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Imagens construídas no servidor remoto${NC}"

# 7. Informações finais
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Setup remoto via Docker Context concluído!        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Próximos passos:${NC}"
echo -e "  ${GREEN}1.${NC} Iniciar serviços:"
echo -e "     ${YELLOW}docker context use $DOCKER_CONTEXT${NC}"
echo -e "     ${YELLOW}cd $REMOTE_DIR${NC}"
echo -e "     ${YELLOW}docker compose --env-file=./loonar/.env -f docker-compose-loonar.yml up -d${NC}"
echo ""
echo -e "  ${GREEN}2.${NC} Ou use o script up.sh adaptado para contexto remoto"
echo ""
echo -e "${CYAN}Contexto atual será restaurado para: $CURRENT_CONTEXT${NC}"
echo ""
