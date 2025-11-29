# Security/Compliance Agent

## Objetivo
Automatizar hardening, rotação de segredos, auditoria e conformidade do Superset.

## Ferramentas e Integrações
- Vault, AWS Secrets Manager
- Scanners de vulnerabilidade (Trivy, Clair)
- RBAC, controle de acesso
- Auditoria de logs
- Scripts de rotação de segredos

## Funções
- Rotação automática de segredos (.env, banco, API keys)
- Auditoria de logs e acessos
- Aplicação de políticas de segurança
- Scan de vulnerabilidades em containers
- Integração com sistemas de conformidade (LGPD, GDPR)

## Exemplo de uso
- Executar `loonar/rotate-keys.sh` para rotacionar segredos
- Rodar scanner de vulnerabilidade em imagens Docker
- Auditar logs de acesso e operações

---
## Configuração inicial
- Adicione variáveis de auditoria ao .env
- Configure integração com Vault ou Secrets Manager
- Agende rotação periódica de segredos
