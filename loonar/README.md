# Superset Loonar – Guia de Instalação

Este guia foi atualizado para o fluxo unificado baseado no script `loonar/up.sh`, que trata seleção de contexto Docker, persistência com volumes nomeados e execução do `docker compose` sem etapas adicionais.

---

## 📋 Pré-requisitos

- Docker Engine 20.10+ e Docker Compose v2
- Acesso ao repositório com os fontes do Superset Loonar
- Arquivo `loonar/.env` configurado (gere com `./loonar/rotate-keys.sh` se ainda não existir)
- Certificados válidos em `loonar/ssl-certs/` se desejar HTTPS

---

## 🚀 Instalação

### 1. Clonar repositório e criar `.env`

```bash
git clone <repository-url>
cd superset/loonar
./rotate-keys.sh   # cria/atualiza loonar/.env com segredos fortes
```

### 2. Executar `up.sh`

```bash
./up.sh
```

O script irá:

1. Validar se o Docker está acessível e se o `.env` existe.
2. Listar os contextos Docker configurados (`docker context ls`).
3. Permitir que você escolha o contexto alvo ou mantenha o atual.
4. Detectar se o `docker-compose-loonar.yml` define redes. Se não definir, perguntará qual rede utilizar ou criará uma nova.
5. Executar `docker compose --env-file loonar/.env -f docker-compose-loonar.yml up -d --build --remove-orphans` no contexto escolhido.

Todos os diretórios de dados (Superset, Postgres, Redis, logs do Nginx) agora são **volumes Docker nomeados** (`superset_home_data`, `db_data`, `redis_data`, `nginx_logs_data`). Assim não é necessário preparar pastas locais nem ajustar permissões manualmente.

### 3. Acompanhar a inicialização

```bash
docker compose \
  --env-file loonar/.env \
  -f docker-compose-loonar.yml logs -f superset_app
```

### 4. Acessar a interface

- URL base: `http://<SUPERSET_HOST>` (configure no `.env`)
- Usuário padrão: `admin`
- Senha padrão: `admin` (troque imediatamente após o primeiro login)

Para encerrar os serviços:

```bash
./down.sh            # para os containers
./down.sh -v         # remove também os volumes Docker nomeados
```

---

## 🧭 Cenários

| Cenário | Como proceder |
| --- | --- |
| Desenvolvimento local | Execute `./up.sh`, mantenha o contexto `default` e acesse via `http://localhost:8088`. |
| Servidor remoto (Docker Context) | Crie um contexto (`docker context create producao ...`) e escolha-o quando o script listar as opções. O build e os volumes serão criados diretamente no daemon remoto. |
| Execução direta no host remoto | Conecte-se via SSH, navegue até `superset/loonar` e execute `./up.sh` no próprio servidor. |

---

## 🐛 Troubleshooting

| Problema | Ação sugerida |
| --- | --- |
| `arquivo .env não encontrado` | Execute `./loonar/rotate-keys.sh`. |
| Contexto não listado | Verifique com `docker context ls` e crie/o atualize conforme necessário. |
| Portas 80/443 ocupadas | Edite `docker-compose-loonar.yml` no serviço `nginx` para ajustar o `ports`. |
| UI em branco + erros CSP para `https://superset/...` | Recrie o `nginx` com o template novo executando `./loonar/up.sh` (ou `docker compose --env-file loonar/.env -f docker-compose-loonar.yml restart nginx`). Valide com `curl -I https://$SUPERSET_HOST/static/appbuilder/css/flags/flags16.css` — o retorno deve ser 200 sem redirecionar; depois limpe o cache do navegador. |
| Reset completo dos dados | Rode `./down.sh -v` e depois `./up.sh` para recriar volumes limpos. |

---

## 🔐 Boas práticas

- Não versione `loonar/.env`.
- Gere segredos únicos sempre que mover para um novo ambiente (`rotate-keys.sh`).
- Configure certificados TLS válidos em produção.
- Restrinja o acesso aos contextos Docker remotos (SSH com chave, VPN, etc.).
- Altere a senha padrão do usuário `admin` assim que possível.

---

## 📚 Arquivos importantes

- `loonar/up.sh` – script interativo de deploy
- `loonar/down.sh` – encerra serviços
- `loonar/rotate-keys.sh` – gera segredos e `.env`
- `docker-compose-loonar.yml` – definição dos serviços e volumes nomeados
- `loonar/README-DEPLOY.md` / `loonar/QUICKSTART.md` – documentação adicional

---

## 📞 Suporte adicional

- Documentação oficial do Superset: <https://superset.apache.org/docs/>
- Guia completo de deploy: [`DEPLOY.md`](DEPLOY.md)# Superset Loonar - Guia de Instalação

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

### 2. Execute o Script de Deploy

O novo fluxo está concentrado em `loonar/up.sh`, que seleciona o contexto Docker, cria redes/volumes quando necessário e executa o `docker compose up`.

```bash
cd loonar
./up.sh
```

Os dados persistentes são criados automaticamente como **volumes Docker nomeados**, dispensando `sudo` e criação manual de diretórios.

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

### 4. Acompanhe a Inicialização

Use o próprio assistente do `up.sh` ou rode manualmente:

```bash
docker compose --env-file loonar/.env -f docker-compose-loonar.yml logs -f superset_app
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

### Logs e troubleshooting

- `docker compose --env-file loonar/.env -f docker-compose-loonar.yml ps`
- `docker compose --env-file loonar/.env -f docker-compose-loonar.yml logs -f superset_app`

Se precisar reiniciar ou limpar dados:

```bash
./loonar/down.sh        # Para os serviços
./loonar/down.sh -v     # Remove volumes Docker nomeados
./loonar/up.sh          # Recria tudo
```

Como os volumes são gerenciados pelo Docker, não é necessário remover diretórios manualmente. Use `docker volume ls` para inspecionar ou `docker volume rm <nome>` para limpeza manual.

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
