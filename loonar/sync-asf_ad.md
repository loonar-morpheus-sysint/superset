# Script `sync-asf-ad.sh`

## Propósito

O script `sync-asf-ad.sh` sincroniza roles do Apache Superset com grupos do Active Directory. Para cada grupo cujo `CN` contenha o termo desejado, uma role homônima é criada (ou atualizada) no Superset copiando integralmente as permissões de uma role base já existente. Todo o processo ocorre via container `superset_app` e registra logs detalhados com feedback de sucesso ou erro.

## Pré-requisitos

- Container Docker `superset_app` em execução e com acesso à instância Superset configurada.
- Ferramentas locais: `docker` e `ldapsearch` disponíveis no `PATH`.
- Credenciais de serviço do Active Directory com permissão de leitura para os grupos alvo.
- Role base no Superset já criada, contendo as permissões que serão clonadas.

## Parâmetros e variáveis

Todos os parâmetros são obrigatórios, porém podem ser omitidos se a variável de ambiente de mesmo nome já estiver definida. Exemplos: `AD_DN_BASE`, `AD_SVC_USER`, `LOG_PATH`.

| Parâmetro            | Descrição                                                                                 |
|----------------------|-------------------------------------------------------------------------------------------|
| `--ad_dn_base`       | DN base usado na consulta LDAP (ex.: `OU=Clientes,DC=example,DC=com`).                     |
| `--ad_cn_term`       | Termo obrigatório que deve aparecer no `CN` dos grupos (alias `--ad_cn_hasterm`).          |
| `--asf_role_base`    | Nome da role no Superset cujas permissões serão copiadas.                                  |
| `--ad_svc_user`      | DN completo do usuário de serviço que fará o bind LDAP.                                    |
| `--ad_svc_password`  | Senha do usuário de serviço.                                                               |
| `--retain_logs_max_days` | Número de dias para manter logs `sync-asf-ad_*.log` antes da limpeza automática.     |
| `--ad_uri`           | URI completa do servidor LDAP (ex.: `ldaps://ldap.example.com`). Se omitido, o script tenta derivar a partir do `DN`. |
| `--log_path`         | Diretório onde os arquivos de log serão criados. Deve existir e ser gravável.             |
| `--debug`            | (Opcional) Inclui a saída completa dos comandos LDAP/Docker no log.                        |
| `--show_log`         | (Opcional) Exibe no stdout as mesmas mensagens gravadas no log.                           |
| `-h`, `--help`       | Mostra o texto de ajuda.                                                                   |

## Execução básica

```bash
./sync-asf-ad.sh \
  --ad_dn_base "OU=Clientes,DC=example,DC=com" \
  --ad_cn_hasterm "-CONTROLE" \
  --asf_role_base "ROLE_BASE" \
  --ad_svc_user "CN=Service Account,OU=Infra,DC=example,DC=com" \
  --ad_svc_password "StrongPassword!" \
  --retain_logs_max_days 7 \
  --ad_uri "ldaps://ldap.example.com" \
  --log_path "/var/log/superset-sync" \
  --show_log
```

### Usando variáveis de ambiente

```bash
export AD_DN_BASE="OU=Clientes,DC=example,DC=com"
export AD_CN_TERM="-CONTROLE"
export ASF_ROLE_BASE="ROLE_BASE"
export AD_SVC_USER="CN=Service Account,OU=Infra,DC=example,DC=com"
export AD_SVC_PASSWORD="StrongPassword!"
export RETAIN_LOGS_MAX_DAYS=7
export AD_URI="ldaps://ldap.example.com"
export LOG_PATH="/var/log/superset-sync"

./sync-asf-ad.sh --show_log
```

## Agendamento via cron

1. Crie um arquivo de variáveis (ex.: `/opt/sync-asf-ad.env`) contendo os valores obrigatórios:

  ```bash
  AD_DN_BASE="OU=Clientes,DC=example,DC=com"
  AD_CN_TERM="-CONTROLE"
  ASF_ROLE_BASE="ROLE_BASE"
  AD_SVC_USER="CN=Service Account,OU=Infra,DC=example,DC=com"
  AD_SVC_PASSWORD="StrongPassword!"
  RETAIN_LOGS_MAX_DAYS=7
  AD_URI="ldaps://ldap.example.com"
  LOG_PATH="/var/log/superset-sync"
  ```

2. Edite o crontab do usuário responsável pela sincronização (ex.: `crontab -u superset -e`) e inclua uma entrada como a seguir:

  ```cron
  # Min Hora Dia Mês DiaSemana Comando
  0 2 * * * . /opt/sync-asf-ad.env && /home/app/superset/loonar/sync-asf-ad.sh --show_log >> /var/log/superset-sync/cron.log 2>&1
  ```

- O comando acima executa o script diariamente às 02h00.
- O arquivo `.env` é carregado primeiro para preencher os parâmetros obrigatórios.
- O redirecionamento `>>` adiciona a saída do cron ao log já usado pelo script; ajuste caminhos conforme necessário.

1. Após salvar o crontab, confirme a instalação com `crontab -l` e monitore os logs para garantir que o container `superset_app` esteja disponível no horário programado.

## Logs

- Os arquivos são criados como `sync-asf-ad_<diamesanohoraminutosegundo>.log` no diretório definido por `--log_path` (ou `LOG_PATH`).
- Logs antigos além do limite `--retain_logs_max_days` são excluídos automaticamente.
- Com `--debug`, a saída dos comandos `ldapsearch` e `docker exec` é adicionada ao log para facilitar troubleshooting.

## Mensagens e retorno

- Mensagens seguem o formato `AAAA-MM-DD HH:MM:SS [NÍVEL] texto`, com níveis `INFO` e `ERROR`.
- Qualquer falha crítica (ex.: container inexistente, role base não encontrada, diretório de log inválido) encerra o script imediatamente com código diferente de zero.

## Boas práticas

- Teste primeiro com `--show_log` em ambiente controlado para validar credenciais e filtro de grupos.
- Garanta que a role base contenha apenas as permissões desejadas, já que serão clonadas integralmente.
- Utilize usuários de serviço dedicados, com senha armazenada de forma segura (ex.: `pass`, `vault`, variáveis de ambiente protegidas).
