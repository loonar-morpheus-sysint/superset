# Verificação de Logos Customizados - Loonar FinOps

## ✅ Mudanças Aplicadas

### 1. Arquivos de Logo

- **Local**: `<local do repositório>/loonar-morpheus-sysint/superset/loonar/logo/`
- **Arquivos**:
  - `logo-light.png` - Logo para modo claro (12.9 KB)
  - `logo-dark.png` - Logo para modo escuro (12.9 KB)

### 2. Docker Compose

**Arquivo**: `docker-compose-loonar.yml`

Volumes adicionados:

```yaml
- ./loonar/pythonpath:/app/pythonpath
- ./loonar/logo:/app/superset/static/assets/images/loonar:ro
```

### 3. Configuração do Superset

**Arquivo**: `loonar/pythonpath/superset_config.py`

Configurações aplicadas:

```python
APP_NAME = "Loonar FinOps"
APP_ICON = "/static/assets/images/loonar/logo-light.png"
LOGO_TOOLTIP = "Loonar FinOps - Powered by Superset"

# Temas com logos customizados
THEME_DEFAULT = {
    "algorithm": "default",
    "token": {
        "brandLogoUrl": "/static/assets/images/loonar/logo-light.png",
        "brandLogoAlt": "Loonar FinOps",
        "brandLogoHeight": "40px",
        # ... outras configurações
    }
}

THEME_DARK = {
    "algorithm": "dark",
    "token": {
        "brandLogoUrl": "/static/assets/images/loonar/logo-dark.png",
        "brandLogoAlt": "Loonar FinOps",
        "brandLogoHeight": "40px",
        # ... outras configurações
    }
}

# Talisman CSP atualizado
TALISMAN_CONFIG = {
    "content_security_policy": {
        "default-src": ["'self'", "data:", "blob:"],
        "img-src": ["'self'", "data:", "https:"],
        "script-src": ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
        "script-src-elem": ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
        "style-src": ["'self'", "'unsafe-inline'"],
        "style-src-elem": ["'self'", "'unsafe-inline'"],
        "font-src": ["'self'", "data:"],
    },
    "force_https": False,  # HTTPS gerenciado pelo Nginx
    "force_https_permanent": False,
}

# IMPORTANTE: Não usar SERVER_NAME em ambiente com proxy reverso
PREFERRED_URL_SCHEME = "https"
```

### 4. Nginx

**Arquivo**: `docker/nginx/conf.d/superset.conf`

CSP headers atualizados:

```nginx
add_header Content-Security-Policy "default-src 'self' data: blob:; img-src 'self' data: https:; font-src 'self' data:; style-src 'self' 'unsafe-inline'; style-src-elem 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; script-src-elem 'self' 'unsafe-inline' 'unsafe-eval'" always;
```

Proxy headers para static files:

```nginx
proxy_redirect off;
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-Server $host;
proxy_set_header X-Forwarded-Proto $scheme;
```

## 🔍 Como Verificar

### 1. Verificar se os containers estão rodando

```bash
cd <local do repositório>/loonar-morpheus-sysint/superset
docker compose -f docker-compose-loonar.yml ps
```

Todos devem estar **healthy**.

### 2. Verificar se os arquivos estão montados corretamente

```bash
docker compose -f docker-compose-loonar.yml exec superset_app \
  ls -lh /app/superset/static/assets/images/loonar/
```

Deve mostrar:

- `logo-dark.png` (13K)
- `logo-light.png` (13K)

### 3. Verificar se a configuração foi carregada

```bash
docker compose -f docker-compose-loonar.yml exec superset_app bash -c \
  "python3 -c 'from superset import config; print(config.APP_NAME, config.APP_ICON)'"
```

Deve mostrar:

```text
Loaded your LOCAL configuration at [/app/pythonpath/superset_config.py]
Loonar FinOps /static/assets/images/loonar/logo-light.png
```

### 4. Verificar no navegador

1. **Limpar cache do navegador**:
   - Chrome/Edge: `Ctrl + Shift + Delete` → Marcar "Imagens e arquivos em cache" → Limpar
   - Firefox: `Ctrl + Shift + Delete` → Marcar "Cache" → Limpar

2. **Acessar a aplicação**:
   - URL: https://your.domain.com
   - Fazer login

3. **Verificar os logos**:
   - ✅ Logo no cabeçalho superior (navbar)
   - ✅ Título "Loonar FinOps" ao invés de "Superset"
   - ✅ Trocar entre modo claro/escuro (ícone de sol/lua) para verificar se o logo muda

4. **Testar em modo escuro**:
   - Clicar no ícone de tema (sol/lua) no canto superior direito
   - Verificar se o logo muda para `logo-dark.png`

## 🐛 Troubleshooting

### Logo não aparece ou aparece o antigo

1. **Limpar cache do navegador** (Ctrl + Shift + Delete)
2. **Fazer hard refresh** (Ctrl + F5)
3. **Tentar em modo anônimo** do navegador
4. **Verificar logs do container**:

   ```bash
   docker compose -f docker-compose-loonar.yml logs superset_app | tail -50
   ```

### Container não está saudável

```bash
# Verificar logs
docker compose -f docker-compose-loonar.yml logs superset_app

# Reiniciar container
docker compose -f docker-compose-loonar.yml restart superset_app

# Se necessário, recriar
docker compose -f docker-compose-loonar.yml up -d superset_app
```

### Erro de permissão nos arquivos de logo

```bash
# Verificar permissões
ls -la loonar/logo/

# Ajustar se necessário
chmod 644 loonar/logo/*.png
```

## 📝 Notas Importantes

1. **Cache**: Navegadores fazem cache agressivo de imagens estáticas. Sempre limpe o cache após mudanças.

2. **Temas**: O Superset suporta dois temas (claro e escuro). Cada um pode ter seu próprio logo.

3. **Tamanho dos logos**:
   - Altura configurada: 40px
   - Os logos devem ter proporções adequadas para evitar distorção
   - Tamanho atual dos arquivos: ~13KB cada

4. **Localização dos arquivos**:
   - Host: `loonar/logo/`
   - Container: `/app/superset/static/assets/images/loonar/`
   - URL: `/static/assets/images/loonar/logo-*.png`

## ✅ Status Final

- [x] Logos montados no container
- [x] Configuração aplicada
- [x] Containers rodando e saudáveis
- [ ] **PENDENTE**: Verificar na UI do navegador (requer limpeza de cache)

## 🔄 Reverter Mudanças (se necessário)

Se precisar voltar aos logos originais:

1. Editar `loonar/pythonpath/superset_config.py`:

   ```python
   APP_ICON = "/static/assets/images/superset-logo-horiz.png"
   # Remover THEME_DEFAULT e THEME_DARK customizados
   THEME_DEFAULT = {"algorithm": "default"}
   THEME_DARK = {"algorithm": "dark"}
   ```

2. Reiniciar container:

   ```bash
   docker compose -f docker-compose-loonar.yml restart superset_app
   ```
