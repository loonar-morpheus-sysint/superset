#!/usr/bin/bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to you under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# =============================
# Script de Teste - Integração LDAP/Active Directory com Superset
# =============================
# Este script valida a configuração LDAP de duas formas:
# 1. Via ldapsearch (testa conectividade e busca de usuários/grupos)
# 2. Via API REST do Superset (testa autenticação real)

# =============================
# CORES PARA OUTPUT
# =============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================
# FUNÇÕES AUXILIARES
# =============================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

separator() {
    echo -e "\n${BLUE}========================================${NC}\n"
}

# =============================
# CARREGAR VARIÁVEIS DE AMBIENTE
# =============================

load_env() {
    # Procurar .env-prod primeiro, depois .env
    local env_file=""

    if [ -f "loonar/.env-prod" ]; then
        env_file="loonar/.env-prod"
    elif [ -f "loonar/.env" ]; then
        env_file="loonar/.env"
    else
        log_error "Arquivo de configuração não encontrado (.env ou .env-prod)"
        exit 1
    fi

    # Carregar variáveis do arquivo .env com proteção contra caracteres especiais
    set -a
    source "$env_file" 2>/dev/null || true
    set +a

    log_success "Variáveis carregadas de $env_file"

    # Validar variáveis obrigatórias
    if [ -z "$LOONAR_LDAP_MODE" ]; then
        log_error "LOONAR_LDAP_MODE não está definido"
        exit 1
    fi

    if [ "$LOONAR_LDAP_MODE" = "real" ]; then
        LDAP_SERVER="$LOONAR_LDAP_SERVER_REAL"
        LDAP_BIND_DN="$LOONAR_LDAP_BIND_DN_REAL"
        LDAP_BIND_PASSWORD="$LOONAR_LDAP_BIND_PASSWORD_REAL"
        LDAP_USER_BASE="$LOONAR_LDAP_USER_BASE_REAL"
        LDAP_GROUP_BASE="$LOONAR_LDAP_GROUP_BASE_REAL"
    else
        LDAP_SERVER="$LOONAR_LDAP_SERVER_MOCK_INTERNAL"
        LDAP_BIND_DN="$LOONAR_LDAP_BIND_DN_MOCK"
        LDAP_BIND_PASSWORD="$LOONAR_LDAP_BIND_PASSWORD_MOCK"
        LDAP_USER_BASE="${LOONAR_LDAP_USER_BASE_REAL:-OU=04-CLIENTES,DC=loonardc,DC=local}"
        LDAP_GROUP_BASE="${LOONAR_LDAP_GROUP_BASE_REAL:-OU=04-CLIENTES,DC=loonardc,DC=local}"
    fi
}

# =============================
# 1. TESTE DE CONECTIVIDADE LDAP (ldapsearch)
# =============================

test_ldap_connection() {
    separator
    log_info "Testando conectividade LDAP com ldapsearch..."

    if ! command -v ldapsearch &> /dev/null; then
        log_warning "ldapsearch não está instalado. Execute: sudo apt-get install ldap-utils"
        return 1
    fi

    # Extrair servidor e porta
    LDAP_HOST=$(echo "$LDAP_SERVER" | sed 's|ldap://||' | cut -d: -f1)
    LDAP_PORT=$(echo "$LDAP_SERVER" | sed 's|ldap://||' | cut -d: -f2)
    LDAP_PORT=${LDAP_PORT:-389}

    log_info "Servidor: $LDAP_HOST"
    log_info "Porta: $LDAP_PORT"
    log_info "Bind DN: $LDAP_BIND_DN"

    # Teste de bind
    if ldapsearch -x \
        -H "$LDAP_SERVER" \
        -D "$LDAP_BIND_DN" \
        -w "$LDAP_BIND_PASSWORD" \
        -b "$LDAP_USER_BASE" \
        "(objectClass=user)" \
        sAMAccountName \
        givenName \
        sn \
        mail 2>/dev/null | grep -q "numResponses"; then
        log_success "Conexão LDAP bem-sucedida"
        return 0
    else
        log_error "Falha na conexão LDAP"
        return 1
    fi
}

# =============================
# 2. TESTE DE BUSCA DE USUÁRIOS
# =============================

test_ldap_search_users() {
    separator
    log_info "Testando busca de usuários no LDAP..."

    ldapsearch -x \
        -H "$LDAP_SERVER" \
        -D "$LDAP_BIND_DN" \
        -w "$LDAP_BIND_PASSWORD" \
        -b "$LDAP_USER_BASE" \
        "(objectClass=user)" \
        | head -50
}

# =============================
# 3. TESTE DE BUSCA DE GRUPOS
# =============================

test_ldap_search_groups() {
    separator
    log_info "Testando busca de grupos Superset no LDAP..."

    local groups_output
    groups_output=$(ldapsearch -x \
        -H "$LDAP_SERVER" \
        -D "$LDAP_BIND_DN" \
        -w "$LDAP_BIND_PASSWORD" \
        -b "$LDAP_GROUP_BASE" \
        "(cn=superset_*)" \
        cn \
        member 2>/dev/null)

    if echo "$groups_output" | grep -q "superset_"; then
        log_success "Grupos Superset encontrados:"
        echo "$groups_output" | grep "^cn: superset_"
    else
        log_warning "Nenhum grupo com prefixo 'superset_' encontrado"
        log_info "Procurando todos os grupos (cn=*)..."
        ldapsearch -x \
            -H "$LDAP_SERVER" \
            -D "$LDAP_BIND_DN" \
            -w "$LDAP_BIND_PASSWORD" \
            -b "$LDAP_GROUP_BASE" \
            "(objectClass=group)" \
            cn \
            2>/dev/null | grep "^cn:" | head -20
    fi
}

# =============================
# 4. TESTE DE CONFIGURAÇÃO DO SUPERSET
# =============================

test_superset_config() {
    separator
    log_info "Verificando configuração do Superset..."

    # Variáveis obrigatórias
    if [ "$SUPERSET_LOGIN_FORM_TYPE" != "ldap" ]; then
        log_error "SUPERSET_LOGIN_FORM_TYPE deve ser 'ldap', encontrado: $SUPERSET_LOGIN_FORM_TYPE"
        return 1
    fi
    log_success "SUPERSET_LOGIN_FORM_TYPE = ldap"

    log_success "LOONAR_LDAP_MODE = $LOONAR_LDAP_MODE"
    log_success "Servidor LDAP = $LDAP_SERVER"
    log_success "Base de usuários = $LDAP_USER_BASE"
    log_success "Base de grupos = $LDAP_GROUP_BASE"

    return 0
}

# =============================
# 5. TESTE VIA API REST DO SUPERSET
# =============================

test_superset_login_api() {
    separator
    log_info "Testando autenticação via API REST do Superset..."

    # Verificar se Superset está rodando
    if ! curl -s http://localhost:8088/health > /dev/null 2>&1; then
        log_error "Superset não está acessível em http://localhost:8088"
        log_info "Verifique se os containers estão rodando:"
        log_info "  docker-compose -f docker-compose-loonar.yml ps"
        return 1
    fi
    log_success "Superset está acessível"

    # Pedir credenciais para teste
    read -p "Digite o usuário LDAP para teste: " TEST_USER
    read -sp "Digite a senha: " TEST_PASSWORD
    echo ""

    # Tentar fazer login via API
    LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8088/api/v1/security/login \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"$TEST_USER\",
            \"password\": \"$TEST_PASSWORD\",
            \"provider\": \"db\"
        }")

    if echo "$LOGIN_RESPONSE" | grep -q '"access_token"'; then
        log_success "Login bem-sucedido via LDAP!"
        echo "$LOGIN_RESPONSE" | jq . 2>/dev/null || echo "$LOGIN_RESPONSE"

        # Extrair token
        ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.access_token' 2>/dev/null)

        # Verificar informações do usuário
        separator
        log_info "Obtendo informações do usuário autenticado..."
        curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
            http://localhost:8088/api/v1/security/me | jq .

    else
        log_error "Falha ao fazer login"
        echo "$LOGIN_RESPONSE" | jq . 2>/dev/null || echo "$LOGIN_RESPONSE"
        return 1
    fi
}

# =============================
# 6. VERIFICAR LOGS DO SUPERSET
# =============================

test_superset_logs() {
    separator
    log_info "Verificando logs do Superset para erros LDAP..."

    if command -v docker-compose &> /dev/null; then
        log_info "Últimos logs de autenticação:"
        docker-compose -f docker-compose-loonar.yml logs superset_app 2>/dev/null | \
            grep -i "ldap\|auth\|security" | tail -20
    else
        log_warning "docker-compose não encontrado"
    fi
}

# =============================
# 7. TESTE DE MAPEAMENTO DE GRUPOS
# =============================

test_ldap_group_mapping() {
    separator
    log_info "Testando mapeamento de grupos LDAP para roles Superset..."

    # Roles esperadas
    ROLES=("superset_Admin" "superset_Alpha" "superset_Gamma" "superset_sql_lab")

    for ROLE in "${ROLES[@]}"; do
        ROLE_FOUND=$(ldapsearch -x \
            -H "$LDAP_SERVER" \
            -D "$LDAP_BIND_DN" \
            -w "$LDAP_BIND_PASSWORD" \
            -b "$LDAP_GROUP_BASE" \
            "(cn=$ROLE)" \
            cn 2>/dev/null | grep -c "^cn: $ROLE" || echo "0")

        if [ "$ROLE_FOUND" -gt 0 ]; then
            log_success "Grupo encontrado: $ROLE"
        else
            log_warning "Grupo não encontrado: $ROLE"
        fi
    done
}

# =============================
# MENU PRINCIPAL
# =============================

show_menu() {
    separator
    echo "Testes de Integração LDAP/Active Directory"
    echo ""
    echo "1) Testar conectividade LDAP (ldapsearch)"
    echo "2) Buscar usuários no LDAP"
    echo "3) Buscar grupos Superset no LDAP"
    echo "4) Verificar configuração do Superset"
    echo "5) Testar autenticação via API REST"
    echo "6) Verificar logs do Superset"
    echo "7) Testar mapeamento de grupos"
    echo "8) Executar todos os testes"
    echo "9) Sair"
    echo ""
}

# =============================
# EXECUTAR TESTES
# =============================

run_all_tests() {
    log_info "Executando todos os testes..."

    test_superset_config || return 1
    test_ldap_connection || return 1
    test_ldap_search_users
    test_ldap_search_groups
    test_ldap_group_mapping
    test_superset_logs
    test_superset_login_api
}

# =============================
# MAIN
# =============================

main() {
    load_env

    if [ $# -eq 0 ]; then
        # Menu interativo
        while true; do
            show_menu
            read -p "Escolha uma opção (1-9): " choice

            case $choice in
                1) test_ldap_connection ;;
                2) test_ldap_search_users ;;
                3) test_ldap_search_groups ;;
                4) test_superset_config ;;
                5) test_superset_login_api ;;
                6) test_superset_logs ;;
                7) test_ldap_group_mapping ;;
                8) run_all_tests ;;
                9) log_info "Saindo..."; exit 0 ;;
                *) log_error "Opção inválida" ;;
            esac

            read -p "Pressione ENTER para continuar..."
        done
    else
        # Modo não-interativo
        case $1 in
            all) run_all_tests ;;
            connection) test_ldap_connection ;;
            users) test_ldap_search_users ;;
            groups) test_ldap_search_groups ;;
            config) test_superset_config ;;
            login) test_superset_login_api ;;
            logs) test_superset_logs ;;
            mapping) test_ldap_group_mapping ;;
            *)
                echo "Uso: $0 [all|connection|users|groups|config|login|logs|mapping]"
                exit 1
                ;;
        esac
    fi
}

# Executar main
main "$@"
