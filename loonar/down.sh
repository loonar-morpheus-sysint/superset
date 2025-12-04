#!/usr/bin/bash
#
# Script para parar o Superset Loonar
# Opções:
#   -v  Remove volumes (apaga dados!)
#   -c  Remove volumes e limpa completamente
#

clear

# ============================================================================
# CORES E ESTILOS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # Sem cor

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} $1"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_action() {
    echo -e "${MAGENTA}→ $1${NC}"
}

show_menu() {
    echo ""
    echo -e "${CYAN}┌─ Selecione a ação a executar:${NC}"
    echo -e "${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} ${MAGENTA}1${NC} - Parar Superset (preservar dados)"
    echo -e "${BLUE}│${NC}   ${BLUE}Containers são parados, volumes mantêm os dados${NC}"
    echo -e "${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} ${MAGENTA}2${NC} - Parar Superset E remover volumes"
    echo -e "${BLUE}│${NC}   ${RED}⚠️  AVISO: Todos os dados serão perdidos!${NC}"
    echo -e "${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} ${MAGENTA}3${NC} - Limpeza completa (volumes + diretórios)"
    echo -e "${BLUE}│${NC}   ${RED}⚠️  AVISO: Todas as configurações e dados serão perdidos!${NC}"
    echo -e "${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} ${MAGENTA}0${NC} - Cancelar"
    echo -e "${BLUE}│${NC}"
    echo -e "${CYAN}└─${NC}"
    echo ""
}

ask_confirmation() {
    local prompt=$1
    local default=$2
    local response

    while true; do
        echo -n -e "${YELLOW}${prompt}${NC} "
        read -r response

        case "$response" in
            [Ss])
                return 0
                ;;
            [Nn])
                return 1
                ;;
            *)
                print_info "Por favor, responda com 's' ou 'n'"
                ;;
        esac
    done
}

check_file_exists() {
    local file=$1
    if [ ! -f "$file" ]; then
        print_error "Arquivo '$file' não encontrado em $(pwd)"
        exit 1
    fi
}

# ============================================================================
# CONFIGURAÇÕES E VARIÁVEIS
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VOLUMES_DIR="${SCRIPT_DIR}/volumes"

# Nomes de arquivos necessários (com caminho absoluto)
ENV_FILE="$PROJECT_ROOT/loonar/.env"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose-loonar.yml"

# Diretórios de volumes
VOLUMES_DIR="${SCRIPT_DIR}/volumes"

# Flags de operação
REMOVE_VOLUMES=false
CLEAN_ALL=false

# Comando Docker Compose
DOCKER_CMD="docker compose -f ${COMPOSE_FILE} --env-file=${ENV_FILE}"

# ============================================================================
# PROCESSAMENTO DE ARGUMENTOS
# ============================================================================

HAS_ARGS=false

while getopts "vc" opt; do
  HAS_ARGS=true
  case $opt in
    v)
      REMOVE_VOLUMES=true
      ;;
    c)
      CLEAN_ALL=true
      REMOVE_VOLUMES=true
      ;;
    \?)
      echo "Uso: $0 [-v] [-c]"
      echo "  -v  Remove volumes Docker"
      echo "  -c  Remove volumes E limpa diretórios locais"
      exit 1
      ;;
  esac
done


# ============================================================================
# VALIDAÇÕES
# ============================================================================

clear
print_header "🛑 Parando Superset Loonar"

cd "$PROJECT_ROOT" || exit 1

check_file_exists "$ENV_FILE"
check_file_exists "$COMPOSE_FILE"
print_success "Arquivos de configuração validados"
echo ""

# Se não houver argumentos, mostrar menu interativo
if [ "$HAS_ARGS" = false ]; then
    show_menu
    read -rp "Escolha uma opção [0-3]: " choice

    case $choice in
        1)
            REMOVE_VOLUMES=false
            CLEAN_ALL=false
            ;;
        2)
            REMOVE_VOLUMES=true
            CLEAN_ALL=false
            ;;
        3)
            REMOVE_VOLUMES=true
            CLEAN_ALL=true
            ;;
        0)
            print_info "Operação cancelada pelo usuário"
            exit 0
            ;;
        *)
            print_error "Opção inválida"
            exit 1
            ;;
    esac
fi

# ============================================================================
# CONFIRMAÇÕES DE SEGURANÇA
# ============================================================================

if [ "$REMOVE_VOLUMES" = true ]; then
    echo ""
    print_warning "Esta ação removerá os volumes Docker!"
    echo ""
    print_info "Volumes que serão removidos:"
    echo -e "  ${RED}•${NC} Banco de dados"
    echo -e "  ${RED}•${NC} Redis"
    echo -e "  ${RED}•${NC} Configurações do Superset"
    echo ""

    if [ "$CLEAN_ALL" = true ]; then
        print_warning "Limpeza completa: diretórios locais também serão removidos!"
        echo ""
    fi

    if ! ask_confirmation "(s/n) Deseja continuar?"; then
        print_info "Operação cancelada pelo usuário"
        exit 0
    fi
fi

echo ""

# ============================================================================
# OPERAÇÕES DE PARADA
# ============================================================================

if [ "$REMOVE_VOLUMES" = true ]; then
    print_action "Parando Superset e removendo volumes..."
    $DOCKER_CMD down -v

    # Como usamos bind mounts, o down -v não remove os arquivos.
    # Precisamos remover manualmente para garantir que o banco seja resetado.
    echo ""
    print_action "Removendo arquivos dos volumes locais..."
    if [ -d "${VOLUMES_DIR}" ]; then
        sudo rm -rf "${VOLUMES_DIR}"
        print_success "Volumes locais removidos"
    fi

    if [ "$CLEAN_ALL" = true ]; then
        # A limpeza já foi feita acima, mas mantemos o bloco para lógica futura se necessário
        :
    fi
else
    print_action "Parando Superset (preservando dados)..."
    $DOCKER_CMD down
fi

# ============================================================================
# MENSAGENS FINAIS
# ============================================================================

echo ""
print_success "Superset parado com sucesso!"
echo ""

if [ "$REMOVE_VOLUMES" = false ]; then
    print_info "Os dados foram preservados nos volumes"
    echo ""
    print_info "Próximas ações:"
    echo -e "  ${MAGENTA}•${NC} Para remover volumes: ./down.sh -v"
    echo -e "  ${MAGENTA}•${NC} Para limpeza completa: ./down.sh -c"
    echo -e "  ${MAGENTA}•${NC} Para menu interativo: ./down.sh (sem argumentos)"
fi

echo ""
