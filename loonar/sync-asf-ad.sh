#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

LOG_PATH="$SCRIPT_DIR"
LOG_FILE=""

DEBUG=false
SHOW_LOG=false
RETAIN_LOGS_MAX_DAYS=7

declare -a AD_GROUPS=()
declare -a CREATED_ROLES=()
declare -a UPDATED_ROLES=()
declare -a FAILED_ROLES=()

load_env_file() {
  local env_file="${LOONAR_ENV_FILE:-$SCRIPT_DIR/.env}"
  if [[ ! -f "$env_file" ]]; then
    printf 'ERROR: Arquivo .env não encontrado em "%s".\n' "$env_file" >&2
    exit 1
  fi

  # Carregamento no formato dotenv (não é shell): suporta espaços e caracteres especiais.
  # Exemplos que quebram `export $(... | xargs)`:
  #   LOONAR_LDAP_BIND_DN_REAL=CN=Morpheus Serviços,...   (contém espaço)
  #   LOONAR_LDAP_BIND_PASSWORD_REAL=Morph&us#2020       (& é metacaractere)
  local loaded=0
  local skipped=0
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove CR (arquivos com \r\n)
    line="${line%$'\r'}"

    # Trim à esquerda
    line="${line#"${line%%[![:space:]]*}"}"

    # Ignora vazias/comentários
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    # Permite prefixo 'export '
    if [[ "$line" == export\ * ]]; then
      line="${line#export }"
      line="${line#"${line%%[![:space:]]*}"}"
    fi

    # Precisa ter '='
    if [[ "$line" != *"="* ]]; then
      ((++skipped))
      continue
    fi

    key="${line%%=*}"
    value="${line#*=}"

    # Trim key/value
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    # Remove aspas simples/duplas ao redor (dotenv comum)
    if [[ ${#value} -ge 2 ]]; then
      if [[ ("$value" == '"'*'"') || ("$value" == "'"*"'") ]]; then
        value="${value:1:${#value}-2}"
      fi
    fi

    # Valida nome da variável (evita linhas inválidas)
    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      ((++skipped))
      continue
    fi

    export "$key=$value"
    ((++loaded))
  done < "$env_file"

  printf 'INFO: Arquivo .env carregado com sucesso: %s (vars=%s, ignoradas=%s).\n' "$env_file" "$loaded" "$skipped" >&2
}

validate_env_vars() {
  local missing=()

  [[ -z "${LOONAR_LDAP_MODE:-}" ]] && missing+=("LOONAR_LDAP_MODE")
  [[ -z "${LOONAR_SUPERSET_BASE_ROLE:-}" ]] && missing+=("LOONAR_SUPERSET_BASE_ROLE")

  case "${LOONAR_LDAP_MODE,,}" in
    real)
      [[ -z "${LOONAR_LDAP_SERVER_REAL:-}" ]] && missing+=("LOONAR_LDAP_SERVER_REAL")
      [[ -z "${LOONAR_LDAP_BIND_DN_REAL:-}" ]] && missing+=("LOONAR_LDAP_BIND_DN_REAL")
      [[ -z "${LOONAR_LDAP_BIND_PASSWORD_REAL:-}" ]] && missing+=("LOONAR_LDAP_BIND_PASSWORD_REAL")
      [[ -z "${LOONAR_LDAP_GROUP_BASE_REAL:-}" ]] && missing+=("LOONAR_LDAP_GROUP_BASE_REAL")
      ;;
    mock)
      if [[ -z "${LOONAR_LDAP_SERVER_MOCK:-}" && -z "${LOONAR_LDAP_SERVER_MOCK_INTERNAL:-}" ]]; then
        missing+=("LOONAR_LDAP_SERVER_MOCK|LOONAR_LDAP_SERVER_MOCK_INTERNAL")
      fi
      [[ -z "${LOONAR_LDAP_BIND_DN_MOCK:-}" ]] && missing+=("LOONAR_LDAP_BIND_DN_MOCK")
      [[ -z "${LOONAR_LDAP_BIND_PASSWORD_MOCK:-}" ]] && missing+=("LOONAR_LDAP_BIND_PASSWORD_MOCK")
      [[ -z "${LOONAR_LDAP_GROUP_BASE_MOCK:-}" ]] && missing+=("LOONAR_LDAP_GROUP_BASE_MOCK")
      ;;
    *)
      printf 'ERROR: Valor inválido para LOONAR_LDAP_MODE (use "real" ou "mock").\n' >&2
      exit 1
      ;;
  esac

  if (( ${#missing[@]} > 0 )); then
    printf 'ERROR: Variáveis obrigatórias ausentes no .env: %s\n' "${missing[*]}" >&2
    exit 1
  fi
}

usage() {
  cat <<EOF
Uso: $SCRIPT_NAME [--retain_logs_max_days "<dias>"] [--log_path "/dir/logs"] \
                  [--debug] [--show_log]

Variáveis carregadas do .env:
  LOONAR_LDAP_MODE               Define se usa LDAP real ou mock
  LOONAR_LDAP_SERVER_REAL        URI/host do LDAP real
  LOONAR_LDAP_BIND_DN_REAL       Bind DN do LDAP real
  LOONAR_LDAP_BIND_PASSWORD_REAL Senha do LDAP real
  LOONAR_LDAP_GROUP_BASE_REAL    Base DN de grupos (real)
  LOONAR_LDAP_USE_SSL_REAL       true|false

  LOONAR_LDAP_SERVER_MOCK        URI/host do LDAP mock
  LOONAR_LDAP_SERVER_MOCK_INTERNAL URI/host interno do LDAP mock (prioridade)
  LOONAR_LDAP_BIND_DN_MOCK       Bind DN do LDAP mock
  LOONAR_LDAP_BIND_PASSWORD_MOCK Senha do LDAP mock
  LOONAR_LDAP_GROUP_BASE_MOCK    Base DN de grupos (mock)
  LOONAR_LDAP_USE_SSL_MOCK       true|false

  LOONAR_SUPERSET_BASE_ROLE      Role base do Superset para copiar permissões (obrigatória)
  LOONAR_LDAP_CN_TERM            Termo opcional que deve aparecer no CN dos grupos (filtro)

Parâmetros opcionais:
  --retain_logs_max_days  Dias de retenção dos logs (padrão 7)
  --log_path              Diretório onde os logs serão gravados (padrão: diretório do script)
  --debug                 Registra no log a saída completa dos comandos
  --show_log              Exibe as mensagens também no stdout
  -h, --help              Mostra esta ajuda
EOF
}

log() {
  local level="$1"; shift
  local message="$*"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  # Sempre grava em arquivo quando configurado.
  if [[ -n "$LOG_FILE" ]]; then
    printf '%s [%s] %s\n' "$ts" "$level" "$message" >>"$LOG_FILE"
  fi

  # Por padrão, mantenha o terminal “limpo”, mas não esconda erros.
  # - Se --show_log: ecoa tudo no stdout.
  # - Caso contrário: ecoa WARN/ERROR no stderr.
  if [[ "$SHOW_LOG" == "true" ]]; then
    printf '%s [%s] %s\n' "$ts" "$level" "$message"
  else
    case "$level" in
      ERROR|WARN)
        printf '%s [%s] %s\n' "$ts" "$level" "$message" >&2
        ;;
    esac
  fi
}

exit_with_help() {
  log ERROR "$1"
  usage >&2
  exit 1
}

expect_value() {
  local option="$1"
  local value="$2"
  if [[ -z "$value" || "$value" == --* ]]; then
    exit_with_help "O parâmetro $option requer um valor válido."
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --retain_logs_max_days)
        local value="${2-}"
        expect_value "$1" "$value"
        RETAIN_LOGS_MAX_DAYS="$value"
        shift 2
        ;;
      --retain_logs_max_days=*)
        RETAIN_LOGS_MAX_DAYS="${1#*=}"
        shift
        ;;
      --log_path)
        local value="${2-}"
        expect_value "$1" "$value"
        LOG_PATH="$value"
        shift 2
        ;;
      --log_path=*)
        LOG_PATH="${1#*=}"
        shift
        ;;
      --debug)
        DEBUG=true
        shift
        ;;
      --show_log)
        SHOW_LOG=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        exit_with_help "Parâmetro desconhecido: $1"
        ;;
    esac
  done
}

validate_params() {
  if [[ ! "$RETAIN_LOGS_MAX_DAYS" =~ ^[0-9]+$ ]] || (( RETAIN_LOGS_MAX_DAYS <= 0 )); then
    exit_with_help "O parâmetro --retain_logs_max_days deve ser um inteiro positivo."
  fi
}

ensure_command() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    exit_with_help "Dependência obrigatória não encontrada: $bin"
  fi
}

ensure_container_running() {
  if ! docker inspect -f '{{.State.Running}}' superset_app >/dev/null 2>&1; then
    exit_with_help "O container 'superset_app' não está em execução ou não existe."
  fi
}

normalize_ldap_uri() {
  local server="$1"
  local use_ssl="$2"

  if [[ "$server" =~ ^ldaps?:// ]]; then
    echo "$server"
    return
  fi

  local scheme="ldap"
  if [[ "${use_ssl,,}" == "true" ]]; then
    scheme="ldaps"
  fi
  echo "${scheme}://${server}"
}

resolve_ldap_context() {
  # NÃO declare LDAP_* como local aqui.
  # Em Bash, variáveis têm escopo dinâmico: o chamador (ex: fetch_ad_groups)
  # declara `local LDAP_URI ...` e esta função deve preencher esses valores.
  case "${LOONAR_LDAP_MODE,,}" in
    real)
      LDAP_URI="$(normalize_ldap_uri "$LOONAR_LDAP_SERVER_REAL" "${LOONAR_LDAP_USE_SSL_REAL:-false}")"
      LDAP_BIND_DN="$LOONAR_LDAP_BIND_DN_REAL"
      LDAP_BIND_PASSWORD="$LOONAR_LDAP_BIND_PASSWORD_REAL"
      LDAP_GROUP_BASE="$LOONAR_LDAP_GROUP_BASE_REAL"
      ;;
    mock)
      local server_source="$LOONAR_LDAP_SERVER_MOCK"
      if [[ -n "${LOONAR_LDAP_SERVER_MOCK_INTERNAL:-}" ]]; then
        server_source="$LOONAR_LDAP_SERVER_MOCK_INTERNAL"
      fi
      LDAP_URI="$(normalize_ldap_uri "$server_source" "${LOONAR_LDAP_USE_SSL_MOCK:-false}")"
      LDAP_BIND_DN="$LOONAR_LDAP_BIND_DN_MOCK"
      LDAP_BIND_PASSWORD="$LOONAR_LDAP_BIND_PASSWORD_MOCK"
      LDAP_GROUP_BASE="$LOONAR_LDAP_GROUP_BASE_MOCK"
      ;;
    *)
      exit_with_help "Modo LDAP inválido: ${LOONAR_LDAP_MODE}."
      ;;
  esac

  log INFO "Modo LDAP: ${LOONAR_LDAP_MODE} | URI: ${LDAP_URI} | Base: ${LDAP_GROUP_BASE}"
}

cleanup_old_logs() {
  local retain="$RETAIN_LOGS_MAX_DAYS"
  local threshold=$((retain - 1))
  local removed=0
  while IFS= read -r -d '' file; do
    rm -f "$file"
    ((removed++))
    log INFO "Log removido por retenção: $(basename "$file")"
  done < <(find "$LOG_PATH" -maxdepth 1 -type f -name 'sync-asf-ad_*.log' -mtime +"$threshold" -print0)
  log INFO "Limpeza de logs concluída (arquivos removidos: $removed)."
}

debug_block() {
  local prefix="$1"
  local content="$2"
  [[ "$DEBUG" == "true" ]] || return 0
  while IFS= read -r line; do
    log INFO "[DEBUG] $prefix$line"
  done <<<"$content"
}

configure_log_path() {
  local target="$LOG_PATH"
  if [[ -z "$target" ]]; then
    target="$SCRIPT_DIR"
  fi
  if [[ ! -d "$target" ]]; then
    printf 'ERROR: Diretório de logs "%s" não existe.\n' "$target" >&2
    exit 1
  fi
  LOG_PATH="$(cd "$target" && pwd)"
  LOG_FILE="$LOG_PATH/sync-asf-ad_$(date +%d%m%Y%H%M%S).log"
  if ! touch "$LOG_FILE"; then
    printf 'ERROR: Não foi possível criar o arquivo de log em "%s".\n' "$LOG_FILE" >&2
    exit 1
  fi

  # Dica explícita (vai para o stderr e aparece mesmo sem --show_log)
  printf 'INFO: Logs serão gravados em "%s" (use --show_log para ver no terminal).\n' "$LOG_FILE" >&2
}

ensure_base_role_exists() {
  local output=""
  if ! output=$(docker exec -i superset_app python3 - "$LOONAR_SUPERSET_BASE_ROLE" <<'PY'
from __future__ import annotations

import sys
from superset.app import create_app
from superset.extensions import security_manager


def main(role_name: str) -> None:
    app = create_app()
    with app.app_context():
        role = security_manager.find_role(role_name)
        if role is None:
            print("BASE_ROLE_NOT_FOUND", file=sys.stderr)
            raise SystemExit(1)
        print("BASE_ROLE_OK")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Uso: check_base_role.py <role>")
    main(sys.argv[1])
PY
); then
    log ERROR "Role base '${LOONAR_SUPERSET_BASE_ROLE}' não encontrada. Detalhes: ${output:-sem saída}."
    exit 1
  fi
  debug_block "verificação role base >> " "$output"
  log INFO "Role base '${LOONAR_SUPERSET_BASE_ROLE}' confirmada no Superset."
}

fetch_ad_groups() {
  local LDAP_URI LDAP_BIND_DN LDAP_BIND_PASSWORD LDAP_GROUP_BASE
  resolve_ldap_context

  local filter="(objectClass=group)"
  if [[ -n "${LOONAR_LDAP_CN_TERM:-}" ]]; then
    filter="(&(objectClass=group)(cn=*${LOONAR_LDAP_CN_TERM}*))"
  fi
  local raw_output=""
  if ! raw_output=$(LDAPTLS_REQCERT=allow ldapsearch -LLL -x -H "$LDAP_URI" -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PASSWORD" -b "$LDAP_GROUP_BASE" "$filter" cn); then
    log ERROR "Falha ao consultar grupos no LDAP (${LOONAR_LDAP_MODE})."
    exit 1
  fi
  debug_block "ldapsearch >> " "$raw_output"
  mapfile -t AD_GROUPS < <(printf '%s\n' "$raw_output" | awk -F': ' '/^cn: / {print $2}' | sort -u)
  local filtro_desc="todos"
  if [[ -n "${LOONAR_LDAP_CN_TERM:-}" ]]; then
    filtro_desc="cn contendo '${LOONAR_LDAP_CN_TERM}'"
  fi
  log INFO "Total de grupos encontrados (${filtro_desc}): ${#AD_GROUPS[@]}."
}

sync_role_permissions() {
  local role_name="$1"
  local output=""
  if ! output=$(docker exec -i superset_app python3 - "$LOONAR_SUPERSET_BASE_ROLE" "$role_name" <<'PY'
from __future__ import annotations

import sys
from typing import Optional, Tuple

from superset.app import create_app
from superset.extensions import db, security_manager


def sync_role(base_role_name: str, target_role_name: str) -> Tuple[str, str]:
    app = create_app()
    with app.app_context():
        base_role = security_manager.find_role(base_role_name)
        if base_role is None:
            raise ValueError(f"Role base '{base_role_name}' não encontrada.")
        target_role = security_manager.find_role(target_role_name)
        created = False
        if target_role is None:
            target_role = security_manager.add_role(target_role_name)
            created = True
        target_role.permissions = list(base_role.permissions)
        db.session.add(target_role)
        db.session.commit()
        return target_role.name, "created" if created else "updated"


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Uso: clone_role.py <role_base> <role_destino>")
    try:
        name, status = sync_role(sys.argv[1], sys.argv[2])
    except ValueError as exc:
        db.session.rollback()
        print(str(exc), file=sys.stderr)
        raise SystemExit(1) from exc
    print(f"ROLE_SYNC_OK:{name}:{status}")
PY
); then
    log ERROR "Erro ao sincronizar role '${role_name}'. Detalhes: ${output:-sem saída}."
    FAILED_ROLES+=("$role_name")
    return 1
  fi
  debug_block "docker exec >> " "$output"
  if [[ "$output" =~ ^ROLE_SYNC_OK:([^:]+):([^:]+)$ ]]; then
    local name="${BASH_REMATCH[1]}"
    local status="${BASH_REMATCH[2]}"
    if [[ "$status" == "created" ]]; then
      CREATED_ROLES+=("$name")
      log INFO "Role '${name}' criada e sincronizada."
    else
      UPDATED_ROLES+=("$name")
      log INFO "Role '${name}' atualizada."
    fi
  else
    log INFO "Role '${role_name}' processada. Saída: $output"
    UPDATED_ROLES+=("$role_name")
  fi
  return 0
}

process_groups() {
  local group
  for group in "${AD_GROUPS[@]}"; do
    [[ -z "$group" ]] && continue
    log INFO "Processando grupo '${group}'."
    sync_role_permissions "$group" || continue
  done
}

summarize() {
  log INFO "Roles processadas: ${#AD_GROUPS[@]}"
  if (( ${#CREATED_ROLES[@]} > 0 )); then
    log INFO "Roles criadas: ${CREATED_ROLES[*]}"
  fi
  if (( ${#UPDATED_ROLES[@]} > 0 )); then
    log INFO "Roles atualizadas (já existiam): ${UPDATED_ROLES[*]}"
  fi
  if (( ${#FAILED_ROLES[@]} > 0 )); then
    log ERROR "Falha ao sincronizar as roles: ${FAILED_ROLES[*]}"
    exit 1
  fi
  log INFO "Processo concluído com sucesso."
}

main() {
  load_env_file
  validate_env_vars
  parse_args "$@"
  configure_log_path
  trap 'log ERROR "Execução interrompida."; exit 1' INT TERM
  validate_params
  cleanup_old_logs
  ensure_command ldapsearch
  ensure_command docker
  ensure_container_running

  log INFO "Iniciando sincronização (container=superset_app, modo='${LOONAR_LDAP_MODE}', role base='${LOONAR_SUPERSET_BASE_ROLE}', filtro='${LOONAR_LDAP_CN_TERM:-todos}')."

  ensure_base_role_exists
  fetch_ad_groups

  if (( ${#AD_GROUPS[@]} == 0 )); then
    log INFO "Nenhum grupo encontrado. Nada a realizar."
    exit 0
  fi

  process_groups
  summarize
}

main "$@"
