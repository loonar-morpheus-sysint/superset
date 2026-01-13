# Correção: Erro 503 na Autenticação

## Problema Identificado

Quando o usuário errava a senha ou tentava acessar com um usuário inexistente no Superset UI, ocorria um erro:
```
503 Service Temporarily Unavailable
nginx/1.25.5
```

## Causa Raiz

O arquivo [loonar/pythonpath/loonar/security.py](loonar/pythonpath/loonar/security.py) **não tinha tratamento de exceções** nos métodos de autenticação:

1. **`_login_with_database()`** - Chamava `auth_user_db()` sem try/except
2. **`_login_with_ldap()`** - Chamava `auth_user_ldap()` sem try/except  
3. **`_sync_roles_from_ldap_groups()`** - Não tratava exceções LDAP
4. **`_get_bound_connection()`** - Não tratava erros de conexão LDAP

Quando ocorria um erro não capturado:
1. A exceção propagava para o Flask
2. Flask retornava um erro 500 interno
3. O nginx, ao não conseguir alcançar o backend, retornava 503

## Solução Implementada

### 1. Tratamento de Exceções em `_login_with_database()`
```python
def _login_with_database(self, form: LoonarLoginForm) -> Optional[Response]:
    try:
        user = self.appbuilder.sm.auth_user_db(form.username.data, form.password.data)
        if not user:
            flash(_("Usuário ou senha inválidos."), "danger")
            return None
        # ... resto do código
    except Exception as e:
        logger.error(f"Erro durante autenticação: {str(e)}", exc_info=True)
        flash(_("Erro ao processar login. Tente novamente."), "danger")
        return None
```

### 2. Tratamento de Exceções em `_login_with_ldap()`
```python
def _login_with_ldap(self, form: LoonarLoginForm) -> Optional[Response]:
    try:
        user = self.appbuilder.sm.auth_user_ldap(form.username.data, form.password.data)
        # ... resto do código
    except LDAPException as e:
        logger.error(f"Erro de conexão LDAP: {str(e)}", exc_info=True)
        flash(_("Erro ao conectar ao Active Directory. Tente novamente."), "danger")
        return None
    except Exception as e:
        logger.error(f"Erro durante autenticação LDAP: {str(e)}", exc_info=True)
        flash(_("Erro ao processar login. Tente novamente."), "danger")
        return None
```

### 3. Tratamento de Exceções em `_sync_roles_from_ldap_groups()`
- Adicionado try/except com logging detalhado
- A sincronização de roles falha gracefully, sem interromper o login
- Desconexão LDAP protegida contra erros

### 4. Tratamento de Exceções em `_get_bound_connection()`
- Validação de configurações LDAP com warnings
- Captura específica de `LDAPException`
- Captura genérica de outras exceções
- Logs detalhados para debugging

### 5. Adicionado Logging
```python
import logging
logger = logging.getLogger(__name__)
```

Todos os métodos agora loggam erros com `exc_info=True` para rastreamento completo.

## Benefícios

✅ **Resiliência**: A autenticação falha gracefully com mensagens úteis ao usuário  
✅ **Observabilidade**: Todos os erros são logados com stack trace completo  
✅ **Experiência do Usuário**: Em vez de erro 503, o usuário vê mensagem amigável  
✅ **Debugging**: Logs detalhados facilitam diagnóstico de problemas LDAP  

## Testes Recomendados

1. **Teste com usuário inexistente**: Acesse com username que não existe
2. **Teste com senha errada**: Use um usuário válido com senha incorreta
3. **Teste LDAP desconectado**: Desconecte o servidor LDAP e tente login LDAP
4. **Verifique logs**: Confirme que erros são logados corretamente

## Configurações Recomendadas

No arquivo `loonar/.env`, configure logging:
```bash
# Habilitar logs detalhados
SUPERSET_LOG_LEVEL=debug
```

## Arquivos Modificados

- `loonar/pythonpath/loonar/security.py`
