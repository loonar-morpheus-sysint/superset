# 🚀 Sistema de Deploy do Superset Loonar

Sistema completo de deploy com suporte para instalação **local** ou **remota** (via Docker Context ou SSH).

## 📌 Início Rápido

```bash
cd loonar
./deploy.sh    # Script interativo com menu de opções
```

## 📚 Documentação

- **[QUICKSTART.md](QUICKSTART.md)** - Guia rápido com exemplos práticos
- **[DEPLOY.md](DEPLOY.md)** - Documentação completa e detalhada

## 🎯 Opções de Deploy

| Opção | Descrição | Quando Usar |
|-------|-----------|-------------|
| **1. Local** | Deploy na máquina atual | Desenvolvimento, testes |
| **2. Docker Context** | Deploy remoto via contexto Docker | Servidor com Docker Context configurado |
| **3. SSH** | Deploy remoto via SSH | Servidor acessível por SSH com chave |

## 📋 Scripts Disponíveis

### Scripts Principais
- **`deploy.sh`** - Script principal com menu interativo
- **`up.sh`** - Iniciar Superset (local)
- **`down.sh`** - Parar Superset (local)
- **`rotate-keys.sh`** - Gerar segredos para .env

### Scripts de Setup (chamados automaticamente)
- `setup-local.sh` - Configuração para deploy local
- `setup-remote-context.sh` - Configuração para Docker Context
- `setup-remote-ssh.sh` - Configuração para deploy via SSH

## ⚙️ Arquivos de Configuração

- **`.env`** - Configurações e segredos (não versionar!)
- **`.env-sample`** - Template de configurações
- **`docker-compose-loonar.yml`** - Definição dos serviços

## 🔐 Segurança

1. Gere segredos únicos: `./rotate-keys.sh`
2. Configure SSL em `ssl-certs/`
3. Troque senha do admin após primeiro acesso
4. Configure firewall adequadamente

## 📊 Estrutura de Volumes

```
volumes/
├── db_home/        # Banco de dados PostgreSQL
├── redis/          # Cache Redis
├── superset_home/  # Dados do Superset
└── nginx_logs/     # Logs do Nginx
```

## 🆘 Suporte

- Problemas comuns: Consulte [QUICKSTART.md](QUICKSTART.md#-resolução-de-problemas-comuns)
- Documentação completa: [DEPLOY.md](DEPLOY.md)
- Superset oficial: https://superset.apache.org/

---

**Versão:** 2.0 - Sistema de deploy unificado
