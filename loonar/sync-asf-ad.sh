#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

LOG_PATH="${LOG_PATH:-$SCRIPT_DIR}"
LOG_FILE=""

DEBUG=false
SHOW_LOG=false
AD_DN_BASE="${AD_DN_BASE:-}"
AD_CN_TERM="${AD_CN_TERM:-}"
ASF_ROLE_BASE="${ASF_ROLE_BASE:-}"
AD_SVC_USER="${AD_SVC_USER:-}"
AD_SVC_PASSWORD="${AD_SVC_PASSWORD:-}"
RETAIN_LOGS_MAX_DAYS="${RETAIN_LOGS_MAX_DAYS:-}"
AD_URI="${AD_URI:-}"
LDAP_URI=""

declare -a AD_GROUPS=()
declare -a CREATED_ROLES=()
declare -a FAILED_ROLES=()

usage() {
  cat <<EOF
Uso: $SCRIPT_NAME --ad_dn_base "<OU=...,DC=...,DC=...>" --ad_cn_term "<termo>"
                  --asf_role_base "<role>" --ad_svc_user "<CN=...>"
                  --ad_svc_password "<senha>" --retain_logs_max_days "<dias>"
                  [--ad_uri "<ldaps://host>"] [--log_path "/dir/logs"]
                  [--debug] [--show_log]

Parâmetros:
  --ad_dn_base             Base DN no Active Directory (ex: OU=04-CLIENTES,DC=yourcompany,DC=local)
  --ad_cn_term             Termo obrigatório no CN do grupo (alias: --ad_cn_hasterm)
  --asf_role_base          Role do Superset usada como modelo de permissões
  --ad_svc_user            DN completo do usuário de serviço
  --ad_svc_password        Senha do usuário de serviço
  --retain_logs_max_days   Dias para retenção dos logs (inteiro > 0)
  --ad_uri                 URI do servidor LDAP (ex: ldaps://ldap.example.com)
  --log_path               Diretório onde os logs serão gravados
  --debug                  Registra no log a saída completa dos comandos
  --show_log               Exibe as mensagens também no stdout
  -h, --help               Mostra esta ajuda

Observação: cada parâmetro pode ser omitido caso a variável de ambiente de mesmo nome (ex: AD_DN_BASE, AD_URI, LOG_PATH) esteja definida.
EOF
}

log() {
  local level="$1"; shift
  local message="$*"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  if [[ -n "$LOG_FILE" ]]; then
    printf '%s [%s] %s\n' "$ts" "$level" "$message" >>"$LOG_FILE"
  else
    printf '%s [%s] %s\n' "$ts" "$level" "$message" >&2
  fi
  if [[ "$SHOW_LOG" == "true" ]]; then
    printf '%s [%s] %s\n' "$ts" "$level" "$message"
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
      --ad_dn_base)
        local value="${2-}"
        expect_value "$1" "$value"
        AD_DN_BASE="$value"
        shift 2
        ;;
      --ad_dn_base=*)
        AD_DN_BASE="${1#*=}"
        shift
        ;;
      --ad_cn_term|--ad_cn_hasterm)
        local value="${2-}"
        expect_value "$1" "$value"
        AD_CN_TERM="$value"
        shift 2
        ;;
      --ad_cn_term=*|--ad_cn_hasterm=*)
        AD_CN_TERM="${1#*=}"
        shift
        ;;
      --asf_role_base)
        local value="${2-}"
        expect_value "$1" "$value"
        ASF_ROLE_BASE="$value"
        shift 2
        ;;
      --asf_role_base=*)
        ASF_ROLE_BASE="${1#*=}"
        shift
        ;;
      --ad_svc_user)
        local value="${2-}"
        expect_value "$1" "$value"
        AD_SVC_USER="$value"
        shift 2
        ;;
      --ad_svc_user=*)
        AD_SVC_USER="${1#*=}"
        shift
        ;;
      --ad_svc_password)
        local value="${2-}"
        expect_value "$1" "$value"
        AD_SVC_PASSWORD="$value"
        shift 2
        ;;
      --ad_svc_password=*)
        AD_SVC_PASSWORD="${1#*=}"
        shift
        ;;
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
      --ad_uri)
        local value="${2-}"
        expect_value "$1" "$value"
        AD_URI="$value"
        shift 2
        ;;
      --ad_uri=*)
        AD_URI="${1#*=}"
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
  local missing=()
  for var in AD_DN_BASE AD_CN_TERM ASF_ROLE_BASE AD_SVC_USER AD_SVC_PASSWORD RETAIN_LOGS_MAX_DAYS; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    exit_with_help "Parâmetros obrigatórios ausentes: ${missing[*]}"
  fi

  AD_DN_BASE="$(printf '%s' "$AD_DN_BASE" | sed 's/,[[:space:]]*/,/g')"
  if [[ ! "$AD_DN_BASE" =~ ^(OU|DC)=[^,=]+(,(OU|CN|DC)=[^,=]+)+$ ]]; then
    exit_with_help "Valor inválido para --ad_dn_base."
  fi
  if [[ ! "$AD_CN_TERM" =~ ^[-[:alnum:]_]+$ ]]; then
    exit_with_help "Valor inválido para --ad_cn_term (permitido letras, números, -, _)."
  fi
  if [[ ! "$ASF_ROLE_BASE" =~ ^[[:alnum:]_.-]+$ ]]; then
    exit_with_help "Valor inválido para --asf_role_base."
  fi
  if [[ ! "$AD_SVC_USER" =~ ^CN=.* ]]; then
    exit_with_help "Valor inválido para --ad_svc_user (DN deve iniciar com CN=)."
  fi
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

derive_ldap_uri() {
  if [[ -n "${AD_URI:-}" ]]; then
    LDAP_URI="$AD_URI"
    log INFO "LDAP URI definido a partir do parâmetro/variável AD_URI."
    return
  fi

  local part
  local domain_parts=()
  IFS=',' read -ra parts <<<"$AD_DN_BASE"
  for part in "${parts[@]}"; do
    part="$(printf '%s' "$part" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [[ "$part" =~ ^[Dd][Cc]=(.*)$ ]]; then
      domain_parts+=("${BASH_REMATCH[1],,}")
    fi
  done
  if (( ${#domain_parts[@]} == 0 )); then
    exit_with_help "Não foi possível derivar o domínio a partir de --ad_dn_base."
  fi
  local domain
  domain=$(IFS=.; printf '%s' "${domain_parts[*]}")
  local scheme="${AD_LDAP_SCHEME:-ldaps}"
  LDAP_URI="${scheme}://${domain}"
  log INFO "LDAP URI definido automaticamente como '${LDAP_URI}'."
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
}

ensure_base_role_exists() {
  local output=""
  if ! output=$(docker exec -i superset_app python3 - "$ASF_ROLE_BASE" <<'PY'
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
    log ERROR "Role base '${ASF_ROLE_BASE}' não encontrada. Detalhes: ${output:-sem saída}."
    exit 1
  fi
  debug_block "verificação role base >> " "$output"
  log INFO "Role base '${ASF_ROLE_BASE}' confirmada no Superset."
}

fetch_ad_groups() {
  local filter="(&(objectClass=group)(cn=*${AD_CN_TERM}*))"
  local raw_output=""
  if ! raw_output=$(LDAPTLS_REQCERT=allow ldapsearch -LLL -x -H "$LDAP_URI" -D "$AD_SVC_USER" -w "$AD_SVC_PASSWORD" -b "$AD_DN_BASE" "$filter" cn); then
    log ERROR "Falha ao consultar grupos no Active Directory."
    exit 1
  fi
  debug_block "ldapsearch >> " "$raw_output"
  mapfile -t AD_GROUPS < <(printf '%s\n' "$raw_output" | awk -F': ' '/^cn: / {print $2}' | sort -u)
  log INFO "Total de grupos encontrados com o termo '${AD_CN_TERM}': ${#AD_GROUPS[@]}."
}

sync_role_permissions() {
  local role_name="$1"
  local output=""
  if ! output=$(docker exec -i superset_app python3 - "$ASF_ROLE_BASE" "$role_name" <<'PY'
from __future__ import annotations

import sys
from typing import Optional

from superset.app import create_app
from superset.extensions import db, security_manager


def sync_role(base_role_name: str, target_role_name: str) -> str:
    app = create_app()
    with app.app_context():
        base_role = security_manager.find_role(base_role_name)
        if base_role is None:
            raise ValueError(f"Role base '{base_role_name}' não encontrada.")
        target_role = security_manager.find_role(target_role_name)
        if target_role is None:
            target_role = security_manager.add_role(target_role_name)
        target_role.permissions = list(base_role.permissions)
        db.session.add(target_role)
        db.session.commit()
        return target_role.name


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Uso: clone_role.py <role_base> <role_destino>")
    try:
        synced = sync_role(sys.argv[1], sys.argv[2])
    except ValueError as exc:
        db.session.rollback()
        print(str(exc), file=sys.stderr)
        raise SystemExit(1) from exc
    print(f"ROLE_SYNC_OK:{synced}")
PY
); then
    log ERROR "Erro ao sincronizar role '${role_name}'. Detalhes: ${output:-sem saída}."
    FAILED_ROLES+=("$role_name")
    return 1
  fi
  debug_block "docker exec >> " "$output"
  if [[ "$output" == ROLE_SYNC_OK:* ]]; then
    CREATED_ROLES+=("$role_name")
    log INFO "Role '${role_name}' sincronizada com sucesso."
  else
    log INFO "Role '${role_name}' processada. Saída: $output"
    CREATED_ROLES+=("$role_name")
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
    log INFO "Roles sincronizadas: ${CREATED_ROLES[*]}"
  fi
  if (( ${#FAILED_ROLES[@]} > 0 )); then
    log ERROR "Falha ao sincronizar as roles: ${FAILED_ROLES[*]}"
    exit 1
  fi
  log INFO "Processo concluído com sucesso."
}

main() {
  if [[ $# -eq 0 ]]; then
    usage >&2
    exit 1
  fi

  parse_args "$@"
  configure_log_path
  trap 'log ERROR "Execução interrompida."; exit 1' INT TERM
  validate_params
  cleanup_old_logs
  ensure_command ldapsearch
  ensure_command docker
  ensure_container_running
  derive_ldap_uri

  log INFO "Iniciando sincronização (container=superset_app, role base='${ASF_ROLE_BASE}', filtro='${AD_CN_TERM}', base DN='${AD_DN_BASE}')."

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
