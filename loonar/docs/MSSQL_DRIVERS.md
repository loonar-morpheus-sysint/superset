# Drivers Microsoft SQL Server - Guia de Uso

## Drivers Instalados

Esta instalação do Superset possui **dois drivers** para conexão com Microsoft SQL Server:

1. **pymssql** - Driver mais simples
2. **pyodbc** - Driver com mais recursos

## Como Usar

### 1. Reconstruir a Imagem Docker

Após qualquer modificação nos arquivos de requisitos ou Dockerfile, reconstrua a imagem:

```bash
cd <local do repositório>/loonar-morpheus-sysint/superset
docker-compose -f docker-compose-loonar.yml build superset_app
docker-compose -f docker-compose-loonar.yml up -d
```

### 2. Criar Conexão no Superset

No Superset UI, vá para **Data > Databases > + Database** e escolha o driver na string de conexão:

#### Opção A: pymssql (Recomendado para simplicidade)

```text
mssql+pymssql://username:password@hostname:1433/database_name
```

**Características:**

- ✅ Configuração mais simples
- ✅ Menos dependências externas
- ✅ Bom para casos de uso básicos
- ❌ Menos recursos avançados

**Exemplo:**

```text
mssql+pymssql://sa:MyP@ssw0rd@sqlserver.example.com:1433/sales_db
```

#### Opção B: pyodbc (Recomendado para recursos avançados)

```text
mssql+pyodbc://username:password@hostname:1433/database_name?driver=FreeTDS
```

**Características:**

- ✅ Mais recursos e controle
- ✅ Melhor suporte a tipos de dados complexos
- ✅ Mais opções de configuração
- ❌ Requer configuração ODBC adicional

**Exemplo básico:**

```text
mssql+pyodbc://sa:MyP@ssw0rd@sqlserver.example.com:1433/sales_db?driver=FreeTDS
```

**Exemplo com parâmetros adicionais:**
```text
mssql+pyodbc://sa:MyP@ssw0rd@sqlserver.example.com:1433/sales_db?driver=FreeTDS&TDS_Version=7.4&charset=UTF-8
```

### 3. Opções Avançadas pyodbc

Para usar o Microsoft ODBC Driver (se instalado):

```text
mssql+pyodbc://username:password@hostname:1433/database_name?driver=ODBC+Driver+17+for+SQL+Server
```

ou

```text
mssql+pyodbc://username:password@hostname:1433/database_name?driver=ODBC+Driver+18+for+SQL+Server&Encrypt=yes&TrustServerCertificate=no
```

## Solução de Problemas

### Testar Conexão via CLI

```bash
# Entrar no container
docker exec -it superset_app bash

# Testar pymssql
python -c "import pymssql; print('pymssql OK')"

# Testar pyodbc
python -c "import pyodbc; print('pyodbc OK')"

# Listar drivers ODBC disponíveis
python -c "import pyodbc; print(pyodbc.drivers())"
```

### Verificar Conectividade

```bash
# Verificar se a porta SQL Server está acessível
docker exec -it superset_app bash -c "nc -zv sqlserver.example.com 1433"
```

### Erros Comuns

#### Erro: "Can't open lib 'FreeTDS'"

- Solução: Use `pymssql` ao invés de `pyodbc` ou instale drivers ODBC adicionais

#### Erro: "Login failed for user"

- Verifique usuário, senha e permissões no SQL Server
- Certifique-se que autenticação SQL está habilitada

#### Erro: "Unable to connect"

- Verifique firewall e conectividade de rede
- Confirme que SQL Server está escutando na porta correta

## Comparação de Performance

| Aspecto | pymssql | pyodbc |
|---------|---------|--------|
| Velocidade | ⚡⚡⚡ Rápido | ⚡⚡ Médio |
| Recursos | ⭐⭐ Básico | ⭐⭐⭐ Avançado |
| Configuração | ✅ Simples | ⚠️ Complexa |
| Compatibilidade | ✅ SQL Server 2005+ | ✅ SQL Server 2000+ |
| Suporte a Tipos | 📊 Básico | 📊📊📊 Completo |

## Recomendações

1. **Para desenvolvimento/testes**: Use `pymssql`
2. **Para produção com tipos complexos**: Use `pyodbc`
3. **Para máxima compatibilidade**: Teste ambos e escolha o que funcionar melhor

## Arquivos Modificados

Os seguintes arquivos foram modificados para suportar ambos os drivers:

- `requirements/base.in` - Adicionados pymssql e pyodbc
- `requirements/base.txt` - Compilado automaticamente
- `Dockerfile` - Adicionadas dependências do sistema (unixodbc-dev, freetds-dev, etc.)

## Segurança em Produção

⚠️ **IMPORTANTE**:

1. **Nunca** exponha credenciais em logs ou código
2. Use **variáveis de ambiente** para senhas
3. Configure **SSL/TLS** quando possível (parâmetro `Encrypt=yes`)
4. Use **usuários com privilégios mínimos**
5. Configure **firewall** para restringir acesso ao SQL Server

## Suporte

Para mais informações sobre strings de conexão SQLAlchemy:

- https://docs.sqlalchemy.org/en/latest/dialects/mssql.html
- https://pymssql.readthedocs.io/
- https://github.com/mkleehammer/pyodbc/wiki
