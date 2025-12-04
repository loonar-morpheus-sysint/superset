#!/usr/bin/bash
#
# Setup para instalação LOCAL do Superset Loonar
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Configurando Superset para instalação LOCAL...${NC}"
echo ""

# 1. Criar diretórios necessários
echo -e "${BLUE}📁 Criando diretórios de volumes...${NC}"
mkdir -p "$SCRIPT_DIR/volumes/"{db_home,redis,superset_home,nginx_logs}

# 2. Configurar permissões
echo -e "${BLUE}🔒 Configurando permissões...${NC}"

# PostgreSQL (UID 999 no container)
if command -v sudo &> /dev/null && [ "$EUID" -ne 0 ]; then
    sudo chown -R 999:999 "$SCRIPT_DIR/volumes/db_home" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Não foi possível usar sudo, tentando sem...${NC}"
        chown -R 999:999 "$SCRIPT_DIR/volumes/db_home" 2>/dev/null || chmod 755 "$SCRIPT_DIR/volumes/db_home"
    }
    sudo chmod 700 "$SCRIPT_DIR/volumes/db_home" 2>/dev/null || chmod 700 "$SCRIPT_DIR/volumes/db_home"

    # Redis (UID 999 no container)
    sudo chown -R 999:999 "$SCRIPT_DIR/volumes/redis" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Não foi possível usar sudo para Redis, tentando sem...${NC}"
        chown -R 999:999 "$SCRIPT_DIR/volumes/redis" 2>/dev/null || chmod 755 "$SCRIPT_DIR/volumes/redis"
    }
    sudo chmod 700 "$SCRIPT_DIR/volumes/redis" 2>/dev/null || chmod 700 "$SCRIPT_DIR/volumes/redis"
else
    echo -e "${YELLOW}⚠️  Executando sem sudo, configurando permissões básicas...${NC}"
    chmod 755 "$SCRIPT_DIR/volumes/db_home" "$SCRIPT_DIR/volumes/redis"
fi

# Superset home e nginx logs
chmod 755 "$SCRIPT_DIR/volumes/superset_home" "$SCRIPT_DIR/volumes/nginx_logs"

# 3. Verificar certificados SSL (opcional)
CERT_DIR="$SCRIPT_DIR/ssl-certs"
if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
    echo -e "${YELLOW}⚠️  Certificados SSL não encontrados em $CERT_DIR${NC}"
    echo -e "${YELLOW}   Esperado: fullchain.pem e privkey.pem${NC}"
    echo ""
    read -p "Continuar sem SSL? [s/N]: " CONTINUE_NO_SSL
    if [[ ! "$CONTINUE_NO_SSL" =~ ^[sS]$ ]]; then
        echo -e "${RED}❌ Setup cancelado${NC}"
        exit 1
    fi
    echo -e "${YELLOW}⚠️  Continuando sem SSL (não recomendado para produção)${NC}"
fi

# 4. Copiar configuração de produção se existir
if [ -f "$SCRIPT_DIR/pythonpath/superset_config_production.py" ]; then
    echo -e "${BLUE}📝 Usando configuração de produção...${NC}"
    cp "$SCRIPT_DIR/pythonpath/superset_config_production.py" \
       "$SCRIPT_DIR/pythonpath/superset_config.py"
fi

# 5. Adicionar volumes ao .dockerignore
if [ -f "$PROJECT_ROOT/.dockerignore" ]; then
    if ! grep -q "^loonar/volumes/$" "$PROJECT_ROOT/.dockerignore" 2>/dev/null; then
        echo -e "${BLUE}📝 Adicionando volumes ao .dockerignore...${NC}"
        echo "loonar/volumes/" >> "$PROJECT_ROOT/.dockerignore"
    fi
fi

# 6. Build das imagens
echo ""
echo -e "${BLUE}🏗️  Construindo imagens Docker...${NC}"
cd "$PROJECT_ROOT"

# Verificar se deve fazer build
echo -e "${YELLOW}Deseja fazer build das imagens? [S/n]: ${NC}"
read -p "" DO_BUILD

if [[ ! "$DO_BUILD" =~ ^[nN]$ ]]; then
    docker compose --env-file="$SCRIPT_DIR/.env" -f docker-compose-loonar.yml build
else
    echo -e "${YELLOW}⚠️  Pulando build (usando imagens existentes)${NC}"
fi

echo ""
echo -e "${GREEN}✅ Setup local concluído!${NC}"
echo ""
echo -e "${BLUE}Próximos passos:${NC}"
echo -e "  ${GREEN}1.${NC} Revisar arquivo .env em: $SCRIPT_DIR/.env"
echo -e "  ${GREEN}2.${NC} Iniciar serviços com: ${YELLOW}./loonar/up.sh${NC}"
echo -e "  ${GREEN}3.${NC} Acessar em: ${YELLOW}http://\$(grep SUPERSET_HOST $SCRIPT_DIR/.env | cut -d= -f2)${NC}"
echo ""
