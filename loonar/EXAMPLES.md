# Exemplos Práticos de Deploy

Este documento contém exemplos práticos e completos de cada modo de deploy.

## 🏠 Exemplo 1: Deploy Local para Desenvolvimento

```bash
# 1. Preparar ambiente
cd /home/devopsvanilla/_prj/loonar/loonar-morpheus-sysint/superset

# 2. Gerar segredos
cd loonar
./rotate-keys.sh

# Saída esperada:
# Backup do .env criado em env-backup-20251204...
# ✅ Novo .env gerado e variáveis rotacionadas em .../loonar/.env

# 3. Executar deploy
./deploy.sh

# Menu apresentado:
# ┌─ Selecione o modo de instalação:
# │
# │ 1 - Instalação LOCAL
# │   Deploy na máquina atual
# │
# │ 2 - Instalação REMOTA via Docker Context
# │   Usa contexto Docker remoto (requer contexto configurado)
# │
# │ 3 - Instalação REMOTA via SSH
# │   Copia arquivos e executa setup no servidor remoto
# │
# │ 0 - Cancelar
# └─
# Escolha uma opção [0-3]:

# Digite: 1

# Configuração:
#   Modo: Local
#   Diretório: /home/devopsvanilla/.../superset/loonar
# Confirma a instalação? [s/N]:

# Digite: s

# 4. Aguardar setup completar
# 🔧 Configurando Superset para instalação LOCAL...
# 📁 Criando diretórios de volumes...
# 🔒 Configurando permissões...
# 🏗️  Construindo imagens Docker...
# ✅ Setup local concluído!

# 5. Iniciar Superset
./up.sh

# 6. Acessar
# Abrir navegador em: http://finops-hom.sondahybrid.com
# Login: admin / admin

# 7. Gerenciar
./down.sh           # Parar
./up.sh             # Reiniciar
./down.sh -v        # Parar e limpar volumes
```

---

## 🌐 Exemplo 2: Deploy Remoto via Docker Context

```bash
# PRÉ-REQUISITO: Configurar Docker Context

# 1. Criar contexto Docker remoto
docker context create producao \
  --docker "host=ssh://admin@192.168.1.100"

# Testar conexão
docker context use producao
docker ps

# Saída esperada: lista de containers no servidor remoto (ou vazio)

# 2. Voltar ao contexto local para deploy
docker context use default

# 3. Preparar deploy local
cd /home/devopsvanilla/_prj/loonar/loonar-morpheus-sysint/superset/loonar

# 4. Executar deploy
./deploy.sh

# Digite: 2 (Instalação REMOTA via Docker Context)

# Digite o nome do contexto Docker remoto (ou Enter para atual): producao

# Digite o diretório no servidor remoto (ex: /opt/superset): /opt/superset

# Configuração:
#   Modo: Remoto via Docker Context
#   Contexto: producao
#   Diretório remoto: /opt/superset
# Confirma a instalação? [s/N]: s

# 5. Aguardar deploy completar
# 🌐 Configurando Superset para deploy REMOTO via Docker Context
#    Contexto: producao
#    Diretório remoto: /opt/superset
# 🔄 Mudando contexto Docker para: producao
# 📁 Criando diretórios no servidor remoto...
# 📦 Preparando arquivos para deploy...
# 📤 Enviando arquivos para servidor remoto...
# 🏗️  Construindo imagens no servidor remoto...
# ✅ Setup remoto via Docker Context concluído!

# 6. Iniciar serviços no servidor remoto
docker context use producao
cd /opt/superset
docker compose --env-file=./loonar/.env -f docker-compose-loonar.yml up -d

# 7. Verificar status
docker compose ps

# 8. Voltar ao contexto local
docker context use default
```

---

## 🔐 Exemplo 3: Deploy Remoto via SSH

```bash
# PRÉ-REQUISITO: SSH configurado com chave

# 1. Testar acesso SSH
ssh admin@servidor.exemplo.com

# Deve conectar sem pedir senha
# Se pedir senha, configure chave SSH:
# ssh-copy-id admin@servidor.exemplo.com

# 2. Preparar deploy local
cd /home/devopsvanilla/_prj/loonar/loonar-morpheus-sysint/superset/loonar

# 3. Executar deploy
./deploy.sh

# Digite: 3 (Instalação REMOTA via SSH)

# Digite o host SSH (ex: user@servidor.com): admin@servidor.exemplo.com

# → Testando conexão SSH com admin@servidor.exemplo.com...
# ✅ Conexão SSH OK

# Digite o diretório no servidor remoto (ex: /opt/superset): /opt/superset

# Configuração:
#   Modo: Remoto via SSH
#   SSH Host: admin@servidor.exemplo.com
#   Diretório remoto: /opt/superset
# Confirma a instalação? [s/N]: s

# 4. Aguardar deploy completar
# 🔐 Configurando Superset para deploy REMOTO via SSH
#    SSH Host: admin@servidor.exemplo.com
#    Diretório remoto: /opt/superset
# 🔍 Verificando requisitos no servidor remoto...
# ✅ Docker e Docker Compose disponíveis no servidor remoto
# 📁 Criando diretórios no servidor remoto...
# 📦 Preparando arquivos para envio...
# ✅ Arquivos empacotados (85M)
# 📤 Enviando arquivos para servidor remoto...
# 📂 Extraindo arquivos no servidor remoto...
# 🔒 Configurando permissões...
# 🏗️  Construindo imagens Docker no servidor remoto...
# 📝 Criando script de gerenciamento remoto...
# ✅ Setup remoto via SSH concluído!

# 5. Conectar ao servidor e iniciar
ssh admin@servidor.exemplo.com
cd /opt/superset
./manage-superset.sh start

# Saída:
# 🚀 Iniciando Superset...
# ⏳ Aguardando serviços...
# 🔧 Aplicando migrações...
# 👤 Criando usuário admin...
# 🔐 Inicializando...
# ✅ Superset iniciado!

# 6. Gerenciar remotamente (sem SSH interativo)
ssh admin@servidor.exemplo.com "/opt/superset/manage-superset.sh status"
ssh admin@servidor.exemplo.com "/opt/superset/manage-superset.sh logs"
ssh admin@servidor.exemplo.com "/opt/superset/manage-superset.sh restart"

# 7. Ou gerenciar via SSH interativo
ssh admin@servidor.exemplo.com
cd /opt/superset

./manage-superset.sh start    # Iniciar
./manage-superset.sh stop     # Parar
./manage-superset.sh restart  # Reiniciar
./manage-superset.sh status   # Ver status
./manage-superset.sh logs     # Ver todos os logs
./manage-superset.sh logs superset_app  # Logs específicos
```

---

## 🔄 Exemplo 4: Atualização de Deploy Existente

### Local:

```bash
cd loonar

# Parar serviços
./down.sh

# Atualizar código
git pull

# Rebuild se necessário
./build.sh

# Reiniciar
./up.sh
```

### Remoto via SSH:

```bash
# Conectar ao servidor
ssh admin@servidor.exemplo.com

# Navegar para diretório
cd /opt/superset

# Parar serviços
./manage-superset.sh stop

# Atualizar código
git pull

# Rebuild
docker compose --env-file=./loonar/.env -f docker-compose-loonar.yml build

# Reiniciar
./manage-superset.sh start
```

---

## 🐛 Exemplo 5: Troubleshooting

### Verificar logs local:

```bash
# Logs da aplicação
docker logs -f superset_app

# Logs do banco
docker logs -f superset_db

# Logs de todos os serviços
cd loonar
docker compose --env-file=./.env -f ../docker-compose-loonar.yml logs -f
```

### Verificar logs remoto (via SSH):

```bash
ssh admin@servidor.exemplo.com

cd /opt/superset

# Usando manage-superset.sh
./manage-superset.sh logs               # Todos
./manage-superset.sh logs superset_app  # Específico

# Ou diretamente
docker logs -f superset_app
```

### Resolver problemas de permissão:

```bash
# Local
sudo chown -R 999:999 loonar/volumes/db_home loonar/volumes/redis
sudo chmod 700 loonar/volumes/db_home loonar/volumes/redis

# Remoto
ssh admin@servidor.exemplo.com \
  "sudo chown -R 999:999 /opt/superset/loonar/volumes/{db_home,redis} && \
   sudo chmod 700 /opt/superset/loonar/volumes/{db_home,redis}"
```

---

## 📊 Exemplo 6: Backup e Restauração

### Backup local:

```bash
# Parar serviços
cd loonar
./down.sh

# Criar backup
tar czf superset-backup-$(date +%Y%m%d).tar.gz volumes/

# Reiniciar
./up.sh
```

### Backup remoto:

```bash
# Parar serviços no servidor
ssh admin@servidor.exemplo.com "/opt/superset/manage-superset.sh stop"

# Criar backup no servidor
ssh admin@servidor.exemplo.com \
  "cd /opt/superset && tar czf superset-backup-\$(date +%Y%m%d).tar.gz loonar/volumes/"

# Baixar backup
scp admin@servidor.exemplo.com:/opt/superset/superset-backup-*.tar.gz .

# Reiniciar serviços
ssh admin@servidor.exemplo.com "/opt/superset/manage-superset.sh start"
```

### Restauração:

```bash
# Local
cd loonar
./down.sh -v  # Parar e limpar volumes
tar xzf superset-backup-20251204.tar.gz
./up.sh

# Remoto
ssh admin@servidor.exemplo.com "/opt/superset/manage-superset.sh stop"
scp superset-backup-20251204.tar.gz admin@servidor.exemplo.com:/opt/superset/
ssh admin@servidor.exemplo.com \
  "cd /opt/superset && tar xzf superset-backup-20251204.tar.gz"
ssh admin@servidor.exemplo.com "/opt/superset/manage-superset.sh start"
```

---

## 🎓 Dicas Avançadas

### Usar variáveis de ambiente customizadas:

```bash
# Editar .env para produção
vim loonar/.env

# Adicionar configurações específicas
SUPERSET_VOLUMES_PATH=/data/superset/volumes  # Para contexto remoto
SUPERSET_LOG_LEVEL=WARNING                     # Menos verboso
```

### Monitorar recursos:

```bash
# Local
docker stats

# Remoto
ssh admin@servidor.exemplo.com "docker stats --no-stream"
```

### Limpar recursos antigos:

```bash
# Local
docker system prune -a

# Remoto
ssh admin@servidor.exemplo.com "docker system prune -af"
```
