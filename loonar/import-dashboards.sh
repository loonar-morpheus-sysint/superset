#!/usr/bin/bash
# set -u faz o script parar se usar variável não definida.
set -euo pipefail

clear

# ==============================================================================
# 1. DEFINIÇÕES GLOBAIS (CORES E FUNÇÕES)
# ==============================================================================
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

# ==============================================================================
# 2. CONFIGURAÇÕES PADRÃO
# ==============================================================================
ORIG_SSH_USER="devopsvanilla"
ORIG_SSH_HOST="192.168.0.222"
CONTAINER_NAME="superset_app"
HOST_IMPORTS_DIR="./imports"
CONTAINER_IMPORTS_DIR="/tmp/local_superset_imports"
EXPORTS_TMP_DIR="/tmp/superset_exports"

# URI de Conexão do Superset de Destino (Local)
SUPERSET_SQL_URI="postgresql+psycopg2://superset:XXXXXXXXX@db:5432/superset"

# ==============================================================================
# 3. PARSE DE ARGUMENTOS
# ==============================================================================
show_help() {
  cat <<EOF
Uso: $0 [opções]
  --user USUARIO           Usuário SSH do servidor de origem
  --host HOST              Host/IP do servidor de origem
  --imports-dir DIR        Diretório local (Host) para salvar imports
  --exports-tmp-dir DIR    Diretório temporário remoto para exports
  --container NOME         Nome do container (local e remoto)
  --sql-uri URI            SQLAlchemy URI completa do Superset local (com senha)
  --no-prompt              Não perguntar nada (modo não-interativo)
  -h, --help               Exibe esta ajuda
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --user) ORIG_SSH_USER="$2"; shift 2;;
    --host) ORIG_SSH_HOST="$2"; shift 2;;
    --imports-dir) HOST_IMPORTS_DIR="$2"; shift 2;;
    --exports-tmp-dir) EXPORTS_TMP_DIR="$2"; shift 2;;
    --container) CONTAINER_NAME="$2"; shift 2;;
    --sql-uri) SUPERSET_SQL_URI="$2"; shift 2;;
    --superset-run-user|--superset-url|--superset-user|--superset-pass) shift 2;;
    --no-prompt) NO_PROMPT=1; shift;;
    -h|--help) show_help; exit 0;;
    *) echo "Opção desconhecida: $1"; show_help; exit 1;;
  esac
done

# ==============================================================================
# 4. FUNÇÕES DE DOCKER/SSH E CHECAGENS
# ==============================================================================
ssh_container() {
  ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" -- docker exec "${CONTAINER_NAME}" "$@"
}

local_container() {
  docker exec "${CONTAINER_NAME}" "$@"
}

check_command() {
  command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}ERRO: comando '$1' não encontrado. Instale-o.${RESET}"; exit 1; }
}

check_ssh() {
  ssh -o BatchMode=yes -o ConnectTimeout=5 "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" 'echo ok' >/dev/null 2>&1 || {
    echo -e "${RED}ERRO: falha na conexão SSH com ${ORIG_SSH_USER}@${ORIG_SSH_HOST}${RESET}"; exit 1; }
}

check_local_container() {
  if ! docker inspect --format='{{.State.Running}}' "${CONTAINER_NAME}" >/dev/null 2>&1; then
    echo -e "${RED}ERRO: container local '${CONTAINER_NAME}' não encontrado/rodando.${RESET}"; exit 1;
  fi
}

# ==============================================================================
# 5. EXECUÇÃO PRINCIPAL
# ==============================================================================

echo -e "${BOLD}🔧 Revisar configurações (pressione Enter para manter o valor atual)${RESET}"
prompt_edit ORIG_SSH_USER "${ORIG_SSH_USER}" "Usuário SSH do servidor de origem"
prompt_edit ORIG_SSH_HOST "${ORIG_SSH_HOST}" "Host/IP do servidor de origem"
prompt_edit HOST_IMPORTS_DIR "${HOST_IMPORTS_DIR}" "Diretório local de imports (Host)"
prompt_edit EXPORTS_TMP_DIR "${EXPORTS_TMP_DIR}" "Diretório temporário remoto"
prompt_edit CONTAINER_NAME "${CONTAINER_NAME}" "Nome do container"
prompt_edit SUPERSET_SQL_URI "${SUPERSET_SQL_URI}" "SQLAlchemy URI Local (COM SENHA)"

echo -e "${GREEN}✅ Configurações validadas.${RESET}"

echo "==> Executando checagens prévias..."
check_command ssh; check_command scp; check_command docker; check_command unzip; check_command zip; check_command find; check_command sed
check_ssh; check_local_container
echo "==> Checagens OK."

# --- FASE 1: EXPORTAÇÃO REMOTA ---
echo -e "${BOLD}🚀 Iniciando exportação remota...${RESET}"
echo -e "${BLUE}⤷ Preparando diretórios remotos...${RESET}"
ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" -- mkdir -p -- "${EXPORTS_TMP_DIR}"
ssh_container mkdir -p "${EXPORTS_TMP_DIR}"

if confirm "Executar export no servidor remoto?"; then
  echo -e "${YELLOW}📦 Exportando artefatos...${RESET}"
  ssh_container superset export-dashboards -f "${EXPORTS_TMP_DIR}/dashboards.zip"
  ssh_container superset export-datasources -f "${EXPORTS_TMP_DIR}/datasets.zip"

  echo -e "${BLUE}⤷ Copiando do container remoto para o host remoto...${RESET}"
  ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" -- docker cp "${CONTAINER_NAME}:${EXPORTS_TMP_DIR}/dashboards.zip" "${EXPORTS_TMP_DIR}/dashboards.zip"
  ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" -- docker cp "${CONTAINER_NAME}:${EXPORTS_TMP_DIR}/datasets.zip" "${EXPORTS_TMP_DIR}/datasets.zip"
  echo -e "${GREEN}✅ Exportação concluída.${RESET}"
else
  echo -e "${RED}Abortado pelo usuário.${RESET}"; exit 1
fi

# --- FASE 2: TRANSFERÊNCIA ---
echo -e "${BLUE}📁 Baixando arquivos para local (${HOST_IMPORTS_DIR})...${RESET}"
mkdir -p "${HOST_IMPORTS_DIR}"
scp -q "${ORIG_SSH_USER}@${ORIG_SSH_HOST}:${EXPORTS_TMP_DIR}/dashboards.zip" "${HOST_IMPORTS_DIR}/"
scp -q "${ORIG_SSH_USER}@${ORIG_SSH_HOST}:${EXPORTS_TMP_DIR}/datasets.zip" "${HOST_IMPORTS_DIR}/"
echo -e "${GREEN}✅ Arquivos baixados.${RESET}"

# --- FASE 3: PRÉ-PROCESSAMENTO (INJEÇÃO DE SENHA E RENOMEAÇÃO) ---
echo -e "${BOLD}${YELLOW}🔧 Modificando 'datasets.zip' (Senha e Nome do Banco)...${RESET}"

TEMP_UNZIP_DIR="${HOST_IMPORTS_DIR}/datasets_temp"
DATASETS_ZIP_PATH="${HOST_IMPORTS_DIR}/datasets.zip"
NEW_URI="sqlalchemy_uri: ${SUPERSET_SQL_URI}"

# Limpa temp antigo se existir
rm -rf "${TEMP_UNZIP_DIR}"
mkdir -p "${TEMP_UNZIP_DIR}"

echo -e "${BLUE}⤷ Descompactando...${RESET}"
unzip -q -o "${DATASETS_ZIP_PATH}" -d "${TEMP_UNZIP_DIR}"

echo -e "${BLUE}⤷ Procurando arquivos YAML de banco de dados...${RESET}"
# Usa find recursivo para achar arquivos .yaml dentro de 'databases'
YAML_FILES=$(find "${TEMP_UNZIP_DIR}" -type f -path '*/databases/*.yaml')

if [ -n "$YAML_FILES" ]; then
    echo -e "${BLUE}⤷ Arquivos encontrados. Aplicando correções...${RESET}"
    echo "$YAML_FILES" | while read -r file; do
        echo "  - Processando: $file"

        # 1. Substitui a URI (Injeção de Senha)
        sed -i "s|^sqlalchemy_uri:.*|${NEW_URI}|g" "$file"

        # 2. Renomeia o banco de dados (Ex: PostgreSQL -> PostgreSQL_Import)
        # Isso força a criação de uma nova conexão e evita o erro de 'SAWarning/Flush'
        sed -i "s|^database_name:.*|database_name: PostgreSQL_Import|g" "$file"
    done
    echo -e "${GREEN}✅ URIs atualizadas e Banco renomeado para evitar conflitos.${RESET}"
else
    echo -e "${YELLOW}⚠️  AVISO: Nenhum arquivo de configuração de banco de dados encontrado no ZIP.${RESET}"
fi

echo -e "${BLUE}⤷ Recompactando datasets.zip...${RESET}"
(cd "${TEMP_UNZIP_DIR}" && zip -r -q - ./*) > "${DATASETS_ZIP_PATH}"
rm -rf "${TEMP_UNZIP_DIR}"
echo -e "${GREEN}✅ Arquivo pronto para importação.${RESET}"

# --- FASE 4: IMPORTAÇÃO LOCAL ---
echo -e "${BLUE}⤷ Preparando container local...${RESET}"
if local_container mkdir -p "${CONTAINER_IMPORTS_DIR}"; then
    : # Sucesso
else
    echo -e "${RED}❌ Falha ao criar diretório no container. Verifique permissões.${RESET}"; exit 1
fi

echo -e "${BLUE}⤷ Enviando arquivos para o container...${RESET}"
docker cp "${HOST_IMPORTS_DIR}/dashboards.zip" "${CONTAINER_NAME}:${CONTAINER_IMPORTS_DIR}/dashboards.zip"
docker cp "${HOST_IMPORTS_DIR}/datasets.zip" "${CONTAINER_NAME}:${CONTAINER_IMPORTS_DIR}/datasets.zip"

echo -e "${BOLD}🔁 Importando no Superset local...${RESET}"
if confirm "Iniciar importação?"; then
  echo -e "${YELLOW}🗂️  Importando datasets (com conexão de DB)...${RESET}"

  # Desabilita 'set -e' temporariamente para que Warnings do SQLAlchemy não parem o script
  set +e
  local_container superset import-datasources -p "${CONTAINER_IMPORTS_DIR}/datasets.zip" -u admin
  DATA_EXIT_CODE=$?
  set -e

  if [ $DATA_EXIT_CODE -eq 0 ]; then
     echo -e "${GREEN}✅ Datasets importados.${RESET}"
  else
     echo -e "${YELLOW}⚠️  O comando de datasets terminou com código $DATA_EXIT_CODE. Verifique os logs acima, mas prosseguindo para dashboards...${RESET}"
  fi

  echo -e "${YELLOW}📦 Importando dashboards...${RESET}"
  local_container superset import-dashboards -p "${CONTAINER_IMPORTS_DIR}/dashboards.zip" -u admin

  echo -e "${GREEN}✅ Processo de importação finalizado.${RESET}"
  echo -e "${BLUE}ℹ️  Verifique no Superset se uma nova conexão chamada 'PostgreSQL_Import' foi criada.${RESET}"
else
  echo -e "${RED}Abortado.${RESET}"; exit 1
fi

# --- FASE 5: LIMPEZA ---
echo -e "${YELLOW}🧹 Limpando remoto...${RESET}"
if confirm "Remover arquivos temporários remotos?"; then
  ssh "${ORIG_SSH_USER}@${ORIG_SSH_HOST}" -- rm -rf -- "${EXPORTS_TMP_DIR}"
  echo -e "${GREEN}✅ Removido.${RESET}"
else
  echo -e "${YELLOW}Mantido em ${EXPORTS_TMP_DIR}${RESET}"
fi

echo -e "${BOLD}${GREEN}🎉 Sucesso total!${RESET}"
