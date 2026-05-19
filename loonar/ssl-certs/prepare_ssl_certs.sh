#!/bin/bash
# Script interativo para preparar certificados SSL para um host específico
# Uso: ./prepare_ssl_certs.sh

set -e

SRC_DIR="$(dirname "$0")/original"
DST_DIR="$(dirname "$0")"

# Listar arquivos disponíveis
clear
echo "Arquivos disponíveis em $SRC_DIR:"
ls -1 "$SRC_DIR"
echo

# Perguntar nome do host
echo -n "Digite o nome do host (ex: finops.sondahybrid.com): "
read HOST
if [[ -z "$HOST" ]]; then
  echo "Host não informado. Abortando."
  exit 1
fi

# Sugerir nomes padrão
CERT_FILE="$DST_DIR/cert.pem"
KEY_FILE="$DST_DIR/privkey.pem"
CHAIN_FILE="$DST_DIR/chain.pem"
FULLCHAIN_FILE="$DST_DIR/fullchain.pem"

# Perguntar se deseja customizar nomes
echo "\nNomes padrão sugeridos para os arquivos de saída:"
echo "  Certificado:     $CERT_FILE"
echo "  Chave privada:   $KEY_FILE"
echo "  Cadeia:         $CHAIN_FILE"
echo "  Fullchain:      $FULLCHAIN_FILE"
echo -n "Deseja customizar os nomes dos arquivos? (s/N): "
read CUSTOMIZE
if [[ "$CUSTOMIZE" =~ ^[sS]$ ]]; then
  echo -n "Nome do arquivo de certificado (.pem): "
  read CERT_FILE
  echo -n "Nome do arquivo de chave privada (.pem): "
  read KEY_FILE
  echo -n "Nome do arquivo de cadeia (.pem): "
  read CHAIN_FILE
  echo -n "Nome do arquivo fullchain (.pem): "
  read FULLCHAIN_FILE
fi

# Confirmar operações
echo "\nResumo das operações:"
echo "  Host:            $HOST"
echo "  Certificado:     $CERT_FILE"
echo "  Chave privada:   $KEY_FILE"
echo "  Cadeia:         $CHAIN_FILE"
echo "  Fullchain:      $FULLCHAIN_FILE"
echo -n "\nConfirma as operações acima? (S/n): "
read CONFIRM
if [[ "$CONFIRM" =~ ^[nN]$ ]]; then
  echo "Operação cancelada."
  exit 1
fi

# Copiar/renomear arquivos (ajuste conforme os nomes reais dos arquivos)
# Exemplo: supondo que os arquivos originais sejam:
#   - $SRC_DIR/$HOST.crt
#   - $SRC_DIR/$HOST.key
#   - $SRC_DIR/$HOST.ca-bundle
#
# Confirma cada operação

# Certificado
if [[ -f "$SRC_DIR/$HOST.crt" ]]; then
  echo -n "Copiar $SRC_DIR/$HOST.crt para $CERT_FILE? (S/n): "
  read OK
  if [[ ! "$OK" =~ ^[nN]$ ]]; then
    cp "$SRC_DIR/$HOST.crt" "$CERT_FILE"
    echo "OK."
  fi
else
  echo "Arquivo $SRC_DIR/$HOST.crt não encontrado. Pule para próxima etapa."
fi

# Chave privada
if [[ -f "$SRC_DIR/$HOST.key" ]]; then
  echo -n "Copiar $SRC_DIR/$HOST.key para $KEY_FILE? (S/n): "
  read OK
  if [[ ! "$OK" =~ ^[nN]$ ]]; then
    cp "$SRC_DIR/$HOST.key" "$KEY_FILE"
    echo "OK."
  fi
else
  echo "Arquivo $SRC_DIR/$HOST.key não encontrado. Pule para próxima etapa."
fi

# Cadeia
if [[ -f "$SRC_DIR/$HOST.ca-bundle" ]]; then
  echo -n "Copiar $SRC_DIR/$HOST.ca-bundle para $CHAIN_FILE? (S/n): "
  read OK
  if [[ ! "$OK" =~ ^[nN]$ ]]; then
    cp "$SRC_DIR/$HOST.ca-bundle" "$CHAIN_FILE"
    echo "OK."
  fi
else
  echo "Arquivo $SRC_DIR/$HOST.ca-bundle não encontrado. Pule para próxima etapa."
fi

# Fullchain (cert + chain)
if [[ -f "$SRC_DIR/$HOST.crt" && -f "$SRC_DIR/$HOST.ca-bundle" ]]; then
  echo -n "Gerar $FULLCHAIN_FILE concatenando $SRC_DIR/$HOST.crt e $SRC_DIR/$HOST.ca-bundle? (S/n): "
  read OK
  if [[ ! "$OK" =~ ^[nN]$ ]]; then
    cat "$SRC_DIR/$HOST.crt" "$SRC_DIR/$HOST.ca-bundle" > "$FULLCHAIN_FILE"
    echo "OK."
  fi
else
  echo "Não foi possível gerar o fullchain (faltam arquivos)."
fi

echo "\nProcesso concluído!"
