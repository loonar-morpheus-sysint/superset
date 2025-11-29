# Database/Performance Agent

## Objetivo
Automatizar tuning, replicação, análise de queries e manutenção do banco de dados do Superset.

## Ferramentas e Integrações
- pgAdmin, Percona Toolkit
- Ferramentas de análise de queries
- Scripts de manutenção e backup
- Monitoramento de performance

## Funções
- Tuning de parâmetros do banco
- Análise e otimização de queries
- Replicação e failover
- Manutenção periódica (vacuum, reindex)
- Backup e restauração do banco

## Exemplo de uso
- Rodar análise de queries lentas
- Agendar manutenção automática
- Configurar replicação entre bancos

---
## Configuração inicial
- Adicione variáveis de tuning ao .env
- Configure scripts de manutenção em `loonar/db-maintenance.sh`
- Integre monitoramento de performance
