# 🚀 Sistema de Deploy do Superset Loonar

Sistema completo de deploy com suporte para instalação **local** ou **remota** (via Docker Context ou SSH).

## 📌 Início Rápido

```bash
cd loonar
./up.sh    # Script interativo com seleção de contexto e redes
```

## 📚 Documentação

- **[QUICKSTART.md](QUICKSTART.md)** - Guia rápido com exemplos práticos
- **[DEPLOY.md](DEPLOY.md)** - Documentação completa e detalhada

## 📋 Scripts Disponíveis

### Scripts Principais
- **`up.sh`** - Script único de deploy (seleciona contexto, redes e executa o compose)
- **`deploy.sh`** - Alias legado que apenas encaminha para `up.sh`
- **`down.sh`** - Parar Superset (local)
- **`rotate-keys.sh`** - Gerar segredos para .env

### Scripts de Setup (legados)
- `setup-local.sh` e `setup-remote-ssh.sh` continuam disponíveis para cenários avançados, mas o fluxo padrão agora é `up.sh`

## ⚙️ Arquivos de Configuração

- **`.env`** - Configurações e segredos (não versionar!)
- **`.env-sample`** - Template de configurações
- **`docker-compose-loonar.yml`** - Definição dos serviços

## 🔐 Segurança

1. Gere segredos únicos: `./rotate-keys.sh`
2. Configure SSL em `ssl-certs/`
3. Troque senha do admin após primeiro acesso
4. Configure firewall adequadamente

## 📊 Persistência

Os dados persistentes agora usam **volumes gerenciados pelo Docker**, eliminando a necessidade de criar diretórios locais ou remotos manualmente. Basta executar `./up.sh` que o Docker cuidará da criação e do ciclo de vida dos volumes.

## 🆘 Suporte

- Problemas comuns: Consulte [QUICKSTART.md](QUICKSTART.md#-resolução-de-problemas-comuns)
- Documentação completa: [DEPLOY.md](DEPLOY.md)
- Superset oficial: https://superset.apache.org/
