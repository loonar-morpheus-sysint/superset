#!/usr/bin/bash
set -euo pipefail

clear

# Configurações padrão
ORIG_SSH_USER="devopsvanilla"
ORIG_SSH_HOST="finops.sondahybrid.com"
IMPORTS_DIR="./imports"
EXPORTS_TMP_DIR="/tmp/superset_exports"
CONTAINER_NAME="superset_app"
SUPERSET_URL="https://finops-hom.sondahybrid.com"
SUPERSET_USERNAME="admin"
SUPERSET_PASSWORD="admin"

# Parse CLI flags
show_help() {
  cat <<EOF
Uso: $0 [opções]
  --user USUARIO           Usuário SSH do servidor de origem
  --host HOST              Host/IP do servidor de origem
  --imports-dir DIR        Diretório local para salvar imports
  --exports-tmp-dir DIR    Diretório temporário remoto para exports
  --container NOME         Nome do container (local e remoto)
  --superset-url URL       URL do Superset local (padrão: https://localhost)
  --superset-user USER     Usuário admin do Superset (padrão: admin)
  --superset-pass PASS     Senha do usuário admin
  --no-prompt              Não perguntar nada (modo não-interativo)
  -h, --help               Exibe esta ajuda
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --user)
      ORIG_SSH_USER="$2"; shift 2;;
    --host)
      ORIG_SSH_HOST="$2"; shift 2;;
    --imports-dir)
      IMPORTS_DIR="$2"; shift 2;;
    --exports-tmp-dir)
      EXPORTS_TMP_DIR="$2"; shift 2;;
    --container)
      CONTAINER_NAME="$2"; shift 2;;
    --superset-url)
      SUPERSET_URL="$2"; shift 2;;
    --superset-user)
      SUPERSET_USERNAME="$2"; shift 2;;
    --superset-pass)
      SUPERSET_PASSWORD="$2"; shift 2;;
    --no-prompt)
      NO_PROMPT=1; shift;;
    -h|--help)
      show_help; exit 0;;
    *)
      echo "Opção desconhecida: $1"; show_help; exit 1;;
  esac
done

# Interface interativa: cores, emojis e prompts
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

NO_PROMPT=${NO_PROMPT:-0}

prompt_edit() {
  local var_name=$1
  local current_val=$2
  local prompt_msg=$3
  local user_input
  if [ "${NO_PROMPT}" = "1" ]; then
    echo -e "${BLUE}⤷ ${prompt_msg}: ${BOLD}${current_val}${RESET} (não interativo)"
    printf -v "$var_name" '%s' "$current_val"
    return
  fi
  read -r -p "${prompt_msg} (padrão: ${current_val}) : " user_input
  if [ -z "${user_input}" ]; then
    printf -v "$var_name" '%s' "$current_val"
  else
    printf -v "$var_name" '%s' "$user_input"
  fi
}

confirm() {
  local msg=$1
  if [ "${NO_PROMPT}" = "1" ]; then
    echo -e "${YELLOW}⚠️  ${msg} - assumindo 'sim' (não interativo)${RESET}"
    return 0
  fi
  local ans
  read -r -p "${msg} [Y/n]: " ans
  ans=${ans:-Y}
  case "${ans}" in
    [Yy]* ) return 0 ;;
    * ) return 1 ;;
  esac
}

echo -e "${BOLD}🔧 Revisar configurações (pressione Enter para manter o valor atual)${RESET}"
prompt_edit ORIG_SSH_USER "${ORIG_SSH_USER}" "Usuário SSH do servidor de origem"
prompt_edit ORIG_SSH_HOST "${ORIG_SSH_HOST}" "Host/IP do servidor de origem"
prompt_edit IMPORTS_DIR "${IMPORTS_DIR}" "Diretório local de imports"
prompt_edit EXPORTS_TMP_DIR "${EXPORTS_TMP_DIR}" "Diretório temporário no servidor remoto para exports"
prompt_edit CONTAINER_NAME "${CONTAINER_NAME}" "Nome do container (local e remoto)"
echo -e "${GREEN}✅ Configurações atualizadas:${RESET}"
echo -e "  • Usuário SSH: ${BOLD}${ORIG_SSH_USER}${RESET}"
echo -e "  • Host SSH: ${BOLD}${ORIG_SSH_HOST}${RESET}"
echo -e "  • Diretório imports local: ${BOLD}${IMPORTS_DIR}${RESET}"
echo -e "  • Diretório temporário remoto: ${BOLD}${EXPORTS_TMP_DIR}${RESET}"
echo -e "  • Nome do container: ${BOLD}${CONTAINER_NAME}${RESET}"

# Checagens prévias
check_command() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERRO: comando '$1' não encontrado. Instale-o e tente novamente."; exit 1; }
}

check_ssh() {
  ssh -o BatchMode=yes -o ConnectTimeout=5 "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" 'echo ok' >/dev/null 2>&1 || {
    echo "ERRO: não foi possível conectar via SSH a ${ORIG_SSH_USER}@${ORIG_SSH_HOST}";
    echo "Verifique rede, chave SSH ou usuário.";
    exit 1;
  }
}

check_local_container() {
  if ! docker inspect --format='{{.State.Running}}' "${CONTAINER_NAME}" >/dev/null 2>&1; then
    echo "ERRO: container local '${CONTAINER_NAME}' não encontrado/rodando. Verifique 'docker ps'.";
    exit 1;
  fi
}

check_remote_container() {
  if ! ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" docker inspect --format='{{.State.Running}}' "${CONTAINER_NAME}" >/dev/null 2>&1; then
    echo "AVISO: não foi possível confirmar que o container '${CONTAINER_NAME}' está rodando no host remoto ${ORIG_SSH_HOST}.";
  fi
}

check_command ssh
check_command scp
check_command docker
check_command curl
echo "==> Executando checagens prévias (pre-flight)..."
check_ssh
check_remote_container
check_local_container
echo "==> Checagens prévias OK."

# Funções auxiliares
ssh_container() {
  ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" -- docker exec "${CONTAINER_NAME}" "$@"
}

local_container() {
  docker exec "${CONTAINER_NAME}" "$@"
}

get_access_token() {
  echo -e "${BLUE}⤷ Tentando autenticar no Superset (${SUPERSET_URL})...${RESET}"

  local response
  response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X POST "${SUPERSET_URL}/api/v1/security/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${SUPERSET_USERNAME}\",\"password\":\"${SUPERSET_PASSWORD}\"}" 2>&1)

  local http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d':' -f2)
  local body=$(echo "$response" | sed '/HTTP_CODE:/d')

  if [ "$http_code" != "200" ]; then
    echo -e "${RED}❌ Erro na autenticação. HTTP Code: ${http_code}${RESET}"
    echo -e "${YELLOW}Response: ${body}${RESET}"
    return 1
  fi

  local token=$(echo "$body" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

  if [ -z "$token" ]; then
    echo -e "${RED}❌ Token não encontrado na resposta${RESET}"
    echo -e "${YELLOW}Response: ${body}${RESET}"
    return 1
  fi

  echo "$token"
}

delete_existing_dashboards() {
  local token=$1

  echo -e "${YELLOW}🔍 Buscando dashboards existentes...${RESET}"

  local response
  response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X GET "${SUPERSET_URL}/api/v1/dashboard/?q=(page_size:1000)" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" 2>&1)

  local http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d':' -f2)
  local body=$(echo "$response" | sed '/HTTP_CODE:/d')

  if [ "$http_code" != "200" ]; then
    echo -e "${RED}❌ Erro ao buscar dashboards. HTTP Code: ${http_code}${RESET}"
    return 1
  fi

  local dashboard_ids
  dashboard_ids=$(echo "$body" | grep -o '"id":[0-9]*' | cut -d':' -f2 | sort -u)

  if [ -z "$dashboard_ids" ]; then
    echo -e "${GREEN}✅ Nenhum dashboard existente encontrado.${RESET}"
    return 0
  fi

  local count=$(echo "$dashboard_ids" | wc -l)
  echo -e "${YELLOW}📋 Dashboards encontrados: ${count}${RESET}"

  if confirm "Deseja deletar os ${count} dashboards existentes antes de importar?"; then
    for id in $dashboard_ids; do
      echo -e "${BLUE}⤷ Deletando dashboard ID: ${id}${RESET}"
      local del_response
      del_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X DELETE "${SUPERSET_URL}/api/v1/dashboard/${id}" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" 2>&1)

      local del_code=$(echo "$del_response" | grep "HTTP_CODE:" | cut -d':' -f2)
      if [ "$del_code" != "200" ]; then
        echo -e "${RED}  ⚠️  Erro ao deletar dashboard ${id} (HTTP ${
