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

## 🧠 Requisito do Host

O Redis (`superset_cache`) exige que o host Linux esteja com `vm.overcommit_memory=1`. Esse ajuste **não** pode ser feito pelo `docker-compose`, pois é um parâmetro global do kernel. Antes de executar `./up.sh`, valide com:

```bash
sysctl vm.overcommit_memory
```

Se o valor não for `1`, execute:

- Aplicar imediatamente: `sudo sysctl -w vm.overcommit_memory=1`
- Tornar permanente: adicione `vm.overcommit_memory = 1` em `/etc/sysctl.conf` e rode `sudo sysctl -p`

Repita o procedimento em todos os hosts (locais ou remotos) onde o stack do Superset for executado.

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
