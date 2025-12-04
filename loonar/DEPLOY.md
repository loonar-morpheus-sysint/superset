# Deploy do Superset Loonar - Guia Completo

Este guia descreve como fazer o deploy do Superset Loonar em diferentes contextos: local ou remoto.

## 📋 Pré-requisitos

### Para todos os cenários:
- Docker e Docker Compose instalados
- Arquivo `.env` configurado (execute `./rotate-keys.sh` se necessário)

### Para deploy remoto via Docker Context:
- Docker Context remoto já configurado e testado
- Acesso ao servidor remoto via Docker API

### Para deploy remoto via SSH:
- Acesso SSH ao servidor remoto via chave SSH (sem senha)
- Docker e Docker Compose instalados no servidor remoto
- Permissões adequadas no servidor remoto

---

## 🚀 Deploy Rápido

### Passo único para todos os cenários:

```bash
cd loonar
./deploy.sh
```

O script interativo irá:
1. Validar o arquivo `.env`
2. Apresentar opções de deploy
3. Executar o setup apropriado baseado na sua escolha

---

## 📝 Cenários de Deploy

### 1️⃣ Deploy Local

**Quando usar:** Deploy na máquina atual para desenvolvimento ou testes.

**O que acontece:**
- Cria volumes localmente em `loonar/volumes/`
- Configura permissões necessárias
- Constrói imagens Docker
- Prepara ambiente para execução local

**Execução:**
```bash
./deploy.sh
# Selecione opção 1
```

**Após o setup:**
```bash
./up.sh          # Iniciar Superset
./down.sh        # Parar Superset
```

---

### 2️⃣ Deploy Remoto via Docker Context

**Quando usar:** Você tem um Docker Context configurado apontando para servidor remoto.

**Pré-requisitos:**
- Docker Context remoto configurado:
  ```bash
  docker context create remote --docker "host=ssh://user@servidor"
  docker context use remote
  docker ps  # Testar conexão
  ```

**O que acontece:**
- Muda para o contexto Docker remoto
- Cria diretórios no servidor remoto
- Envia arquivos necessários
- Constrói imagens no servidor remoto
- Restaura contexto original ao finalizar

**Execução:**
```bash
./deploy.sh
# Selecione opção 2
# Informe o nome do contexto Docker (ou use o atual)
# Informe o diretório no servidor remoto (ex: /opt/superset)
```

**Após o setup:**
```bash
# Mudar para contexto remoto
docker context use remote

# Iniciar serviços
cd /opt/superset  # (diretório informado)
docker compose --env-file=./loonar/.env -f docker-compose-loonar.yml up -d

# Ou voltar ao contexto local e usar comandos remotos
docker context use default
```

---

### 3️⃣ Deploy Remoto via SSH

**Quando usar:** Deploy direto no servidor via SSH, sem Docker Context configurado.

**Pré-requisitos:**
- Chave SSH configurada:
  ```bash
  ssh user@servidor  # Deve conectar sem pedir senha
  ```
- Docker instalado no servidor remoto

**O que acontece:**
- Valida conexão SSH
- Valida Docker no servidor remoto
- Cria tarball com arquivos do projeto
- Envia via SCP para servidor remoto
- Extrai arquivos no servidor
- Configura permissões
- Constrói imagens Docker no servidor
- Cria script de gerenciamento (`manage-superset.sh`)

**Execução:**
```bash
./deploy.sh
# Selecione opção 3
# Informe o host SSH (ex: user@servidor.com)
# Informe o diretório no servidor remoto (ex: /opt/superset)
```

**Após o setup - No servidor remoto:**

```bash
# Conectar ao servidor
ssh user@servidor

# Navegar para diretório
cd /opt/superset  # (diretório informado no deploy)

# Gerenciar Superset
./manage-superset.sh start    # Iniciar
./manage-superset.sh stop     # Parar
./manage-superset.sh restart  # Reiniciar
./manage-superset.sh status   # Ver status
./manage-superset.sh logs     # Ver logs
```

---

## 🔧 Configuração Avançada

### Variáveis de Ambiente Importantes

Edite `loonar/.env` conforme necessário:

```bash
# Host público do Superset
SUPERSET_HOST=seu-dominio.com

# Caminho dos volumes (para deploy remoto)
# Deixe vazio para local, defina caminho absoluto para remoto
SUPERSET_VOLUMES_PATH=/opt/superset/loonar/volumes

# Segredos (SEMPRE use valores fortes em produção!)
SUPERSET_SECRET_KEY=<gerado-por-rotate-keys.sh>
POSTGRES_PASSWORD=<gerado-por-rotate-keys.sh>
REDIS_PASSWORD=<gerado-por-rotate-keys.sh>
```

### Certificados SSL

Para produção, coloque certificados em:
```
loonar/ssl-certs/
  ├── fullchain.pem
  └── privkey.pem
```

Se não tiver certificados, o setup continuará mas sem HTTPS (não recomendado para produção).

---

## 📂 Estrutura de Diretórios

### Local:
```
superset/
├── loonar/
│   ├── deploy.sh              # ← Script principal
│   ├── setup-local.sh         # Setup local
│   ├── setup-remote-context.sh # Setup via Docker Context
│   ├── setup-remote-ssh.sh    # Setup via SSH
│   ├── up.sh                  # Iniciar local
│   ├── down.sh                # Parar local
│   ├── .env                   # Configurações
│   ├── volumes/               # Dados persistentes (local)
│   │   ├── db_home/
│   │   ├── redis/
│   │   ├── superset_home/
│   │   └── nginx_logs/
│   └── ssl-certs/             # Certificados SSL
└── docker-compose-loonar.yml
```

### Remoto (após deploy via SSH):
```
/opt/superset/                 # (ou diretório escolhido)
├── loonar/
│   ├── volumes/               # Dados persistentes (remoto)
│   ├── .env
│   └── ...
├── docker-compose-loonar.yml
├── docker/
└── manage-superset.sh         # ← Script de gerenciamento
```

---

## 🔍 Troubleshooting

### Erro: "Arquivo .env não encontrado"
```bash
cd loonar
./rotate-keys.sh  # Gera .env com segredos
```

### Erro: "Missing required variable"
```bash
# Edite loonar/.env e preencha as variáveis necessárias
vim loonar/.env
```

### Erro de permissão em volumes
```bash
# Local
sudo chown -R 999:999 loonar/volumes/{db_home,redis}

# Remoto (via SSH)
ssh user@servidor "sudo chown -R 999:999 /opt/superset/loonar/volumes/{db_home,redis}"
```

### Contexto Docker não encontrado
```bash
# Listar contextos
docker context ls

# Criar contexto remoto
docker context create remote --docker "host=ssh://user@servidor"

# Testar
docker context use remote
docker ps
```

### Erro ao conectar via SSH
```bash
# Testar conexão
ssh user@servidor

# Verificar chave SSH
ssh-add -l

# Adicionar chave se necessário
ssh-add ~/.ssh/id_rsa
```

---

## 🎯 Resumo dos Comandos

| Ação | Comando |
|------|---------|
| **Deploy inicial** | `./loonar/deploy.sh` |
| **Gerar segredos** | `./loonar/rotate-keys.sh` |
| **Iniciar (local)** | `./loonar/up.sh` |
| **Parar (local)** | `./loonar/down.sh` |
| **Iniciar (remoto SSH)** | `ssh user@srv "cd /opt/superset && ./manage-superset.sh start"` |
| **Ver logs (local)** | `docker logs -f superset_app` |
| **Ver logs (remoto)** | `./manage-superset.sh logs` |

---

## 📚 Recursos Adicionais

- [Documentação do Superset](https://superset.apache.org/)
- [Segurança do Superset](https://superset.apache.org/docs/security/)
- [Docker Context](https://docs.docker.com/engine/context/working-with-contexts/)

---

## ⚠️ Avisos de Segurança

1. **NUNCA** versione o arquivo `.env` com segredos reais
2. Use certificados SSL válidos em produção
3. Troque as senhas padrão do usuário admin
4. Configure firewall adequadamente no servidor remoto
5. Mantenha Docker e dependências atualizadas
6. Use `SUPERSET_SECRET_KEY` forte e único
7. Configure backup dos volumes regularmente
