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
> **Novidade:** Agora o deploy utiliza uma imagem customizada (`Dockerfile-loonar`) que já embute todas as configurações e arquivos necessários, incluindo o `.env` e customizações Python. Não é mais necessário mapear volumes para arquivos de configuração, apenas os volumes de dados persistentes são usados. O script `up.sh` também oferece um menu para escolher entre rebuild da imagem (após alterações de código/config) ou uso da imagem atual para deploy rápido.
```

O script irá:

1. Validar se o Docker está acessível e se o `.env` existe.
2. Listar os contextos Docker configurados (`docker context ls`).
3. Permitir que você escolha o contexto alvo ou mantenha o atual.
4. Perguntar qual fonte de LDAP deseja usar (Active Directory real ou servidor mock) e atualizar a variável `LOONAR_LDAP_MODE` automaticamente.
5. Detectar se o `docker-compose-loonar.yml` define redes. Se não definir, perguntará qual rede utilizar ou criará uma nova.
6. Executar `docker compose --env-file loonar/.env -f docker-compose-loonar.yml up -d --build --remove-orphans` no contexto escolhido.

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

## 📞 Suporte adicional

- Documentação oficial do Superset: <https://superset.apache.org/docs/>
- Guia completo de deploy: [`DEPLOY.md`](DEPLOY.md)

````

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

## 🧪 Servidor Active Directory Mock

Quando for necessário testar a integração LDAP/AD sem acessar o diretório corporativo, utilize o Compose auxiliar `docker-compose-ldap-mock.yml` e o script `./loonar/up-ldap-mock.sh`.

1. Ajuste (se quiser) as variáveis em `loonar/ldap-mock/.env`. Por padrão ele cria o domínio `loonardc.local`, expõe a porta `3389` e popula a estrutura `OU=03-SERVICOS`/`OU=04-CLIENTES`.
2. Execute `./loonar/up-ldap-mock.sh` e selecione o contexto Docker desejado (local ou remoto). O script garante que a rede Docker `superset` exista, valida o compose auxiliar e sobe o serviço `mock_ad` (imagem `osixia/openldap`). Ele também envia o LDIF/schema diretamente do diretório `loonar/ldap-mock/` para dentro do container, então funciona inclusive quando o Docker Engine está em outro host (contextos remotos via SSH, por exemplo).
3. Assim que o OpenLDAP ficar disponível, o script reaplica automaticamente o arquivo `50-loonar-structure.ldif`: primeiro remove as OUs `03-SERVICOS` e `04-CLIENTES` (se já existirem) e depois reimporta todo o conteúdo. Isso garante que sucessivas execuções sempre mantenham os mesmos usuários/grupos do LDIF.
4. Ao final é executado um `ldapsearch` dentro do container para confirmar que o bind com a conta de serviço está funcional. Caso o teste falhe, os logs do mock são exibidos automaticamente.
4. Aponte o Superset para `ldap://<host-remoto>:3389` usando as mesmas credenciais definidas no `.env` principal:
  - **Conta de serviço:** `CN=Morpheus Serviços,OU=BR-BH,OU=03-SERVICOS,DC=loonardc,DC=local`
  - **Senha da conta de serviço:** `Morph&us#2020`
  - **Base DN de busca:** `OU=04-CLIENTES,DC=loonardc,DC=local`
  - **Usuário teste:** `CN=Joana Superset,OU=04-CLIENTES,DC=loonardc,DC=local` (`Superset#2024`)

O LDIF em `loonar/ldap-mock/bootstrap/50-loonar-structure.ldif` mantém os grupos `Gamma` e `Admin`, que correspondem às roles padrão do Superset. Caso precise de novos grupos/usuários, basta editar esse arquivo e executar novamente `./loonar/up-ldap-mock.sh` (ele sempre sobrescreve o conteúdo existente dessas OUs com o LDIF atualizado). Há também um schema mínimo em `loonar/ldap-mock/schema/50-superset-samaccount.ldif` que expõe o atributo `sAMAccountName`, permitindo usar o mesmo `.env` tanto com o mock quanto com o AD real.

Como o `.env` armazena os blocos `*_REAL` e `*_MOCK`, você pode alternar entre eles a qualquer momento reexecutando `./up.sh` e escolhendo a opção desejada. O script atualizará `LOONAR_LDAP_MODE`, executará `docker compose ... up -d` e o Superset passará a usar o novo servidor sem necessidade de editar arquivos manualmente.

## 📞 Suporte

Para problemas específicos do Loonar, consulte a equipe de desenvolvimento.

Para questões do Apache Superset:

- Documentação: https://superset.apache.org/docs/
- GitHub: https://github.com/apache/superset
- Slack: https://apache-superset.slack.com/
