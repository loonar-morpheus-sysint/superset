#!/bin/bash
# update_agents_from_official_docs.sh
# Orquestra atualização dos arquivos de agente Superset a partir da documentação oficial
check_dep() {
  dep="$1"
  install_cmd="$2"
  if ! command -v "$dep" &> /dev/null; then
    echo "Dependência '$dep' não encontrada."
    read -p "Deseja instalar '$dep'? [s/N] " resp
    if [[ "$resp" =~ ^[sS]$ ]]; then
      eval "$install_cmd"
    else
      echo "Execução cancelada por falta de '$dep'."
      exit 10
    fi
  fi
}

# Checa python3
check_dep "python3" "sudo apt update && sudo apt install -y python3"

# Checa pip
check_dep "pip3" "sudo apt install -y python3-pip"

# Checa requests
python3 -c "import requests" 2>/dev/null || {
  echo "Dependência Python 'requests' não encontrada."
  read -p "Deseja instalar 'requests'? [s/N] " resp
  if [[ "$resp" =~ ^[sS]$ ]]; then
    pip3 install requests
  else
    echo "Execução cancelada por falta de 'requests'."
    exit 11
  fi
}

# Checa beautifulsoup4
python3 -c "import bs4" 2>/dev/null || {
  echo "Dependência Python 'beautifulsoup4' não encontrada."
  read -p "Deseja instalar 'beautifulsoup4'? [s/N] " resp
  if [[ "$resp" =~ ^[sS]$ ]]; then
    pip3 install beautifulsoup4
  else
    echo "Execução cancelada por falta de 'beautifulsoup4'."
    exit 12
  fi
}

AGENT_DIR="$(dirname "$0")"
PY_SCRIPT="$AGENT_DIR/fetch_superset_doc.py"

# Mapeamento: nome do agente -> URL oficial
# Adicione/atualize conforme necessário
declare -A DOC_URLS=(
  [AlertsReports]="https://superset.apache.org/docs/alerts-reports"
  [Cache]="https://superset.apache.org/docs/cache"
  [Databases]="https://superset.apache.org/docs/databases"
  [EventLogging]="https://superset.apache.org/docs/event-logging"
  [Theming]="https://superset.apache.org/docs/theming"
  [Timezones]="https://superset.apache.org/docs/timezones"
  # ... adicione outros agentes conforme necessário
)

for agent in "${!DOC_URLS[@]}"; do
  url="${DOC_URLS[$agent]}"
  out_file="$AGENT_DIR/${agent}.config.agent.md"
  echo "Atualizando $agent de $url..."
  python3 "$PY_SCRIPT" "$url" "$out_file"
  if [ $? -eq 0 ]; then
    echo "✔ $out_file atualizado."
  else
    echo "✗ Falha ao atualizar $out_file."
  fi
  # Opcional: diff, log, backup, etc.
done

echo "Atualização concluída."
