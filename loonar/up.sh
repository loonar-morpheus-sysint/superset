#!/usr/bin/bash
#
# Script interativo para implantar o docker-compose-loonar.yml
# - Lista contextos Docker disponíveis e permite selecionar o alvo
# - Mantém o contexto escolhido como padrão
# - Funciona com contextos locais ou remotos
# - Cria ou reutiliza redes apenas quando o compose não define nenhuma

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose-loonar.yml"
ENV_FILE="$SCRIPT_DIR/.env"

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

COMPOSE_ARGS=(--env-file "$ENV_FILE" -f "$COMPOSE_FILE")
TEMP_FILE=""
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
docker compose "${COMPOSE_ARGS[@]}" up -d --build --remove-orphans

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
