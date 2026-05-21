#!/bin/bash
# Gera certificados SSL autoassinados para desenvolvimento do Superset
# Uso: bash generate-ssl-dev.sh
# Os arquivos gerados DEVEM ter exatamente estes nomes para funcionar com o docker-compose/nginx:
#   superset.crt  (certificado)
#   superset.key  (chave privada)
#   superset-ca.crt (CA confiável, opcional)
# Eles serão montados em /etc/nginx/certs dentro do container.
set -e

CERT_DIR="$(dirname "$0")"
CERT_KEY="$CERT_DIR/superset.key"
CERT_CRT="$CERT_DIR/superset.crt"
CERT_CA="$CERT_DIR/superset-ca.crt"

# Parâmetros customizáveis
DAYS=3650

# Caminho do .env (um nível acima do diretório do script)
ENV_FILE="$CERT_DIR/../.env"
if [ ! -f "$ENV_FILE" ]; then
	echo "Arquivo .env não encontrado em $ENV_FILE"
	exit 1
fi

# Extrai SUPERSET_HOST do .env
SUPERSET_HOST=$(grep '^SUPERSET_HOST=' "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | xargs)
if [ -z "$SUPERSET_HOST" ]; then
	echo "Variável SUPERSET_HOST não encontrada no .env"
	exit 1
fi

SUBJECT="/C=BR/ST=Dev/L=Dev/O=Superset Dev/OU=Dev/CN=$SUPERSET_HOST"

# Gera chave privada
openssl genrsa -out "$CERT_KEY" 4096

# Gera certificado autoassinado com SAN igual ao host
openssl req -x509 -new -nodes -key "$CERT_KEY" -sha256 -days $DAYS -out "$CERT_CRT" \
	-subj "$SUBJECT" \
	-addext "subjectAltName=DNS:$SUPERSET_HOST"

# Opcional: gera um CA intermediário para confiar no navegador (desenvolvimento)
openssl req -x509 -new -nodes -key "$CERT_KEY" -sha256 -days $DAYS -out "$CERT_CA" -subj "/C=BR/ST=Dev/L=Dev/O=Superset Dev CA/OU=Dev/CN=SupersetDevCA"

chmod 600 "$CERT_KEY"
chmod 644 "$CERT_CRT" "$CERT_CA"

echo "Certificados gerados em $CERT_DIR com nomes genéricos para fácil troca em produção:"
echo "- superset.key      (chave privada)"
echo "- superset.crt      (certificado)"
echo "- superset-ca.crt   (CA para confiar no navegador, opcional)"
echo ""
echo "Esses nomes permitem substituir facilmente por certificados reais no futuro."
echo "\nConfigure as variáveis de ambiente no nginx:\n  SSL_CERT=/etc/nginx/certs/superset.crt\n  SSL_KEY=/etc/nginx/certs/superset.key\n  SSL_TRUSTED=/etc/nginx/certs/superset-ca.crt\n"
echo "Para confiar no navegador, importe superset-ca.crt como Autoridade Certificadora (CA) confiável."
