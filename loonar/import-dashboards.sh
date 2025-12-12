#!/usr/bin/bash
set -euo pipefail

clear

# Configurações padrão
ORIG_SSH_USER="devopsvanilla"
ORIG_SSH_HOST="192.168.0.222"
IMPORTS_DIR="./imports"
EXPORTS_TMP_DIR="/tmp/superset_exports"
CONTAINER_NAME="superset_app"

# Parse CLI flags
show_help() {
  cat <<EOF
Uso: $0 [opções]
  --user USUARIO           Usuário SSH do servidor de origem
  --host HOST              Host/IP do servidor de origem
  --imports-dir DIR        Diretório local para salvar imports
  --exports-tmp-dir DIR    Diretório temporário remoto para exports
  --container NOME         Nome do container (local e remoto)
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
    --no-prompt)
      NO_PROMPT=1; shift;;
    -h|--help)
      show_help; exit 0;;
    *)
      echo "Opção desconhecida: $1"; show_help; exit 1;;
  esac
done

# Interface interativa: cores, emojis e prompts para confirmar/editar valores
# Definições de cor
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Se NO_PROMPT=1 for set, pula todas as interações (útil para CI)
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

# Confirmação simples sim/não (default sim)
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

# Permite ao usuário revisar/editar valores iniciais
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

# -----------------------------
# Checagens prévias (pre-flight)
# -----------------------------
print_usage() {
  cat <<-USAGE
Usage: ORIG_SSH_USER=usuario ORIG_SSH_HOST=host ./import-dashboards.sh

Variáveis de ambiente opcionais:
  ORIG_SSH_USER - usuário SSH do servidor de origem (padrão: ${ORIG_SSH_USER})
  ORIG_SSH_HOST - FQDN/IP do servidor de origem (padrão: ${ORIG_SSH_HOST})
  IMPORTS_DIR   - diretório local para salvar importações (padrão: ${IMPORTS_DIR})
USAGE
}

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
  # tenta inspecionar o container no host remoto; não falha necessariamente, só avisa
  if ! ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" docker inspect --format='{{.State.Running}}' "${CONTAINER_NAME}" >/dev/null 2>&1; then
    echo "AVISO: não foi possível confirmar que o container '${CONTAINER_NAME}' está rodando no host remoto ${ORIG_SSH_HOST}.";
    echo "Continuando porque export pode ainda funcionar via comando 'superset' no container remoto.";
  fi
}

# Executa checagens básicas
check_command ssh
check_command scp
check_command docker
echo "==> Executando checagens prévias (pre-flight)..."
check_ssh
check_remote_container
check_local_container
echo "==> Checagens prévias OK."

# Função para executar comandos no container do servidor de origem via SSH
ssh_container() {
  # Passa os argumentos corretamente para o ssh (evita problemas com quoting)
  ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" -- docker exec "${CONTAINER_NAME}" "$@"
}

# Função para executar comandos no container local
local_container() {
  # Passa os argumentos corretamente ao docker exec
  docker exec "${CONTAINER_NAME}" "$@"
}


echo -e "${BOLD}🚀 Iniciando exportação de dashboards, charts e datasets do servidor de origem...${RESET}"

# Cria diretório temporário no servidor de origem
echo -e "${BLUE}⤷ Criando diretório temporário remoto: ${EXPORTS_TMP_DIR}${RESET}"
ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" -- mkdir -p -- "${EXPORTS_TMP_DIR}"


# Pergunta antes de exportar
if confirm "Executar export no servidor remoto?"; then
  echo -e "${YELLOW}📦 Exportando dashboards...${RESET}"
  ssh_container superset export-dashboards "${EXPORTS_TMP_DIR}/dashboards.zip" && echo -e "${GREEN}✅ Dashboards exportados: ${EXPORTS_TMP_DIR}/dashboards.zip${RESET}"

  echo -e "${YELLOW}📊 Exportando charts...${RESET}"
  ssh_container superset export-charts "${EXPORTS_TMP_DIR}/charts.zip" && echo -e "${GREEN}✅ Charts exportados: ${EXPORTS_TMP_DIR}/charts.zip${RESET}"

  echo -e "${YELLOW}🗂️  Exportando datasets...${RESET}"
  ssh_container superset export-datasets "${EXPORTS_TMP_DIR}/datasets.zip" && echo -e "${GREEN}✅ Datasets exportados: ${EXPORTS_TMP_DIR}/datasets.zip${RESET}"
else
  echo -e "${RED}Abortando export conforme escolha do usuário.${RESET}"
  exit 1
fi

echo -e "${BLUE}📁 Copiando arquivos exportados para o servidor local (${IMPORTS_DIR})...${RESET}"
mkdir -p "${IMPORTS_DIR}"
scp "${ORIG_SSH_USER}@${ORIG_SSH_HOST}:${EXPORTS_TMP_DIR}/dashboards.zip" "${IMPORTS_DIR}/" && echo -e "${GREEN}✅ Copiado: dashboards.zip${RESET}"
scp "${ORIG_SSH_USER}@${ORIG_SSH_HOST}:${EXPORTS_TMP_DIR}/charts.zip" "${IMPORTS_DIR}/" && echo -e "${GREEN}✅ Copiado: charts.zip${RESET}"
scp "${ORIG_SSH_USER}@${ORIG_SSH_HOST}:${EXPORTS_TMP_DIR}/datasets.zip" "${IMPORTS_DIR}/" && echo -e "${GREEN}✅ Copiado: datasets.zip${RESET}"

echo -e "${BOLD}🔁 Importando datasets, charts e dashboards no servidor local...${RESET}"
if confirm "Prosseguir com import no container local '${CONTAINER_NAME}'?"; then
  local_container superset import-datasets "${IMPORTS_DIR}/datasets.zip" && echo -e "${GREEN}✅ Datasets importados.${RESET}"
  local_container superset import-charts "${IMPORTS_DIR}/charts.zip" && echo -e "${GREEN}✅ Charts importados.${RESET}"
  local_container superset import-dashboards "${IMPORTS_DIR}/dashboards.zip" && echo -e "${GREEN}✅ Dashboards importados.${RESET}"
else
  echo -e "${RED}Import abortado pelo usuário.${RESET}"
  exit 1
fi

echo -e "${YELLOW}🧹 Limpeza dos arquivos temporários no servidor de origem...${RESET}"
if confirm "Remover '${EXPORTS_TMP_DIR}' no servidor remoto?"; then
  ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" -- rm -rf -- "${EXPORTS_TMP_DIR}" && echo -e "${GREEN}✅ Limpeza remota concluída.${RESET}"
else
  echo -e "${YELLOW}⚠️  Arquivos temporários mantidos em ${ORIG_SSH_HOST}:${EXPORTS_TMP_DIR}${RESET}"
fi

echo -e "${BOLD}${GREEN}🎉 Processo concluído com sucesso!${RESET}"
