#!/bin/bash
BACKUP_DIR=./backup
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "🔄 Iniciando backup completo..."

# 1. Backup PostgreSQL (CRÍTICO)
echo "📊 Backup do banco de dados..."
docker exec superset_db pg_dump -U superset superset | gzip > $BACKUP_DIR/superset_db_$DATE.sql.gz

# # 2. Backup de configurações (CRÍTICO)
# echo "⚙️  Backup de configurações..."
# tar czf $BACKUP_DIR/config_$DATE.tar.gz \
#   loonar/.env \
#   loonar/.env-local \
#   loonar/ssl-certs/ \
#   docker-compose-loonar.yml \
#   Dockerfile-loonar

# # 3. Backup Superset Home (arquivos, se houver)
# echo "📁 Backup de arquivos do Superset..."
# docker run --rm \
#   -v loonar_superset_home_data:/source \
#   -v $(pwd)/backup:/backup \
#   ubuntu tar czf /backup/superset_home_$DATE.tar.gz -C /source .

# # 4. Verificar backups
# echo "✅ Backups criados:"
# ls -lh $BACKUP_DIR/*$DATE*

echo "📦 Backup completo finalizado: $DATE"
