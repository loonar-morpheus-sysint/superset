# Superset Loonar - Guia de Instalação

Este guia descreve como implantar o Apache Superset com configurações Loonar em um host novo, evitando problemas comuns de permissões.

## 📋 Pré-requisitos

- Docker Engine 20.10+
- Docker Compose 2.0+
- Acesso sudo no host
- Mínimo 4GB RAM disponível
- Mínimo 10GB espaço em disco

## 🚀 Instalação em Host Novo

### 1. Clone o Repositório

```bash
git clone <repository-url>
cd superset
```

### 2. Execute o Script de Setup

O script `loonar/setup.sh` irá:
- Criar estrutura de diretórios de volumes
- Configurar permissões adequadas
- Criar configurações nginx padrão
- Validar arquivos de configuração necessários

```bash
cd loonar
./setup.sh
```

**IMPORTANTE:** O script solicita `sudo` apenas para ajustar ownership dos volumes. Isso é necessário **UMA VEZ** na instalação inicial.

### 3. Configure Variáveis de Ambiente

Se ainda não existir, crie o arquivo de configuração:

```bash
cp docker/.env-non-dev docker/.env
```

Edite `docker/.env` e configure:

```bash
# Database
DATABASE_PASSWORD=<senha-forte-aqui>

# Redis
REDIS_PASSWORD=<senha-redis-aqui>

# Superset
SECRET_KEY=<gere-uma-chave-secreta-forte>
SUPERSET_LOAD_EXAMPLES=no

# Admin (altere após primeiro login)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin
```

**Gerar SECRET_KEY segura:**
```bash
openssl rand -base64 42
```

### 4. Inicie os Containers

```bash
cd ..  # volta para raiz do projeto
docker compose -f docker-compose-loonar.yml up -d
```

### 5. Acompanhe a Inicialização

```bash
# Ver logs da inicialização
docker logs -f superset_init

# Verificar status dos containers
docker ps -a
```

Aguarde a mensagem:
```
Init Step 3/3 [Complete] -- Setting up roles and perms
```

### 6. Acesse o Superset

Abra seu navegador em:
- **HTTP:** http://localhost
- **HTTPS:** https://localhost (se configurou certificados)

**Credenciais padrão:**
- Usuário: `admin`
- Senha: `admin` (ou a que configurou no `.env`)

⚠️ **ALTERE A SENHA após primeiro login!**

## 🔧 Resolução de Problemas

### Erro: Permission Denied em /app/superset_home

**Sintoma:**
```
PermissionError: [Errno 13] Permission denied: '/app/superset_home/sqllab'
```

**Solução:**
```bash
cd loonar
./setup.sh  # Re-executa configuração de permissões
```

### Erro: Database Connection Failed

**Sintoma:**
```
connection to server at "db" (172.18.0.2), port 5432 failed
```

**Possíveis causas:**

1. **Volumes com permissões incorretas:**
   ```bash
   docker compose -f docker-compose-loonar.yml down -v
   sudo rm -rf loonar/volumes/db_home/*
   cd loonar && ./setup.sh
   docker compose -f docker-compose-loonar.yml up -d
   ```

2. **Container PostgreSQL não inicializou:**
   ```bash
   docker logs superset_db
   ```

### Container superset_init fica reiniciando

**Verificar logs:**
```bash
docker logs superset_init --tail 100
```

**Reset completo:**
```bash
# Parar tudo
docker compose -f docker-compose-loonar.yml down -v

# Limpar volumes
sudo rm -rf loonar/volumes/db_home/*
sudo rm -rf loonar/volumes/redis/*
sudo rm -rf loonar/volumes/superset_home/*

# Re-setup
cd loonar && ./setup.sh

# Iniciar novamente
cd .. && docker compose -f docker-compose-loonar.yml up -d
```

## 📁 Estrutura de Volumes

```
loonar/volumes/
├── superset_home/     # Uploads, cache, configurações
├── db_home/          # Dados PostgreSQL
└── redis/            # Dados Redis/cache
```

**IMPORTANTE para Produção:**
- Configure backup periódico desses volumes
- Use volumes Docker nomeados ou storage externo
- Proteja dados sensíveis com criptografia

## 🔒 Checklist de Segurança para Produção

Antes de ir para produção, revise:

- [ ] `SECRET_KEY` única e forte (42+ caracteres)
- [ ] Senhas de banco e Redis fortes
- [ ] Alterar senha padrão do admin
- [ ] Configurar TLS/SSL no nginx
- [ ] Desabilitar `DEBUG` no `superset_config.py`
- [ ] Configurar CORS apropriadamente
- [ ] Restringir acesso a portas (usar apenas nginx)
- [ ] Configurar firewall do host
- [ ] Habilitar logs de auditoria
- [ ] Configurar backup automático dos volumes
- [ ] Usar usuário não-root nos containers (remover `user: "root"`)
- [ ] Revisar e atualizar dependências regularmente

Ver: https://superset.apache.org/docs/security/

## 🛠 Comandos Úteis

```bash
# Ver todos os containers
docker compose -f docker-compose-loonar.yml ps

# Parar tudo
docker compose -f docker-compose-loonar.yml down

# Reiniciar um serviço específico
docker compose -f docker-compose-loonar.yml restart superset_app

# Ver logs de um serviço
docker logs -f superset_app
docker logs -f superset_worker
docker logs -f superset_db

# Acessar shell de um container
docker exec -it superset_app bash

# Executar comando Superset
docker exec -it superset_app superset --help

# Criar novo admin
docker exec -it superset_app superset fab create-admin

# Backup do banco
docker exec superset_db pg_dump -U superset superset > backup-$(date +%Y%m%d).sql

# Restaurar banco
cat backup.sql | docker exec -i superset_db psql -U superset superset
```

## 📚 Arquivos de Configuração

### docker/.env
Variáveis de ambiente principais (senhas, URLs, etc.)

### docker/.env-local (opcional)
Overrides locais que não devem ser versionados

### docker/pythonpath_dev/superset_config.py
Configuração Python do Superset (cache, features, security, etc.)

### docker/nginx/
- `nginx.conf` - Configuração principal do nginx
- `conf.d/superset.conf` - Configuração de proxy reverso para Superset

## 🔄 Atualizações

Para atualizar o Superset:

```bash
# Backup primeiro!
docker exec superset_db pg_dump -U superset superset > backup-pre-update.sql

# Atualizar código
git pull origin main

# Rebuild containers
docker compose -f docker-compose-loonar.yml build --no-cache

# Aplicar migrations
docker compose -f docker-compose-loonar.yml up -d
docker logs -f superset_init  # Acompanhar migrações
```

## 📞 Suporte

Para problemas específicos do Loonar, consulte a equipe de desenvolvimento.

Para questões do Apache Superset:
- Documentação: https://superset.apache.org/docs/
- GitHub: https://github.com/apache/superset
- Slack: https://apache-superset.slack.com/
