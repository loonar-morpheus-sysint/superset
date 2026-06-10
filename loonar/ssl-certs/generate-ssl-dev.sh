#!/bin/bash
# Script para gerar CA e certificado SSL assinado por ela
# Uso: bash generate-ssl-dev.sh
# Gera:
#   superset-ca.key  (chave privada da CA)
#   superset-ca.crt  (certificado raiz da CA)
#   superset.key     (chave privada do servidor)
#   superset.crt     (certificado do servidor assinado pela CA)

set -e

CERT_DIR="$(dirname "$0")"
CERT_CA_KEY="$CERT_DIR/superset-ca.key"
CERT_CA_CRT="$CERT_DIR/superset-ca.crt"
CERT_KEY="$CERT_DIR/superset.key"
CERT_CSR="$CERT_DIR/superset.csr"
CERT_CRT="$CERT_DIR/superset.crt"

DAYS=3650

# Caminho do .env (um nível acima do diretório do script)
ENV_FILE="$CERT_DIR/../.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Arquivo .env não encontrado em $ENV_FILE"
    exit 1
fi

SUPERSET_HOST=$(grep '^SUPERSET_HOST=' "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | xargs)
if [ -z "$SUPERSET_HOST" ]; then
    echo "Variável SUPERSET_HOST não encontrada no .env"
    exit 1
fi

# 1. Gera chave e certificado da CA
openssl genrsa -out "$CERT_CA_KEY" 4096
openssl req -x509 -new -nodes -key "$CERT_CA_KEY" -sha256 -days $DAYS \
    -out "$CERT_CA_CRT" \
    -subj "/C=BR/ST=Dev/L=Dev/O=Superset Dev CA/OU=Dev/CN=SupersetDevCA"

# 2. Gera chave privada do servidor
openssl genrsa -out "$CERT_KEY" 4096

# 3. Gera CSR para o servidor
openssl req -new -key "$CERT_KEY" -out "$CERT_CSR" \
    -subj "/C=BR/ST=Dev/L=Dev/O=Superset Dev/OU=Dev/CN=$SUPERSET_HOST"

# 4. Assina o CSR com a CA
openssl x509 -req -in "$CERT_CSR" -CA "$CERT_CA_CRT" -CAkey "$CERT_CA_KEY" \
    -CAcreateserial -out "$CERT_CRT" -days $DAYS -sha256 \
    -extfile <(printf "subjectAltName=DNS:$SUPERSET_HOST")

chmod 600 "$CERT_CA_KEY" "$CERT_KEY"
chmod 644 "$CERT_CA_CRT" "$CERT_CRT"

echo "Certificados gerados em $CERT_DIR:"
echo "- superset-ca.key   (chave privada da CA)"
echo "- superset-ca.crt   (certificado raiz da CA)"
echo "- superset.key      (chave privada do servidor)"
echo "- superset.crt      (certificado do servidor assinado pela CA)"
echo ""
