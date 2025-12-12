# 🚀 Guia Rápido - Deploy do Superset Loonar

## ⚡ Início Rápido (2 passos)

```bash
# 1. Gerar segredos (primeira vez)
cd loonar
./rotate-keys.sh

# 2. Executar o deploy interativo
./up.sh   # escolha o contexto Docker desejado quando solicitado
```
> **Nota:** O deploy agora utiliza uma imagem customizada (`Dockerfile-loonar`) que embute todas as configurações e arquivos necessários, incluindo o `.env` e customizações Python. O script `up.sh` oferece um menu para escolher entre rebuild da imagem ou uso da imagem atual, tornando o processo mais flexível e rápido. Apenas volumes de dados persistentes são utilizados, sem necessidade de volumes para arquivos de configuração.

O script `up.sh` lista todos os contextos Docker, permite escolher o alvo (local ou remoto) e cria os volumes/persistência automaticamente usando volumes gerenciados pelo Docker.

---

## 📋 Cenários Práticos

### Cenário 1: Desenvolvimento Local

```bash
cd loonar
./up.sh
# selecione o contexto "default" (ou pressione Enter para manter o atual)

# Acesse em: http://localhost:8088 ou http://your.domain.com
# Login padrão: admin / admin (troque após o primeiro acesso)
```

### Cenário 2: Servidor Remoto (Docker Context)

```bash
# 1. Criar contexto remoto (uma vez)
docker context create producao --docker "host=ssh://user@servidor.com"

# 2. Executar o script normalmente na sua máquina
cd loonar
./up.sh
# selecione o contexto "producao" na lista apresentada

# O script fará o deploy usando o daemon remoto sem exigir diretórios de volumes no host
```

### Cenário 3: Servidor Remoto (SSH direto)

```bash
# 1. Clone o repositório no servidor remoto e gere o .env
ssh user@servidor.com "git clone <repo> superset && cd superset/loonar && ./rotate-keys.sh"

# 2. Execute o script já no servidor
ssh user@servidor.com
cd superset/loonar
./up.sh
# selecione o contexto "default" (você está executando diretamente no host)
```

---

## 🔧 Comandos de Gerenciamento

```bash
./loonar/up.sh                # Deploy/atualização (context aware)
./loonar/down.sh              # Parar serviços
./loonar/down.sh -v           # Parar e remover volumes gerenciados
docker compose \
  --env-file loonar/.env \
  -f docker-compose-loonar.yml logs -f  # Ver logs detalhados
```

---

## 🐛 Resolução de Problemas Comuns

- **`.env` ausente** → execute `./loonar/rotate-keys.sh`
- **Variável obrigatória vazia** → edite `loonar/.env` ou gere novamente com `rotate-keys.sh`
- **Contexto inválido** → confirme com `docker context ls` e rode `./loonar/up.sh` novamente
- **Volumes** → agora são gerenciados pelo Docker (`docker volume ls`), não há necessidade de criar diretórios manualmente

---

## 📊 Estrutura Essencial

```text
loonar/
├── up.sh              # Script interativo (contextos + redes)
├── down.sh            # Encerrar serviços
├── rotate-keys.sh     # Rotacionar segredos do .env
├── setup-local.sh     # Utilitário legado (opcional)
├── setup-remote-ssh.sh# Utilitário legado (opcional)
├── README*.md         # Documentação
└── .env               # Configurações (NÃO versionar)
```

---

## 🔐 Segurança - Checklist

- [ ] Executou `./rotate-keys.sh` para gerar segredos únicos
- [ ] Confirmou que `.env` **não** está versionado
- [ ] Configurou certificados em `loonar/ssl-certs/`
- [ ] Alterou a senha padrão do usuário admin
- [ ] Protegeu o host (firewall / regras de acesso)

---

## ✅ Validação

```bash
cd loonar
./validate.sh   # valida arquivos de configuração
```

---

## 🔄 Comandos Úteis

```bash
docker context ls                  # Listar contextos disponíveis
docker ps                          # Ver containers ativos
docker compose -f docker-compose-loonar.yml ps
docker compose -f docker-compose-loonar.yml logs -f superset_app
./down.sh && ./up.sh               # Reiniciar rapidamente
```

---

**Ficou com dúvidas?** Consulte a documentação completa em [DEPLOY.md](DEPLOY.md).

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

### Tela em branco + erros CSP `https://superset/...`

**Solução:**

```bash
./loonar/up.sh
# ou
docker compose --env-file loonar/.env -f docker-compose-loonar.yml restart nginx
curl -I https://$SUPERSET_HOST/static/appbuilder/css/flags/flags16.css
```

Após o restart, o `curl` deve retornar 200 sem redirecionar; limpe o cache do navegador e recarregue a UI.

---

## 📚 Documentação Completa

Para mais detalhes, consulte: **`loonar/README.md`**
