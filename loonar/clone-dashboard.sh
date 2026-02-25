#!/bin/bash

# Este script clona um dashboard por meio da exportação de seu YAML,
# alteração de seus metadados e importação como um novo dashboard.
#
# USO:
#
#   ./clone-dashboard.sh <ID_DO_DASHBOARD> <NOME_DO_NOVO_DASHBOARD> [--no-update]
#
# Opcionalmente, você pode definir a variável de ambiente SUPERSET_DOMAIN
# para mirar em um domínio diferente de http://localhost:8088.
#
# O parâmetro --no-update impede a atualização das dependências.
#
# REQUISITOS:
#
#   - Python 3.9+
#   - pip
#
# DEPENDÊNCIAS:
#
#   - superset-sdk
#   - pyyaml
#
# O script irá instalar as dependências automaticamente, a menos que --no-update
# seja especificado.
#
# EXEMPLO:
#
#   ./clone-dashboard.sh 123 "Meu Novo Dashboard"
#   ./clone-dashboard.sh 123 "Meu Outro Dashboard" --no-update
#

set -e

# --- Funções ---

function check_deps() {
    if [ "$UPDATE_DEPS" = true ]; then
        echo "Verificando e atualizando dependências..."
        pip install -U "superset-sdk==0.1.0a15" pyyaml==6.0.1
    else
        echo "Verificação de dependências ignorada (--no-update)."
    fi
}

function login() {
    echo "Fazendo login no Superset..."
    superset-cli --user "$SUPERSET_USER" --password "$SUPERSET_PASSWORD" login
}

function export_dashboard() {
    local dashboard_id=$1
    echo "Exportando dashboard $dashboard_id..."
    mkdir -p ./tmp
    superset-cli dashboard export --id "$dashboard_id" --output-dir ./tmp
}

function find_exported_file() {
    find ./tmp -name "*.yaml" | head -n 1
}

function import_dashboard() {
    local file_path=$1
    echo "Importando dashboard de $file_path..."
    superset-cli dashboard import --path "$file_path"
}

function change_dashboard_title() {
    local file_path=$1
    local new_title=$2
    echo "Alterando o título do dashboard para '$new_title'..."
    python3 -c "
import yaml
import uuid

file_path = '$file_path'

with open(file_path, 'r') as f:
    data = yaml.safe_load(f)

data['dashboard_title'] = '$new_title'
data['uuid'] = str(uuid.uuid4())

# Remove o ID para forçar a criação de um novo
if 'id' in data:
    del data['id']

# Remove a referência ao dashboard original
if 'slug' in data:
    del data['slug']

with open(file_path, 'w') as f:
    yaml.dump(data, f)
"
}

# --- Lógica Principal ---

# 1. Defaults
UPDATE_DEPS=true
INTERACTIVE_MODE=true
POSITIONAL_ARGS=()

# 2. Argument Parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-update)
      UPDATE_DEPS=false
      shift
      ;;
    --no-interactive)
      INTERACTIVE_MODE=false
      shift
      ;;
    -*)
      # Ignorando flags desconhecidas para manter compatibilidade
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# --- Configuração do Ambiente Superset ---
: "${SUPERSET_DOMAIN:=http://localhost:8088}"
: "${SUPERSET_USER:=admin}"
: "${SUPERSET_PASSWORD:=admin}"
export SUPERSET_BASE_URL="$SUPERSET_DOMAIN"

# --- Execução ---

# 3. Control Flow: Decide o modo de execução
if [ "${#POSITIONAL_ARGS[@]}" -ge 2 ]; then
    # Modo Explícito: Clona um dashboard com base nos argumentos fornecidos
    check_deps
    login

    DASHBOARD_ID="${POSITIONAL_ARGS[0]}"
    NEW_DASHBOARD_NAME="${POSITIONAL_ARGS[1]}"

    echo "Clone do Dashboard (Modo Explícito)"
    echo "=================================="
    echo
    echo "Dashboard ID: $DASHBOARD_ID"
    echo "Novo Nome:    $NEW_DASHBOARD_NAME"
    echo "Superset URL: $SUPERSET_DOMAIN"
    echo

    export_dashboard "$DASHBOARD_ID"
    EXPORTED_FILE=$(find_exported_file)

    if [ ! -f "$EXPORTED_FILE" ]; then
        echo "Erro: Arquivo exportado não encontrado."
        exit 1
    fi

    echo "Arquivo exportado: $EXPORTED_FILE"

    change_dashboard_title "$EXPORTED_FILE" "$NEW_DASHBOARD_NAME"
    import_dashboard "$EXPORTED_FILE"

    echo
    echo "Dashboard clonado com sucesso!"
    echo "Novo dashboard '$NEW_DASHBOARD_NAME' criado."

elif [ "$INTERACTIVE_MODE" = false ]; then
    # Modo não interativo (em lote): Lógica de clonagem para roles
    check_deps
    login

    echo "Clone do Dashboard (Modo em Lote --no-interactive)"
    echo "=================================================="

    # ----- INÍCIO DA LÓGICA DE CLONAGEM EM LOTE -----
    # A lógica original para ler o .env e iterar sobre as roles
    # deve ser inserida aqui.
    echo "ERRO: A lógica de clonagem em lote (modo não interativo) não está implementada." >&2
    echo "Por favor, insira a lógica para ler o .env e clonar para as roles do Superset." >&2
    exit 1
    # ----- FIM DA LÓGICA DE CLONAGEM EM LOTE -----
else
    # Modo Interativo (sem argumentos e sem --no-interactive)
    # ou número insuficiente de argumentos posicionais.
    echo "USO:"
    echo "  Modo Explícito: $0 <ID_DO_DASHBOARD> <NOME_DO_NOVO_DASHBOARD> [--no-update] [--no-interactive]"
    echo "  Modo em Lote:   $0 --no-interactive [--no-update]"
    echo
    echo "ERRO: Argumentos insuficientes ou modo interativo não implementado." >&2
    exit 1
fi
