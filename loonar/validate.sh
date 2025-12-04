#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# =============================
# Script de Validação do Superset Loonar
# =============================
# Verifica se o ambiente está configurado corretamente
# e se o Superset está rodando
# =============================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Superset Loonar - Validação do Ambiente"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Função para checagem
check() {
    local name="$1"
    local command="$2"
    local error_level="${3:-error}"  # error ou warning

    if eval "$command" > /dev/null 2>&1; then
        echo "✅ $name"
        return 0
    else
        if [ "$error_level" = "error" ]; then
            echo "❌ $name"
            ((ERRORS++))
        else
            echo "⚠️  $name"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Verificações de pré-requisitos
echo "📋 Verificando pré-requisitos..."
check "Docker instalado" "command -v docker"
check "Docker Compose instalado" "command -v docker compose"
check "Docker daemon rodando" "docker info"
echo ""

# Verificações de estrutura
echo "📁 Verificando estrutura de diretórios..."
check "Diretório volumes/superset_home" "[ -d '$SCRIPT_DIR/volumes/superset_home' ]"
check "Diretório volumes/db_home" "[ -d '$SCRIPT_DIR/volumes/db_home' ]"
check "Diretório volumes/redis" "[ -d '$SCRIPT_DIR/volumes/redis' ]"
echo ""

# Verificações de permissões
echo "🔐 Verificando permissões..."
check "Permissões superset_home" "[ -r '$SCRIPT_DIR/volumes/superset_home' ] && [ -w '$SCRIPT_DIR/volumes/superset_home' ]"
# db_home pertence ao usuário postgres (999) no container, então só verificamos existência
check "Diretório db_home existe" "[ -d '$SCRIPT_DIR/volumes/db_home' ]"
check "Permissões redis" "[ -r '$SCRIPT_DIR/volumes/redis' ] && [ -w '$SCRIPT_DIR/volumes/redis' ]"
echo ""

# Verificações de configuração
echo "⚙️  Verificando arquivos de configuração..."
check "Arquivo .env" "[ -f '$SCRIPT_DIR/.env' ]"
check "Arquivo docker-compose-loonar.yml" "[ -f '$SCRIPT_DIR/docker-compose-loonar.yml' ]"
check "Arquivo nginx.conf" "[ -f '$PROJECT_ROOT/docker/nginx/nginx.conf' ]" "warning"
check "Arquivo superset.conf (nginx)" "[ -f '$PROJECT_ROOT/docker/nginx/conf.d/superset.conf' ]" "warning"
echo ""

# Verificações de containers (se estiverem rodando)
echo "🐳 Verificando containers Docker..."
if docker compose -f "$SCRIPT_DIR/docker-compose-loonar.yml" ps | grep -q "Up"; then
    check "Container superset_db rodando" "docker ps | grep -q superset_db"
    check "Container superset_cache rodando" "docker ps | grep -q superset_cache"
    check "Container superset_app rodando" "docker ps | grep -q superset_app"
    check "Container superset_nginx rodando" "docker ps | grep -q superset_nginx"

    echo ""
    echo "🏥 Verificando saúde dos serviços..."

    # Verificar se PostgreSQL está respondendo
    if docker exec superset_db pg_isready -U superset > /dev/null 2>&1; then
        echo "✅ PostgreSQL respondendo"
    else
        echo "❌ PostgreSQL não está respondendo"
        ((ERRORS++))
    fi

    # Verificar se Redis está respondendo
    if docker exec superset_cache redis-cli ping 2>/dev/null | grep -q PONG; then
        echo "✅ Redis respondendo"
    else
        echo "❌ Redis não está respondendo"
        ((ERRORS++))
    fi

    # Verificar se Superset está respondendo
    if curl -sf http://localhost/health > /dev/null 2>&1; then
        echo "✅ Superset respondendo em http://localhost"
    else
        echo "⚠️  Superset não está respondendo (pode estar inicializando)"
        ((WARNINGS++))
    fi

    echo ""
    echo "📊 Status dos containers:"
    docker compose -f "$SCRIPT_DIR/docker-compose-loonar.yml" ps
else
    echo "ℹ️  Nenhum container rodando"
    echo "   Execute: cd loonar && ./up.sh"
fi

echo ""
echo "=========================================="
echo "Resultado da Validação"
echo "=========================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ Tudo OK! Ambiente configurado corretamente."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Ambiente OK com $WARNINGS avisos"
    echo ""
    echo "Avisos não impedem o funcionamento, mas"
    echo "podem indicar configurações faltantes."
    exit 0
else
    echo "❌ Encontrados $ERRORS erros e $WARNINGS avisos"
    echo ""
    echo "Sugestões:"
    echo "1. Execute: cd loonar && ./setup.sh"
    echo "2. Verifique logs: docker logs superset_init"
    echo "3. Consulte: loonar/README.md"
    exit 1
fi
