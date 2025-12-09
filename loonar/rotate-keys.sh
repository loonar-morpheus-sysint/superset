#!/bin/bash
# Script para rotacionar variáveis sensíveis marcadas como [ROTATABLE] no arquivo .env
# Gera segredos compatíveis para cada contexto

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SAMPLE="$SCRIPT_DIR/.env-sample"
ENV_FILE="$SCRIPT_DIR/.env"
TMP_FILE="${ENV_FILE}.tmp"

# Verificar se .env-sample existe
if [ ! -f "$ENV_SAMPLE" ]; then
    echo "❌ Erro: Arquivo .env-sample não encontrado em $SCRIPT_DIR/"
    exit 1
fi

# Se .env já existe, faz backup
if [ -f "$ENV_FILE" ]; then
  TS=$(date +%Y%m%d%H%M)
  cp "$ENV_FILE" "$SCRIPT_DIR/env-backup-$TS"
  echo "Backup do .env criado em env-backup-$TS"
fi
# Funções para geração de segredos
random_secret() {
  # 64 chars, base64
  openssl rand -base64 48 | tr -d '\n'
}
random_password() {
  # 16 chars, alfanumérico
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
}
random_mapbox() {
  # Simula um token (exemplo, não é válido)
  echo "pk.$(openssl rand -hex 16)"
}

awk -v gen_secret="$(random_secret)" -v gen_pass="$(random_password)" -v gen_mapbox="$(random_mapbox)" '
  BEGIN { rotatable=0 }
  {
    if ($0 ~ /^# CHANGE THIS! \[ROTATABLE\]/) {
      rotatable=1
      next
    }
    else if ($0 ~ /^# /) rotatable=0
    else if ($0 ~ /^[A-Z_]+=[^=]*$/ && $0 !~ /=__ROTATE_ME__/) rotatable=0

    if (rotatable && $0 ~ /=__ROTATE_ME__$/) {
      var=gensub(/=.*/, "", "g", $0)
      if (var ~ /SUPERSET_SECRET_KEY/) print var "=" gen_secret
      else if (var ~ /(PASSWORD|MAPBOX_API_KEY)/) {
        if (var ~ /MAPBOX_API_KEY/) print var "=" gen_mapbox
        else print var "=" gen_pass
      }
      else print $0
      rotatable=0
    } else print $0
  }
' "$ENV_SAMPLE" > "$TMP_FILE"

mv "$TMP_FILE" "$ENV_FILE"
echo "✅ Novo .env gerado e variáveis rotacionadas em $ENV_FILE"
