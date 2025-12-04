#!/usr/bin/bash
#
# Script principal de deploy do Superset Loonar
# Permite escolher entre instalação local ou remota
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ============================================================================
# CORES E ESTILOS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

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

# Função para detectar contexto Docker atual
detect_docker_context() {
    docker context show 2>/dev/null || echo "default"
}

# Função para listar contextos Docker disponíveis
list_docker_contexts() {
    docker context ls --format "table {{.Name}}\t{{.Description}}\t{{.DockerEndpoint}}" 2>/dev/null
}

# Função para validar conexão SSH
test_ssh_connection() {
    local ssh_host="$1"
    print_action "Testando conexão SSH com $ssh_host..."

    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$ssh_host" "echo 'OK'" &>/dev/null; then
        print_success "Conexão SSH OK"
        return 0
    else
        print_error "Falha ao conectar via SSH"
        return 1
    fi
}

# Função para validar arquivo .env
validate_env_file() {
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        print_error "Arquivo .env não encontrado em $SCRIPT_DIR/"
        echo ""
        print_info "Execute './rotate-keys.sh' para gerar um arquivo .env com segredos"
        return 1
    fi

    # Validar variáveis obrigatórias
    set -a
    source "$SCRIPT_DIR/.env"
    set +a

    local required_vars=("SUPERSET_SECRET_KEY" "POSTGRES_PASSWORD" "REDIS_PASSWORD" "SUPERSET_HOST")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Variáveis obrigatórias ausentes no .env:"
        printf '   - %s\n' "${missing_vars[@]}"
        echo ""
        print_info "Execute './rotate-keys.sh' para gerar valores"
        return 1
    fi

    return 0
}

# ============================================================================
# MENU PRINCIPAL
# ============================================================================

clear
print_header "🚀 Deploy do Superset Loonar"
echo ""

# Validar .env antes de prosseguir
if ! validate_env_file; then
    exit 1
fi

print_success "Arquivo .env validado"
echo ""

# Exibir menu de opções
echo -e "${CYAN}┌─ Selecione o modo de instalação:${NC}"
echo -e "${BLUE}│${NC}"
echo -e "${BLUE}│${NC} ${MAGENTA}1${NC} - Instalação LOCAL"
echo -e "${BLUE}│${NC}   ${BLUE}Deploy na máquina atual${NC}"
echo -e "${BLUE}│${NC}"
echo -e "${BLUE}│${NC} ${MAGENTA}2${NC} - Instalação REMOTA via Docker Context"
echo -e "${BLUE}│${NC}   ${BLUE}Usa contexto Docker remoto (requer contexto configurado)${NC}"
echo -e "${BLUE}│${NC}"
echo -e "${BLUE}│${NC} ${MAGENTA}3${NC} - Instalação REMOTA via SSH"
echo -e "${BLUE}│${NC}   ${BLUE}Copia arquivos e executa setup no servidor remoto${NC}"
echo -e "${BLUE}│${NC}"
echo -e "${BLUE}│${NC} ${MAGENTA}0${NC} - Cancelar"
echo -e "${BLUE}│${NC}"
echo -e "${CYAN}└─${NC}"
echo ""

read -p "Escolha uma opção [0-3]: " DEPLOY_MODE

case $DEPLOY_MODE in
    1)
        # ====================================================================
        # MODO 1: INSTALAÇÃO LOCAL
        # ====================================================================
        clear
        print_header "📍 Instalação LOCAL"
        echo ""

        print_info "Configuração:"
        echo -e "  ${CYAN}Modo:${NC} Local"
        echo -e "  ${CYAN}Diretório:${NC} $SCRIPT_DIR"
        echo ""

        read -p "Confirma a instalação? [s/N]: " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
            print_warning "Deploy cancelado"
            exit 0
        fi

        echo ""
        print_action "Executando setup local..."
        exec "$SCRIPT_DIR/setup-local.sh"
        ;;

    2)
        # ====================================================================
        # MODO 2: INSTALAÇÃO REMOTA VIA DOCKER CONTEXT
        # ====================================================================
        clear
        print_header "🌐 Instalação REMOTA via Docker Context"
        echo ""

        # Listar contextos disponíveis
        print_info "Contextos Docker disponíveis:"
        echo ""
        list_docker_contexts
        echo ""

        CURRENT_CONTEXT=$(detect_docker_context)
        echo -e "${BLUE}Contexto atual: ${CYAN}$CURRENT_CONTEXT${NC}"
        echo ""

        read -p "Digite o nome do contexto Docker remoto (ou Enter para atual): " DOCKER_CONTEXT

        if [ -z "$DOCKER_CONTEXT" ]; then
            DOCKER_CONTEXT="$CURRENT_CONTEXT"
        fi

        # Verificar se contexto existe
        if ! docker context inspect "$DOCKER_CONTEXT" &>/dev/null; then
            print_error "Contexto '$DOCKER_CONTEXT' não encontrado"
            exit 1
        fi

        print_success "Contexto validado: $DOCKER_CONTEXT"
        echo ""

        # Solicitar diretório remoto
        read -p "Digite o diretório no servidor remoto (ex: /opt/superset): " REMOTE_DIR

        if [ -z "$REMOTE_DIR" ]; then
            REMOTE_DIR="/opt/superset"
            print_warning "Usando diretório padrão: $REMOTE_DIR"
        fi

        # Verificar se diretório existe no servidor remoto
        echo ""
        print_action "Verificando diretório no servidor remoto..."

        DIR_EXISTS=$(docker run --rm -v "$REMOTE_DIR:/check" alpine:latest test -d /check && echo "yes" || echo "no")

        if [ "$DIR_EXISTS" = "no" ]; then
            print_warning "Diretório $REMOTE_DIR não existe no servidor remoto"
            echo ""
            read -p "Deseja criar o diretório? [S/n]: " CREATE_DIR

            if [[ "$CREATE_DIR" =~ ^[nN]$ ]]; then
                print_error "Deploy cancelado - diretório não existe"
                exit 1
            fi

            print_action "Diretório será criado durante o setup"
        else
            print_success "Diretório existe no servidor remoto"
        fi

        echo ""
        print_info "Configuração:"
        echo -e "  ${CYAN}Modo:${NC} Remoto via Docker Context"
        echo -e "  ${CYAN}Contexto:${NC} $DOCKER_CONTEXT"
        echo -e "  ${CYAN}Diretório remoto:${NC} $REMOTE_DIR"
        echo ""

        read -p "Confirma a instalação? [s/N]: " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
            print_warning "Deploy cancelado"
            exit 0
        fi

        echo ""
        print_action "Executando setup remoto via Docker Context..."
        exec "$SCRIPT_DIR/setup-remote-context.sh" "$DOCKER_CONTEXT" "$REMOTE_DIR"
        ;;

    3)
        # ====================================================================
        # MODO 3: INSTALAÇÃO REMOTA VIA SSH
        # ====================================================================
        clear
        print_header "🔐 Instalação REMOTA via SSH"
        echo ""

        read -p "Digite o host SSH (ex: user@servidor.com): " SSH_HOST

        if [ -z "$SSH_HOST" ]; then
            print_error "Host SSH é obrigatório"
            exit 1
        fi

        # Testar conexão SSH
        if ! test_ssh_connection "$SSH_HOST"; then
            exit 1
        fi

        echo ""
        read -p "Digite o diretório no servidor remoto (ex: /opt/superset): " REMOTE_DIR

        if [ -z "$REMOTE_DIR" ]; then
            REMOTE_DIR="/opt/superset"
            print_warning "Usando diretório padrão: $REMOTE_DIR"
        fi

        # Verificar se diretório existe no servidor remoto via SSH
        echo ""
        print_action "Verificando diretório no servidor remoto..."

        if ssh "$SSH_HOST" "test -d $REMOTE_DIR" 2>/dev/null; then
            print_success "Diretório existe no servidor remoto"
            echo ""
            read -p "Diretório já existe. Deseja continuar e sobrescrever? [s/N]: " OVERWRITE

            if [[ ! "$OVERWRITE" =~ ^[sS]$ ]]; then
                print_error "Deploy cancelado pelo usuário"
                exit 1
            fi
        else
            print_warning "Diretório $REMOTE_DIR não existe no servidor remoto"
            echo ""
            read -p "Deseja criar o diretório? [S/n]: " CREATE_DIR

            if [[ "$CREATE_DIR" =~ ^[nN]$ ]]; then
                print_error "Deploy cancelado - diretório não existe"
                exit 1
            fi

            print_action "Diretório será criado durante o setup"
        fi

        echo ""
        print_info "Configuração:"
        echo -e "  ${CYAN}Modo:${NC} Remoto via SSH"
        echo -e "  ${CYAN}SSH Host:${NC} $SSH_HOST"
        echo -e "  ${CYAN}Diretório remoto:${NC} $REMOTE_DIR"
        echo ""

        read -p "Confirma a instalação? [s/N]: " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
            print_warning "Deploy cancelado"
            exit 0
        fi

        echo ""
        print_action "Executando setup remoto via SSH..."
        exec "$SCRIPT_DIR/setup-remote-ssh.sh" "$SSH_HOST" "$REMOTE_DIR"
        ;;

    0)
        print_info "Deploy cancelado"
        exit 0
        ;;

    *)
        print_error "Opção inválida"
        exit 1
        ;;
esac
