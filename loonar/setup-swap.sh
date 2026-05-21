#!/bin/bash

# Script para criar 4GB de memória Virtual (Swap) na VM
# Resolve problemas de OOM (Out Of Memory) durante o build do frontend no Docker.

set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ Por favor, rode este script com sudo: sudo ./setup-swap.sh"
  exit 1
fi

SWAP_FILE="/swapfile"
SWAP_SIZE="4G"

if grep -q "$SWAP_FILE" /proc/swaps; then
    echo "✅ O swap já está ativado no arquivo $SWAP_FILE."
    free -m
    exit 0
fi

echo "⏳ Criando arquivo de swap de $SWAP_SIZE em $SWAP_FILE..."
# Tenta com fallocate (rápido), se falhar usa dd
fallocate -l $SWAP_SIZE $SWAP_FILE || dd if=/dev/zero of=$SWAP_FILE bs=1M count=4096 status=progress

echo "🔒 Ajustando permissões..."
chmod 600 $SWAP_FILE

echo "⚙️ Formatando swap..."
mkswap $SWAP_FILE

echo "🚀 Ativando swap..."
swapon $SWAP_FILE

echo "💾 Adicionando ao /etc/fstab para persistir após reboot..."
if ! grep -q "^$SWAP_FILE" /etc/fstab; then
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
fi

echo "✅ Swap ativado com sucesso!"
free -m
