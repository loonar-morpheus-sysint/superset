#!/bin/bash
#
# Script legado de setup - redireciona para novo sistema de deploy
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "⚠️  Este script foi substituído pelo novo sistema de deploy"
echo ""
echo "Por favor, use: ./deploy.sh"
echo ""
echo "O novo script oferece:"
echo "  - Deploy local"
echo "  - Deploy remoto via Docker Context"
echo "  - Deploy remoto via SSH"
echo ""
echo "Executando deploy.sh..."
echo ""

exec "$SCRIPT_DIR/deploy.sh"
