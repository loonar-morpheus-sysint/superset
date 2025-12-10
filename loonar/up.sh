#!/usr/bin/bash
#
# Script interativo para implantar o docker-compose-loonar.yml
# - Lista contextos Docker disponíveis e permite selecionar o alvo
# - Mantém o contexto escolhido como padrão
# - Funciona com contextos locais ou remotos
# - Cria ou reutiliza redes apenas quando o compose não define nenhuma

clear

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose-loonar.yml"
ENV_FILE="$SCRIPT_DIR/.env"
LDAP_MOCK_ENV_FILE="$SCRIPT_DIR/ldap-mock/.env"

if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker não está instalado ou não está no PATH"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Arquivo .env não encontrado em $SCRIPT_DIR/."
    echo "   Gere-o com ./rotate-keys.sh antes de continuar."
    exit 1
fi

select_context() {
    local current
    current=$(docker context show 2>/dev/null || echo "default")
    echo "🌐 Contexto Docker atual: $current"
    echo ""

    mapfile -t contexts < <(docker context ls --format '{{.Name}}\t{{if .Current}}*{{end}}\t{{.DockerEndpoint}}')
    if [ ${#contexts[@]} -eq 0 ]; then
        echo "❌ Nenhum contexto Docker configurado."
        exit 1
    fi

    echo "📋 Contextos disponíveis:"
    local idx=1
    for entry in "${contexts[@]}"; do
        IFS=$'\t' read -r name marker endpoint <<<"$entry"
        local label="$idx) $name"
        [ "$marker" = "*" ] && label+=" (atual)"
        echo "   $label — $endpoint"
        idx=$((idx + 1))
    done
    echo ""

    read -r -p "Selecione o contexto desejado (Enter para manter $current): " selection
    local target="$current"
    if [ -n "$selection" ]; then
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#contexts[@]} ]; then
            IFS=$'\t' read -r target _ <<<"${contexts[$((selection-1))]}"
        else
            # Permitir seleção por nome direto
            for entry in "${contexts[@]}"; do
                IFS=$'\t' read -r name marker endpoint <<<"$entry"
                if [ "$name" = "$selection" ]; then
                    target="$name"
                    break
                fi
            done
        fi
    fi

    if ! docker context inspect "$target" >/dev/null 2>&1; then
        echo "❌ Contexto '$target' não encontrado"
        exit 1
    fi

    if [ "$target" != "$current" ]; then
        echo "🔄 Alterando contexto Docker padrão para: $target"
        docker context use "$target" >/dev/null
    else
        echo "ℹ️  Mantendo contexto atual: $current"
    fi
}

get_value_from_file() {
    local file="$1"
    local key="$2"
    local default_value="${3:-}"
    if [ ! -f "$file" ]; then
        echo "$default_value"
        return
    fi
    local value
    value=$(grep -E "^${key}=" "$file" | tail -n 1 | cut -d '=' -f2- || true)
    value=${value%%$'\r'}
    if [ -z "$value" ]; then
        value="$default_value"
    fi
    echo "$value"
}

get_env_value() {
    local key="$1"
    local default_value="${2:-}"
    get_value_from_file "$ENV_FILE" "$key" "$default_value"
}

set_env_value() {
    local key="$1"
    local value="$2"
    local tmp
    tmp=$(mktemp)
    awk -v key="$key" -v value="$value" '
        BEGIN { found = 0 }
        $0 ~ "^" key "=" {
            print key "=" value
            found = 1
            next
        }
        { print }
        END {
            if (!found) {
                print key "=" value
            }
        }
    ' "$ENV_FILE" > "$tmp"
    mv "$tmp" "$ENV_FILE"
}

select_build_mode() {
    echo "🔨 Modo de build:"
    echo "   1) Rebuild da imagem Dockerfile-loonar (recomendado após mudanças de código)"
    echo "   2) Usar imagem atual (deploy rápido, sem rebuild)"
    read -r -p "Escolha o modo desejado (Enter para usar imagem atual): " option || true

    case "$option" in
        1|rebuild|REBUILD)
            BUILD_MODE="rebuild"
            echo "✅ Será feito rebuild do Dockerfile-loonar"
            ;;
        *)
            BUILD_MODE="current"
            echo "✅ Será usada a imagem atual"
            ;;
    esac
}

select_ldap_mode() {
    local current_mode
    current_mode=$(get_env_value "LOONAR_LDAP_MODE" "real")

    echo "🔐 Modo LDAP atual: $current_mode"
    echo "   1) Active Directory real (produção)"
    echo "   2) Servidor mock (docker-compose-ldap-mock)"
    read -r -p "Escolha o modo desejado (Enter mantém $current_mode): " option || true

    local new_mode="$current_mode"
    case "$option" in
        1|real|REAL)
            new_mode="real"
            ;;
        2|mock|MOCK)
            new_mode="mock"
            ;;
    esac

    if [ "$new_mode" != "$current_mode" ]; then
        set_env_value "LOONAR_LDAP_MODE" "$new_mode"
        echo "✅ LOONAR_LDAP_MODE atualizado para '$new_mode' em $ENV_FILE"
    else
        echo "ℹ️  Mantendo o modo '$current_mode'"
    fi

    export LOONAR_LDAP_MODE="$new_mode"
    if [ "$new_mode" = "mock" ]; then
        sync_mock_server_uri
    fi

    local upper_mode
    upper_mode=$(echo "$new_mode" | tr '[:lower:]' '[:upper:]')
    local server_key="LOONAR_LDAP_SERVER_${upper_mode}"
    local server_value
    server_value=$(get_env_value "$server_key" "")
    if [ -n "$server_value" ]; then
        echo "🔗 Superset irá apontar para: $server_value"
    fi
}

select_init_mode() {
    local init_marker="$PROJECT_ROOT/.superset_initialized"
    local already_initialized=false

    if [ -f "$init_marker" ]; then
        already_initialized=true
    fi

    echo "🔧 Modo de inicialização do banco de dados:"
    if [ "$already_initialized" = true ]; then
        echo "   ℹ️  Superset já foi inicializado anteriormente"
        echo "   1) Pular inicialização (usar banco existente)"
        echo "   2) Forçar reinicialização (executar superset db upgrade e criar admin)"
    else
        echo "   ℹ️  Primeira execução detectada"
        echo "   1) Executar inicialização (recomendado)"
        echo "   2) Pular inicialização (avançado - assumir que banco já está pronto)"
    fi

    read -r -p "Escolha o modo desejado (Enter para opção 1): " option || true

    export INIT_MODE="skip"
    case "$option" in
        2)
            if [ "$already_initialized" = true ]; then
                export INIT_MODE="force"
                echo "✅ Será executada a reinicialização do banco"
            else
                export INIT_MODE="skip"
                echo "⚠️  Pulando inicialização - certifique-se que o banco está pronto"
            fi
            ;;
        *)
            if [ "$already_initialized" = true ]; then
                export INIT_MODE="skip"
                echo "✅ Inicialização será pulada (banco já existe)"
            else
                export INIT_MODE="run"
                echo "✅ Será executada a inicialização do banco"
            fi
            ;;
    esac
}

sync_mock_server_uri() {
    local superset_host
    superset_host=$(get_env_value "SUPERSET_HOST" "localhost")
    if [ -z "$superset_host" ]; then
        superset_host="localhost"
    fi

    local mock_port
    mock_port=$(get_value_from_file "$LDAP_MOCK_ENV_FILE" "LDAP_MOCK_PORT" "3389")
    if [ -z "$mock_port" ]; then
        mock_port="3389"
    fi

    local uri="ldap://${superset_host}:${mock_port}"
    local current_uri
    current_uri=$(get_env_value "LOONAR_LDAP_SERVER_MOCK" "")

    if [ "$current_uri" != "$uri" ]; then
        set_env_value "LOONAR_LDAP_SERVER_MOCK" "$uri"
        echo "🔗 LOONAR_LDAP_SERVER_MOCK atualizado para $uri (com base em SUPERSET_HOST)"
    else
        echo "ℹ️  LOONAR_LDAP_SERVER_MOCK já está configurado como $uri"
    fi
}

check_superset_initialization() {
    # Marcar arquivo de inicialização
    local init_marker="$PROJECT_ROOT/.superset_initialized"

    # Verificar se deve executar inicialização baseado na escolha do usuário
    if [ "$INIT_MODE" = "skip" ]; then
        echo "⏭️  Pulando inicialização do banco de dados"
        return 0
    fi

    if [ "$INIT_MODE" = "force" ]; then
        echo "🔧 Forçando reinicialização do Superset..."
        rm -f "$init_marker"
    elif [ "$INIT_MODE" = "run" ]; then
        echo "🔧 Primeira execução detectada - inicializando Superset..."
    fi

    # Inicializar com profile 'init'
    echo "🔄 Executando superset_init com profile init..."
    docker compose "${COMPOSE_ARGS[@]}" --profile init up -d superset_init

    # Capturar o container criado para conseguir ler o exit code depois
    init_container_id=$(docker compose "${COMPOSE_ARGS[@]}" ps -q superset_init | head -n1)
    if [ -z "$init_container_id" ]; then
        echo "❌ Não foi possível identificar o container superset_init"
        exit 1
    fi

    # Aguardar conclusão
    echo "⏳ Aguardando inicialização do banco de dados..."
    docker logs -f "$init_container_id"

    # Verificar exit code real via docker wait no container capturado
    exit_code=$(docker wait "$init_container_id" || true)
    if [ "$exit_code" = "0" ]; then
        echo "✅ Superset inicializado com sucesso!"

        # Remover container de inicialização
        echo "🧹 Removendo container superset_init..."
        docker compose "${COMPOSE_ARGS[@]}" rm -f superset_init

        # Marcar como inicializado
        touch "$init_marker"
    else
        echo "❌ Erro na inicialização do Superset (exit code $exit_code)"
        exit 1
    fi
}

# Retorna 0 se houver bloco de redes na raiz do compose
compose_has_networks() {
    grep -Eq '^networks:' "$COMPOSE_FILE"
}

choose_network_override() {
    local override_file network_choice
    echo "🌐 Este compose não define redes. Selecione uma rede existente ou crie uma nova."
    mapfile -t networks < <(docker network ls --format '{{.Name}}\t{{.Driver}}')
    local idx=1
    for entry in "${networks[@]}"; do
        IFS=$'\t' read -r name driver <<<"$entry"
        echo "   $idx) $name ($driver)"
        idx=$((idx + 1))
    done
    echo "   n) Criar nova rede"

    while true; do
        read -r -p "Escolha uma opção: " option
        if [[ "$option" =~ ^[0-9]+$ ]] && [ "$option" -ge 1 ] && [ "$option" -le ${#networks[@]} ]; then
            IFS=$'\t' read -r network_choice _ <<<"${networks[$((option-1))]}"
            break
        elif [[ "$option" =~ ^[nN]$ ]]; then
            read -r -p "Nome da nova rede: " network_choice
            if [ -z "$network_choice" ]; then
                echo "⚠️  Nome inválido"
                continue
            fi
            docker network create "$network_choice" >/dev/null
            echo "✅ Rede '$network_choice' criada."
            break
        else
            echo "⚠️  Opção inválida."
        fi
    done

    override_file=$(mktemp)
    cat <<EOF > "$override_file"
services: {}
networks:
  default:
    external: true
    name: ${network_choice}
EOF
    echo "$override_file"
}

echo "🚀 Implantando Superset Loonar"
select_context
select_build_mode
select_ldap_mode
select_init_mode

COMPOSE_ARGS=(--env-file "$ENV_FILE" -f "$COMPOSE_FILE" --profile init)
TEMP_FILE=""

# Rebuild images upfront when requested to ensure init uses fresh code
if [ "$BUILD_MODE" = "rebuild" ]; then
    echo "🔨 Rebuilding Docker images..."
    docker compose "${COMPOSE_ARGS[@]}" --profile init build
fi

# Inicializar estrutura do banco de dados se necessário (apenas na primeira vez)
check_superset_initialization

if ! compose_has_networks; then
    TEMP_FILE=$(choose_network_override)
    COMPOSE_ARGS+=(-f "$TEMP_FILE")
fi

cleanup() {
    if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
        rm -f "$TEMP_FILE"
    fi
}
trap cleanup EXIT

echo "🧪 Validando configuração..."
docker compose "${COMPOSE_ARGS[@]}" config >/dev/null

echo "📦 Construindo e iniciando serviços..."
BUILD_FLAG=""
if [ "$BUILD_MODE" = "rebuild" ]; then
    BUILD_FLAG="--build"
    echo "🔨 Rebuilding Dockerfile-loonar..."
fi
docker compose "${COMPOSE_ARGS[@]}" up -d $BUILD_FLAG --remove-orphans

echo ""
echo "📊 Status dos containers:"
docker compose "${COMPOSE_ARGS[@]}" ps

HOST_URL=$(grep "^SUPERSET_HOST=" "$ENV_FILE" | cut -d '=' -f2)
[ -z "$HOST_URL" ] && HOST_URL="localhost"

cat <<EOF

✅ Deploy concluído!
   - Contexto ativo: $(docker context show)
   - Acesse: http://$HOST_URL
   - Logs: docker compose ${COMPOSE_ARGS[*]} logs -f

EOF
