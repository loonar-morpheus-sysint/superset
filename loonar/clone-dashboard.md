<!--
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
-->

# Clone de Dashboards — `clone-dashboard.sh`

## O que o script faz

O script `clone-dashboard.sh` automatiza a clonagem de um dashboard “modelo” no Superset para múltiplas *roles* que seguem um sufixo específico. O fluxo, em resumo:

- Autentica no Superset (sessão com cookie + CSRF e JWT para endpoints que exigem Bearer).
- Exporta **uma única vez** o dashboard modelo (template).
- Para cada role que termina com o sufixo configurado:
  - Cria um clone do template (novo UUID), ajusta filtro de “Cliente”, e importa.
  - Renomeia o dashboard clonado.
  - Aplica a role correspondente como permissão do dashboard.
- Mostra um resumo final de criados/ignorados/falhas.

## Variáveis necessárias no `.env`

O script espera um arquivo `.env` no **mesmo diretório** (`loonar/`) com as seguintes chaves:

- `SUPERSET_HOST` — host do Superset (com ou sem `https://`) **quando `SUPERSET_URL` no script estiver vazio**.
- `LOONAR_CLONE_SUPERSET_USER` — usuário para login.
- `LOONAR_CLONE_SUPERSET_PASS` — senha do usuário.
- `LOONAR_CLONE_DASHBOARD_ID` — ID do dashboard modelo (origem).
- `LOONAR_CLONE_DASHBOARD_PREFIX` — prefixo do nome dos dashboards clonados.
- `LOONAR_CLONE_ROLE_SUFFIX` — sufixo usado para filtrar as roles.

## Prioridade da URL do Superset

O valor de `SUPERSET_URL` definido no próprio `clone-dashboard.sh` tem prioridade sobre `SUPERSET_HOST` do `.env`.

- Se `SUPERSET_URL` estiver preenchido no script, ele será usado.
- Se `SUPERSET_URL` estiver vazio no script, o valor vem de `SUPERSET_HOST` no `.env`.

Isso permite fixar um endpoint no script quando necessário (por exemplo, ambiente local) sem depender da variável no `.env`.

## Comportamento de certificado (HTTP/HTTPS)

- Para URL com `http://`: opções de certificado TLS são **ignoradas**.
- Para URL com `https://`: o script usa `--insecure` nas chamadas HTTP (ignora validação de certificado).

> **Exemplo de `.env`:**
>
> ```
> SUPERSET_HOST=https://superset.seudominio.com
> LOONAR_CLONE_SUPERSET_USER=usuario_clone
> LOONAR_CLONE_SUPERSET_PASS=senha_segura
> LOONAR_CLONE_DASHBOARD_ID=123
> LOONAR_CLONE_DASHBOARD_PREFIX=CLIENTE
> LOONAR_CLONE_ROLE_SUFFIX=CONTROLE
> ```

## Como executar manualmente

A partir do diretório `loonar/`:

```
./clone-dashboard.sh
```

Para execução sem interação (sem prompts de confirmação):

```
./clone-dashboard.sh --no-interactive
```

## Parâmetros de execução

- `--no-interactive` — não solicita confirmação para:
  - atualizar/instalar dependências;
  - confirmar criação dos dashboards.

## Como agendar no crontab

O cron deve **entrar no diretório** `loonar/` e registrar logs em `/var/log/clone-dashboard-<dia da semana>.log`.

### Exemplo de entrada no crontab

```
# Executa todos os dias às 02:30
30 2 * * * cd /home/devopsvanilla/_prj/loonar/loonar-morpheus-sysint/superset/loonar && \
  LOG="/var/log/clone-dashboard-$(LC_TIME=pt_BR.UTF-8 date +%A).log" && \
  /bin/bash ./clone-dashboard.sh --no-interactive >> "$LOG" 2>&1
```

> **Observações importantes:**
>
> - O usuário do cron precisa de permissão de escrita em `/var/log/`.
> - Se preferir logs com dia em inglês, remova `LC_TIME=pt_BR.UTF-8`.
> - Para evitar crescimento ilimitado dos logs, considere configurar `logrotate`.

## Como monitorar a execução

Durante (ou após) a execução, você pode acompanhar o arquivo de log do dia:

```
# Exemplo para segunda-feira
sudo tail -f /var/log/clone-dashboard-Segunda-feira.log
```

Se estiver usando o formato em inglês (ex.: `Monday`):

```
sudo tail -f /var/log/clone-dashboard-Monday.log
```

Para verificar rapidamente o último status:

```
sudo tail -n 200 /var/log/clone-dashboard-$(LC_TIME=pt_BR.UTF-8 date +%A).log
```
