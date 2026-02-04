#!/usr/bin/env bash
#
# Script para subir o servidor LDAP fake (OpenLDAP) usado em testes locais/remotos.
# - Permite escolher o contexto Docker (local ou remoto)
# - Garante que a rede compartilhada exista
# - Usa docker-compose-ldap-mock.yml para criar o serviço mock_ad

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose-ldap-mock.yml"
ENV_FILE="$SCRIPT_DIR/ldap-mock/.env"
SUPERSET_ENV_FILE="$SCRIPT_DIR/.env"
BOOTSTRAP_HOST_FILE="$SCRIPT_DIR/ldap-mock/bootstrap/50-loonar-structure.ldif"
SAM_SCHEMA_HOST_FILE="$SCRIPT_DIR/ldap-mock/schema/50-superset-samaccount.ldif"
# ⚠️ Use um project name dedicado para este compose.
# Isso evita que `docker compose up` trate containers de outros stacks (ex.: Superset) como "orphans".
LDAP_MOCK_PROJECT_NAME="${LDAP_MOCK_PROJECT_NAME:-loonar_ldap_mock}"
COMPOSE_PROJECT_NAME_VALUE="$LDAP_MOCK_PROJECT_NAME"

if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker não está instalado ou no PATH"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "❌ Docker Compose (plugin: 'docker compose') não está disponível."
    echo "   Instale/ative o plugin Docker Compose v2 e tente novamente."
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Arquivo de compose não encontrado: $COMPOSE_FILE"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Arquivo $ENV_FILE não encontrado."
    echo "   Copie ldap-mock/.env-sample para ldap-mock/.env e tente novamente."
    exit 1
fi

if [ ! -f "$BOOTSTRAP_HOST_FILE" ]; then
    echo "❌ Arquivo LDIF de bootstrap não encontrado: $BOOTSTRAP_HOST_FILE"
    exit 1
fi

if [ ! -f "$SAM_SCHEMA_HOST_FILE" ]; then
    echo "❌ Arquivo LDIF de schema (sAMAccountName) não encontrado: $SAM_SCHEMA_HOST_FILE"
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

    read -r -p "Selecione o contexto desejado (Enter para manter $current): " selection || true
    local target="$current"
    if [ -n "$selection" ]; then
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#contexts[@]} ]; then
            IFS=$'\t' read -r target _ <<<"${contexts[$((selection-1))]}"
        else
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
        echo "🔄 Alterando contexto Docker para: $target"
        docker context use "$target" >/dev/null
    else
        echo "ℹ️  Mantendo contexto atual: $current"
    fi

    # Valida conectividade com o daemon do Docker no contexto escolhido.
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Não foi possível conectar ao Docker daemon no contexto '$target'."
        echo "   Verifique se o host remoto está acessível, credenciais TLS e permissões." 
        exit 1
    fi
}

get_value_from_file() {
    local file="$1"
    local key="$2"
    local default_value="$3"
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
    local default="$2"
    get_value_from_file "$ENV_FILE" "$key" "$default"
}

cleanup_previous_deployment() {
    # Remove implantações anteriores do LDAP mock sem afetar o Superset.
    # 1) derruba recursos do compose do projeto atual
    # 2) remove container com nome fixo (caso tenha sido criado por outro project name)
    # 3) remove volumes conhecidos do mock (do project atual e legado "superset")

    echo "🧹 Removendo implantações anteriores do LDAP mock (se existirem)..."

    # Derruba o compose do project atual (seguro por usar -p dedicado).
    docker compose "${COMPOSE_ARGS[@]}" down -v --remove-orphans >/dev/null 2>&1 || true

    # O docker-compose-ldap-mock.yml define container_name fixo; se ele existir, removemos.
    if docker ps -a --format '{{.Names}}' | grep -qx 'loonar_mock_ad'; then
        docker rm -f loonar_mock_ad >/dev/null 2>&1 || true
    fi

    # Remove volumes do mock (podem ter sido criados com project name antigo, ex.: "superset").
    local volumes_to_remove=()
    volumes_to_remove+=("${LDAP_MOCK_PROJECT_NAME}_ldap_mock_db" "${LDAP_MOCK_PROJECT_NAME}_ldap_mock_config")
    volumes_to_remove+=("superset_ldap_mock_db" "superset_ldap_mock_config")
    local vol
    for vol in "${volumes_to_remove[@]}"; do
        if docker volume inspect "$vol" >/dev/null 2>&1; then
            docker volume rm "$vol" >/dev/null 2>&1 || true
        fi
    done
}

ensure_service_account_password() {
    local admin_dn="$1"
    local admin_password="$2"
    local service_dn="$3"
    local service_password="$4"

    # Mantém o diretório consistente com a senha configurada no .env do Superset.
    # Isso evita "Invalid credentials" (err=49) se o LDIF tiver uma senha diferente.
    if [ -z "$service_dn" ]; then
        echo "❌ SERVICE_DN vazio; não é possível ajustar senha da conta de serviço."
        exit 1
    fi

    echo "🔑 Ajustando senha da conta de serviço no LDAP para bater com o .env..."
    if ! docker compose "${COMPOSE_ARGS[@]}" exec -T mock_ad \
        ldappasswd -H ldap://localhost:389 -x -D "$admin_dn" -w "$admin_password" \
        -s "$service_password" "$service_dn" >/dev/null 2>&1; then
        echo "❌ Falha ao ajustar senha da conta de serviço ($service_dn)."
        docker compose "${COMPOSE_ARGS[@]}" logs --tail=200 mock_ad || true
        exit 1
    fi
}

ensure_network() {
    local network_name
    network_name=$(get_env_value "LDAP_MOCK_NETWORK" "superset")
    if docker network inspect "$network_name" >/dev/null 2>&1; then
        local compose_label
        compose_label=$(docker network inspect -f '{{ index .Labels "com.docker.compose.network" }}' "$network_name" 2>/dev/null || echo "")
        if [ "$compose_label" = "$network_name" ]; then
            echo "🔗 Rede '$network_name' já existe com labels compatíveis."
            return
        fi

        # ⚠️ Importante: esta rede pode estar sendo usada por outros stacks (ex.: Superset).
        # Para garantir que este script só afete o compose do LDAP mock, NÃO fazemos ações destrutivas
        # (desconectar containers / remover / recriar rede). Apenas reutilizamos a rede existente.
        echo "⚠️ Rede '$network_name' já existe, mas sem labels esperados."
        echo "   Mantendo a rede como está para não afetar outros containers."
        return
    fi

    echo "➕ Criando rede Docker '$network_name' (bridge) com labels compatíveis."
    if ! docker network create \
        --driver bridge \
        --label "com.docker.compose.project=$COMPOSE_PROJECT_NAME_VALUE" \
        --label "com.docker.compose.network=$network_name" \
        "$network_name" >/dev/null; then
        echo "❌ Falha ao criar a rede Docker '$network_name'."
        echo "   Verifique permissões do Docker e se já existe uma rede com o mesmo nome." 
        exit 1
    fi
}

get_current_suffix() {
    local max_attempts=${1:-12}
    local attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
        local suffix
        suffix=$(docker compose "${COMPOSE_ARGS[@]}" exec -T mock_ad \
            ldapsearch -LLL -Y EXTERNAL -H ldapi:/// \
            -b "olcDatabase={1}mdb,cn=config" olcSuffix 2>/dev/null | awk '/^olcSuffix:/{print $2}' | head -n 1)

        if [ -n "$suffix" ]; then
            echo "$suffix"
            return 0
        fi

        attempt=$((attempt + 1))
        echo "⏳ Aguardando leitura do sufixo atual (tentativa $attempt/$max_attempts)..." >&2
        sleep 5
    done

    return 1
}

ensure_suffix_matches_base() {
    local current_suffix
    current_suffix=$(get_current_suffix 12 || true)

    if [ -z "$current_suffix" ]; then
        echo "❌ Não foi possível ler o sufixo atual (olcSuffix). Verifique os logs do container mock_ad."
        docker compose "${COMPOSE_ARGS[@]}" logs --tail=200 mock_ad || true
        exit 1
    fi

    local normalized_current normalized_expected
    normalized_current=$(echo "$current_suffix" | tr '[:upper:]' '[:lower:]')
    normalized_expected=$(echo "$BASE_DN" | tr '[:upper:]' '[:lower:]')

    if [ "$normalized_current" = "$normalized_expected" ]; then
        echo "✅ Sufixo do diretório persistido coincide com BASE_DN ($BASE_DN)."
        return
    fi

    echo "⚠️ Sufixo atual do diretório é '$current_suffix', mas o esperado é '$BASE_DN'. Recriando volume para alinhar..."
    docker compose "${COMPOSE_ARGS[@]}" down -v
    docker compose "${COMPOSE_ARGS[@]}" up -d --build

    current_suffix=$(get_current_suffix 12 || true)
    normalized_current=$(echo "$current_suffix" | tr '[:upper:]' '[:lower:]')

    if [ "$normalized_current" != "$normalized_expected" ]; then
        echo "❌ Mesmo após recriar o volume, o sufixo permanece '$current_suffix' e difere de '$BASE_DN'. Abortando para evitar inconsistências."
        exit 1
    fi

    echo "✅ Sufixo ajustado para $BASE_DN após recriação do volume."
}

wait_for_bind() {
    local dn="$1"
    local password="$2"
    local description="$3"
    local search_base="${4:-$BASE_DN}"
    local max_attempts=${5:-12}
    local attempt=1

    while true; do
        if docker compose "${COMPOSE_ARGS[@]}" exec -T mock_ad \
            ldapsearch -H ldap://localhost:389 \
            -D "$dn" -w "$password" \
            -b "$search_base" -s base '(objectClass=*)' >/dev/null 2>&1; then
            echo "✅ Bind LDAP para $description concluído (tentativa $attempt)."
            break
        fi

        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "❌ Falha ao conectar com $description após $max_attempts tentativas. Veja os logs abaixo:"
            docker compose "${COMPOSE_ARGS[@]}" logs --tail=200 mock_ad
            exit 1
        fi

        attempt=$((attempt + 1))
        echo "⏳ LDAP ainda inicializando para $description (tentativa $attempt/$max_attempts). Aguardando 5s..."
        sleep 5
    done
}

reset_mock_directory() {
    local admin_dn="$1"
    local admin_password="$2"
    local bootstrap_ldif_host="$3"
    local bootstrap_ldif_container="/tmp/50-loonar-structure.ldif"
    local bootstrap_rendered

    bootstrap_rendered=$(mktemp)

    echo "🧹 Limpando dados anteriores (caso existam)..."
    local dn
    for dn in "ou=03-SERVICOS,$BASE_DN" "ou=04-CLIENTES,$BASE_DN"; do
        if docker compose "${COMPOSE_ARGS[@]}" exec -T mock_ad \
            ldapdelete -H ldap://localhost:389 -x -D "$admin_dn" -w "$admin_password" -r "$dn" >/dev/null 2>&1; then
            echo "   - Removido $dn"
        else
            echo "   - Nenhum dado prévio para $dn (ok)"
        fi
    done

    echo "📥 Reaplicando estrutura LDIF personalizada..."

    sed \
        -e "s/DC=loonardc,DC=local/$BASE_DN/g" \
        -e "s/loonardc.local/$LDAP_DOMAIN/g" \
        "$bootstrap_ldif_host" >"$bootstrap_rendered"

    copy_file_to_container "$bootstrap_rendered" "$bootstrap_ldif_container"
    rm -f "$bootstrap_rendered"

    docker compose "${COMPOSE_ARGS[@]}" exec -T mock_ad \
        ldapadd -H ldap://localhost:389 -x -D "$admin_dn" -w "$admin_password" -f "$bootstrap_ldif_container"
}

ensure_sam_account_schema() {
    local schema_ldif_host="$1"
    local schema_ldif_container="/tmp/50-superset-samaccount.ldif"

    if docker compose "${COMPOSE_ARGS[@]}" exec -T mock_ad bash -lc \
        "ldapsearch -LLL -Y EXTERNAL -H ldapi:/// -b 'cn=schema,cn=config' '(cn=*superset-custom*)' dn | grep -q '^dn:'"; then
        echo "✅ Schema 'sAMAccountName' já está aplicado."
        return
    fi

    echo "➕ Aplicando schema para sAMAccountName..."
    copy_file_to_container "$schema_ldif_host" "$schema_ldif_container"
    docker compose "${COMPOSE_ARGS[@]}" exec -T mock_ad \
        ldapadd -Y EXTERNAL -H ldapi:/// -f "$schema_ldif_container"
}

ensure_service_account_acl() {
    local admin_dn="$1"
    local readonly_dn="$2"
    local service_dn="$3"
    local readonly_enabled="${4:-true}"
    local normalized_readonly
    normalized_readonly=$(echo "$readonly_enabled" | tr '[:upper:]' '[:lower:]')
    local readonly_clause=""
    if [[ "$normalized_readonly" == "true" && -n "$readonly_dn" ]]; then
        readonly_clause=" by dn=\"$readonly_dn\" read"
    fi

    local acl_ldif="/tmp/60-service-account-acl.ldif"
    docker compose "${COMPOSE_ARGS[@]}" exec -T mock_ad sh -c "cat > '$acl_ldif'" <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break
olcAccess: {1}to attrs=userPassword,shadowLastChange by self write by dn="$admin_dn" write by anonymous auth by * none
olcAccess: {2}to * by self read by dn="$admin_dn" write${readonly_clause} by dn="$service_dn" read by * none
EOF

    docker compose "${COMPOSE_ARGS[@]}" exec -T mock_ad \
        ldapmodify -Y EXTERNAL -H ldapi:/// -f "$acl_ldif" >/dev/null

    echo "🔐 ACL do LDAP atualizada para permitir leitura pela conta de serviço."
}

copy_file_to_container() {
    local host_path="$1"
    local container_path="$2"

    if [ ! -f "$host_path" ]; then
        echo "❌ Arquivo '$host_path' não encontrado."
        exit 1
    fi

    docker compose "${COMPOSE_ARGS[@]}" exec -T mock_ad sh -c "cat > '$container_path'" <"$host_path"
}

prompt_restart_superset() {
    local compose_file="$PROJECT_ROOT/docker-compose-loonar.yml"
    local services=(superset_app superset_worker superset_worker_beat)

    if [ ! -f "$compose_file" ]; then
        echo "⚠️ Arquivo $compose_file não encontrado; pulando reinício do Superset."
        return
    fi

    if [ ! -f "$SUPERSET_ENV_FILE" ]; then
        echo "⚠️ Arquivo de ambiente $SUPERSET_ENV_FILE não encontrado; pulando reinício do Superset."
        return
    fi

    echo ""
    read -r -p "Deseja reiniciar os serviços do Superset agora? [s/N]: " restart_choice || true
    local normalized_choice
    normalized_choice=$(echo "${restart_choice:-}" | tr '[:upper:]' '[:lower:]')
    if [[ "$normalized_choice" != "s" && "$normalized_choice" != "y" ]]; then
        echo "ℹ️ Superset não será reiniciado."
        return
    fi

    echo "🔄 Reiniciando serviços do Superset (${services[*]})..."
    if docker compose --env-file "$SUPERSET_ENV_FILE" -f "$compose_file" up -d "${services[@]}"; then
        echo "✅ Reinício do Superset concluído."
    else
        echo "⚠️ Falha ao reiniciar serviços do Superset. Verifique o arquivo $compose_file e dependências como 'superset_init'."
    fi
}

select_context
ensure_network

COMPOSE_ARGS=(-p "$LDAP_MOCK_PROJECT_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_FILE")

echo "🧪 Validando configuração do docker compose..."
docker compose "${COMPOSE_ARGS[@]}" config >/dev/null

echo "📦 Subindo mock do Active Directory..."
cleanup_previous_deployment
docker compose "${COMPOSE_ARGS[@]}" up -d --pull always --force-recreate

echo ""
echo "📊 Status do mock AD:"
docker compose "${COMPOSE_ARGS[@]}" ps

BASE_DN=$(get_env_value "LDAP_BASE_DN" "DC=loonardc,DC=local")
LDAP_DOMAIN=$(get_env_value "LDAP_DOMAIN" "loonardc.local")
PORT=$(get_env_value "LDAP_MOCK_PORT" "3389")
DEFAULT_SERVICE_DN="CN=Morpheus Serviços,OU=BR-BH,OU=03-SERVICOS,${BASE_DN}"
SERVICE_DN=$(get_value_from_file "$SUPERSET_ENV_FILE" "LOONAR_LDAP_BIND_DN_MOCK" "$DEFAULT_SERVICE_DN")
SERVICE_PASSWORD=$(get_value_from_file "$SUPERSET_ENV_FILE" "LOONAR_LDAP_BIND_PASSWORD_MOCK" "Morph&us#2020")
ADMIN_PASSWORD=$(get_env_value "LDAP_ADMIN_PASSWORD" "admin")
ADMIN_DN="cn=admin,${BASE_DN}"
BOOTSTRAP_LDIF="$BOOTSTRAP_HOST_FILE"
SAM_SCHEMA_LDIF="$SAM_SCHEMA_HOST_FILE"
READONLY_USER_ENABLED=$(get_env_value "LDAP_READONLY_USER" "true")
READONLY_USER_USERNAME=$(get_env_value "LDAP_READONLY_USER_USERNAME" "readonly")
READONLY_DN=""
if [[ "${READONLY_USER_ENABLED,,}" == "true" && -n "$READONLY_USER_USERNAME" ]]; then
    READONLY_DN="cn=${READONLY_USER_USERNAME},${BASE_DN}"
fi

echo ""
echo "🔎 Validando sufixo persistido do diretório..."
ensure_suffix_matches_base

echo ""
echo "🕒 Aguardando LDAP ficar pronto para operações administrativas..."
wait_for_bind "$ADMIN_DN" "$ADMIN_PASSWORD" "admin"

ensure_sam_account_schema "$SAM_SCHEMA_LDIF"
reset_mock_directory "$ADMIN_DN" "$ADMIN_PASSWORD" "$BOOTSTRAP_LDIF"
ensure_service_account_password "$ADMIN_DN" "$ADMIN_PASSWORD" "$SERVICE_DN" "$SERVICE_PASSWORD"
ensure_service_account_acl "$ADMIN_DN" "$READONLY_DN" "$SERVICE_DN" "$READONLY_USER_ENABLED"

echo ""
echo "🧪 Testando bind LDAP com a conta de serviço..."
wait_for_bind "$SERVICE_DN" "$SERVICE_PASSWORD" "conta de serviço" "$SERVICE_DN"

DEFAULT_HOST="$(hostname -f 2>/dev/null || hostname)"
SUPERSET_HOST_VALUE=$(get_value_from_file "$SUPERSET_ENV_FILE" "SUPERSET_HOST" "$DEFAULT_HOST")
MOCK_HOST=${SUPERSET_HOST_VALUE:-$DEFAULT_HOST}

cat <<EOF

✅ LDAP mock em execução!
   - Host/porta: ldap://$MOCK_HOST:$PORT
   - Base DN: $BASE_DN
   - Conta de serviço: CN=Morpheus Serviços,OU=BR-BH,OU=03-SERVICOS,$BASE_DN
    - Senha da conta de serviço: $SERVICE_PASSWORD
    - Usuário de testes: CN=Joana Superset,OU=04-CLIENTES,$BASE_DN (Senha: #@!123)

Use estes valores no .env do Superset para apontar para o mock quando necessário.
EOF

echo ""
echo "ℹ️  Para evitar impacto no Superset, este script NÃO reinicia containers do Superset."
