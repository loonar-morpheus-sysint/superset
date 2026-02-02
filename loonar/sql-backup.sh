#!/bin/bash

BACKUP_DIR=./backup
# Dia da semana em português (seg, ter, qua, qui, sex, sab, dom)
case $(date +%u) in
	1) DIA="seg";;
	2) DIA="ter";;
	3) DIA="qua";;
	4) DIA="qui";;
	5) DIA="sex";;
	6) DIA="sab";;
	7) DIA="dom";;
esac

ARQUIVO_BACKUP="$BACKUP_DIR/superset_db_${DIA}.sql.gz"


mkdir -p "$BACKUP_DIR"


echo "🔄 Iniciando backup completo para o dia: $DIA..."


# 1. Backup PostgreSQL (CRÍTICO)
echo "📊 Backup do banco de dados..."

# Faz o backup para um arquivo temporário
TMP_BACKUP="${ARQUIVO_BACKUP}.tmp"
if docker exec superset_db pg_dump -U superset superset | gzip > "$TMP_BACKUP"; then
	mv "$TMP_BACKUP" "$ARQUIVO_BACKUP"
	echo "📦 Backup completo finalizado: $ARQUIVO_BACKUP"
else
	echo "❌ Erro ao realizar o backup. O arquivo anterior foi preservado."
	rm -f "$TMP_BACKUP"
	exit 1
fi


