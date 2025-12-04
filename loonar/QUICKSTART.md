# 🚀 Guia Rápido - Deploy do Superset Loonar

## ⚡ Início Rápido (3 passos)

```bash
# 1. Gerar segredos (primeira vez)
cd loonar
./rotate-keys.sh

# 2. Executar deploy
./deploy.sh

# 3. Escolher opção no menu:
#    1 - Local (para testes/dev na máquina atual)
#    2 - Remoto via Docker Context (precisa ter contexto configurado)
#    3 - Remoto via SSH (deploy direto no servidor)
```

---

## 📋 Cenários Práticos

### Cenário 1: Desenvolvimento Local
```bash
cd loonar
./deploy.sh
# Escolher opção 1
# Confirmar com 's'

# Aguardar setup completar...

# Iniciar Superset
./up.sh

# Acessar em: http://localhost:8088 ou http://finops-hom.sondahybrid.com
# Login: admin / admin
```

### Cenário 2: Servidor Remoto (com Docker Context)
```bash
# Pré-requisito: Criar contexto Docker
docker context create producao --docker "host=ssh://user@servidor.com"
docker context use producao
docker ps  # Testar

# Deploy
cd loonar
./deploy.sh
# Escolher opção 2
# Informar contexto: producao
# Informar diretório: /opt/superset
# Confirmar com 's'

# Aguardar setup completar...

# Iniciar serviços
docker context use producao
cd /opt/superset
docker compose --env-file=./loonar/.env -f docker-compose-loonar.yml up -d
```

### Cenário 3: Servidor Remoto (via SSH)
```bash
# Pré-requisito: SSH configurado
ssh user@servidor.com  # Deve conectar sem senha

# Deploy
cd loonar
./deploy.sh
# Escolher opção 3
# Informar host: user@servidor.com
# Informar diretório: /opt/superset
# Confirmar com 's'

# Aguardar setup completar...

# Conectar ao servidor e iniciar
ssh user@servidor.com
cd /opt/superset
./manage-superset.sh start

# Ou remotamente:
ssh user@servidor.com "/opt/superset/manage-superset.sh start"
```

---

## 🔧 Comandos de Gerenciamento

### Local:
```bash
./loonar/up.sh              # Iniciar
./loonar/down.sh            # Parar
./loonar/down.sh -v         # Parar e remover volumes
docker logs -f superset_app # Ver logs
```

### Remoto (via manage-superset.sh):
```bash
./manage-superset.sh start    # Iniciar
./manage-superset.sh stop     # Parar
./manage-superset.sh restart  # Reiniciar
./manage-superset.sh status   # Status
./manage-superset.sh logs     # Ver logs
./manage-superset.sh logs superset_app  # Logs de serviço específico
```

---

## 🐛 Resolução de Problemas Comuns

### Erro: "Arquivo .env não encontrado"
```bash
cd loonar
./rotate-keys.sh
```

### Erro: "Missing required variable"
```bash
# Verificar quais variáveis estão faltando
cat loonar/.env | grep -E "(SUPERSET_SECRET_KEY|POSTGRES_PASSWORD|REDIS_PASSWORD|SUPERSET_HOST)"

# Se alguma estiver vazia, gerar novamente
./loonar/rotate-keys.sh
```

### Erro de permissão nos volumes
```bash
# Local
sudo chown -R 999:999 loonar/volumes/db_home loonar/volumes/redis
sudo chmod 700 loonar/volumes/db_home loonar/volumes/redis

# Remoto
ssh user@servidor "sudo chown -R 999:999 /opt/superset/loonar/volumes/{db_home,redis}"
```

---

## 📊 Estrutura de Arquivos

```
loonar/
├── deploy.sh                    # ← SCRIPT PRINCIPAL
├── setup-local.sh               # Setup para instalação local
├── setup-remote-context.sh      # Setup para Docker Context remoto
├── setup-remote-ssh.sh          # Setup para SSH remoto
├── up.sh                        # Iniciar local
├── down.sh                      # Parar local
├── rotate-keys.sh               # Gerar segredos
├── .env                         # Configurações (NÃO versionar!)
├── DEPLOY.md                    # Documentação completa
└── volumes/                     # Dados persistentes
```

---

## 🔐 Segurança - Checklist

- [ ] Executou `./rotate-keys.sh` para gerar segredos únicos
- [ ] Verificou que `.env` **NÃO** está versionado no git
- [ ] Configurou certificados SSL em `loonar/ssl-certs/`
- [ ] Trocou senha padrão do admin após primeiro login
- [ ] Configurou firewall no servidor remoto

---

**Dúvidas?** Consulte [DEPLOY.md](DEPLOY.md) para documentação completa.


---

## ✅ Validação

```bash
# Verificar se tudo está OK
cd loonar
./validate.sh
```

---

## 📝 Por que o setup.sh é necessário?

O script `setup.sh`:
1. Cria estrutura de diretórios para volumes Docker
2. **Ajusta permissões** para evitar erros "Permission Denied"
3. Cria configurações nginx padrão
4. Valida arquivos de configuração

**Você precisa executá-lo apenas UMA VEZ por host.**

---

## 🔄 Comandos Úteis

```bash
# Ver status
docker ps

# Ver logs
docker logs -f superset_app
docker logs superset_init

# Parar (mantém dados)
./down.sh

# Parar e remover volumes
./down.sh -v

# Limpar tudo completamente
./down.sh -c

# Validar ambiente
./validate.sh
```

---

## 🆘 Problemas Comuns

### Erro: "Permission denied: '/app/superset_home/sqllab'"

**Solução:**
```bash
cd loonar
./setup.sh  # Re-executa configuração
./up.sh
```

### Container reiniciando infinitamente

**Solução:**
```bash
# Ver o erro
docker logs superset_init

# Reset completo
./down.sh -c
./setup.sh
./up.sh
```

### Porta 80 já em uso

**Solução:**
```bash
# Edite docker-compose-loonar.yml e mude as portas:
ports:
  - 8080:80      # Acesse em http://localhost:8080
  - 8443:443
```

---

## 📚 Documentação Completa

Para mais detalhes, consulte: **`loonar/README.md`**
