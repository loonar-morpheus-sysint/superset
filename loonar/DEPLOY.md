# Deploy do Superset Loonar - Guia Completo

Este guia descreve como fazer o deploy do Superset Loonar em diferentes contextos: local ou remoto.

## 📋 Pré-requisitos

### Para todos os cenários

- Docker e Docker Compose instalados
- Arquivo `.env` configurado (execute `./rotate-keys.sh` se necessário)
- Host Linux com `vm.overcommit_memory=1` (obrigatório para o Redis `superset_cache`)

### Para deploy remoto via Docker Context

- Docker Context remoto já configurado e testado
- Acesso ao servidor remoto via Docker API

### Para deploy remoto via SSH

- Acesso SSH ao servidor remoto via chave SSH (sem senha)
- Docker e Docker Compose instalados no servidor remoto
- Permissões adequadas no servidor remoto

---

## 🚀 Deploy Rápido

### Passos rápidos

```bash
cd loonar
./rotate-keys.sh   # primeira vez
./up.sh            # seleciona o contexto Docker e executa o compose
```

O script interativo irá:

1. Validar o arquivo `.env`
2. Apresentar opções de deploy
3. Executar o setup apropriado baseado na sua escolha

---

## 📝 Cenários de Deploy

### 1️⃣ Desenvolvimento local

- Execute `./loonar/up.sh` e mantenha o contexto atual (normalmente `default`).
- O script construirá as imagens, criará os volumes Docker e exibirá o status final.
- Use `./loonar/down.sh` para parar os serviços quando necessário.

### 2️⃣ Deploy remoto via Docker Context

1. Crie o contexto uma única vez:

   ```bash
   docker context create producao --docker "host=ssh://user@servidor.com"
   ```

2. Execute `./loonar/up.sh` na sua máquina e escolha o contexto `producao` na lista.
3. O script usará o daemon remoto e os volumes serão criados automaticamente nesse host.

### 3️⃣ Execução direta no servidor (SSH)

1. Clone o repositório e gere o `.env` no servidor remoto.
2. Acesse o host via SSH e execute `./loonar/up.sh` diretamente nele.
3. Essa abordagem continua compatível com `setup-remote-ssh.sh`, mas o fluxo padrão é o mesmo script.

Em todos os cenários os dados persistentes ficam em volumes Docker nomeados, portanto não é necessário preparar diretórios como `loonar/volumes` manualmente.

---

## 🔧 Configuração Avançada

### Ajuste obrigatório do kernel (Redis)

O serviço `superset_cache` (Redis) precisa que o kernel do host esteja com `vm.overcommit_memory=1`. Como esse parâmetro **não é namespaced**, o Docker ou o `docker-compose` não conseguem defini-lo automaticamente dentro do container.

1. Verifique o valor atual:

  ```bash
  sysctl vm.overcommit_memory
  ```

2. Caso não seja `1`, ajuste no host que executa o Superset:

  - **Aplicação imediata:** `sudo sysctl -w vm.overcommit_memory=1`
  - **Persistência após reboot:** adicione `vm.overcommit_memory = 1` em `/etc/sysctl.conf` e aplique com `sudo sysctl -p`

3. Para ambientes com múltiplos hosts (por exemplo, Docker Context remoto ou SSH), repita o processo em cada nó antes de rodar `./up.sh`.

Depois da alteração reinicie apenas o serviço Redis (`docker compose restart superset_cache`) ou toda a stack para que o aviso desapareça.

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

```text
loonar/ssl-certs/
  ├── fullchain.pem
  └── privkey.pem
  └── ca-bundle.crt
```

Se não tiver certificados, o setup continuará mas sem HTTPS (não recomendado para produção).

---

## 📂 Estrutura de Diretórios

### Local

```text
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

### Remoto (após deploy via SSH)

```text
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

### Tela em branco / CSP apontando para `https://superset/...`

Esse sintoma ocorre quando o Nginx ainda não foi recarregado com o template que encaminha o cabeçalho `Host` para os assets estáticos e o Superset responde com redirecionamentos para `https://superset/...`.

1. Recrie o serviço Nginx com o template atualizado:

  ```bash
  ./loonar/up.sh
  # ou
  docker compose --env-file loonar/.env -f docker-compose-loonar.yml restart nginx
  ```

1. Valide que não há mais redirecionamentos executando:

  ```bash
  curl -I https://$SUPERSET_HOST/static/appbuilder/css/flags/flags16.css
  ```

  O comando deve retornar `HTTP/2 200` sem mudar o host.

1. Limpe o cache do navegador (ou abra uma janela anônima) e recarregue a UI.

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

## 🎯 Exemplo de Conexão MSSQL (SQL Server) no Superset

Para conectar o Superset a um banco de dados Microsoft SQL Server usando o driver ODBC 18, utilize a seguinte string de conexão no campo "SQLAlchemy URI":

```text
mssql+pyodbc://usuario:senha@host:1433/nome_do_banco?driver=ODBC+Driver+18+for+SQL+Server&TrustServerCertificate=yes
```

**Exemplo com dados fictícios:**

```text
mssql+pyodbc://superset_user:Sup3rs3tPwd!@192.168.1.100:1433/MeuBanco?driver=ODBC+Driver+18+for+SQL+Server&TrustServerCertificate=yes
```

**Atenção:**
- O parâmetro `TrustServerCertificate=yes` é necessário para aceitar certificados autoassinados.
- O separador entre parâmetros extras é `&` (e comercial).
- O nome do driver deve ser exatamente igual ao instalado no sistema (verifique com `odbcinst -q -d`).

Se ocorrer erro de SSL/certificado, revise o parâmetro acima. Se aparecer erro de driver, valide a instalação do ODBC Driver 18.

---

## ⚠️ Avisos de Segurança

1. **NUNCA** versione o arquivo `.env` com segredos reais
2. Use certificados SSL válidos em produção
3. Troque as senhas padrão do usuário admin
4. Configure firewall adequadamente no servidor remoto
5. Mantenha Docker e dependências atualizadas
6. Use `SUPERSET_SECRET_KEY` forte e único
7. Configure backup dos volumes regularmente
