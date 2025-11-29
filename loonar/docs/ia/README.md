
# Superset Agent Mode Documentation Index

> ⚠️ **WIP: Este documento está em desenvolvimento!**

Este diretório contém todos os documentos de agente para automação, configuração modular e melhores práticas do Superset.

## Integração com GitHub Copilot Custom Agents

- Os arquivos `.agent.md` deste diretório servem como base de conhecimento detalhada para cada contexto de automação.
- Os arquivos `.agent.md` com prefixo "Superset - " em `.github/agents/` são usados para seleção direta no menu do Copilot.
- Sempre que atualizar ou criar um novo documento aqui, sincronize a versão correspondente em `.github/agents/` para garantir que o menu reflita as opções corretas.
- Apenas os arquivos com prefixo "Superset - " aparecem no menu do Copilot; os demais são ignorados.

## Como usar

1. **Escolha o tema/agente** no menu do Copilot ou na interface customizada (exemplo: "Cache", "Banco de Dados", "Alertas e Relatórios").
2. O agente carrega o arquivo `.config.agent.md` correspondente deste diretório ou o `.agent.md` em `.github/agents/`.
3. O Copilot utiliza as recomendações, variáveis e práticas do documento para:
   - Responder dúvidas assertivamente
   - Automatizar configurações
   - Validar requisitos de produção
   - Sugerir scripts, variáveis e integrações
4. Você pode pedir respostas mais assertivas ("apenas o obrigatório para produção") ou mais flexíveis ("todas as opções disponíveis").

## Documentos disponíveis

- AlertsReports.config.agent.md
- AsyncQueriesCelery.config.agent.md
- Cache.config.agent.md
- ConfiguringSuperset.config.agent.md
- CountryMapTools.config.agent.md
- Databases.config.agent.md
- EventLogging.config.agent.md
- ImportExportDatasources.config.agent.md
- MapTiles.config.agent.md
- NetworkingSettings.config.agent.md
- SQLTemplating.config.agent.md
- Theming.config.agent.md
- Timezones.config.agent.md
Timezones.config.agent.md

## Exemplo de integração

> Ao selecionar "Banco de Dados" no menu, o Copilot lê `Databases.config.agent.md` e te orienta sobre drivers, variáveis, rotação de segredos e automação.

## Manutenção

- Mantenha este diretório e `.github/agents/` sincronizados.
- Remova arquivos antigos ou duplicados sem o prefixo "Superset - " de `.github/agents/`.
- Consulte este README para saber quais agentes estão disponíveis e garantir que o menu do Copilot esteja sempre atualizado.

## Automação: Atualização dos agentes via documentação oficial


Para manter os arquivos `.config.agent.md` sempre atualizados com a documentação oficial do Apache Superset, utilize os scripts de automação deste diretório:

- `update_agents_from_official_docs.sh`: Orquestra a atualização dos agentes, chamando o script Python para cada documento. Antes de rodar, verifica se todas as dependências estão instaladas e pede confirmação para instalar se necessário.
- `fetch_superset_doc.py`: Baixa e converte a documentação oficial em Markdown para cada agente. Também valida dependências e cancela a execução se o usuário não quiser instalar.

### Como atualizar

1. Edite o Bash para incluir todos os agentes e URLs relevantes.
2. Torne o script executável:
   `chmod +x ./loonar/docs/ia/update_agents_from_official_docs.sh`
3. Execute manualmente ou agende via cron:
   `./loonar/docs/ia/update_agents_from_official_docs.sh`

**Dependências obrigatórias:**
  - Python 3
  - pip
  - requests (`pip install requests`)
  - beautifulsoup4 (`pip install beautifulsoup4`)

O Bash gerencia o ciclo de atualização e chama o Python, que faz o download, parsing e atualização dos arquivos. Ambos os scripts validam dependências e garantem segurança na execução. Adapte conforme necessário para sua rotina.

---

**Mantenha este diretório atualizado sempre que novos agentes forem criados ou alterados.**

---

_Para integração avançada, crie menus customizados que listem os temas e carreguem o documento correspondente para cada contexto de automação._
