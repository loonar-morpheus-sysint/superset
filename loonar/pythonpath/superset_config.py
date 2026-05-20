# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

import logging
import os
from datetime import timedelta
from typing import Any, Optional, Type
from urllib.parse import urlparse

from cachelib.redis import RedisCache
from celery.schedules import crontab
from flask_appbuilder.security.manager import AUTH_DB, AUTH_LDAP
from flask_appbuilder.security.sqla.manager import SecurityManager

from loonar import LoonarAppInitializer
from loonar.ldap_config import get_ldap_setting, get_ldap_user_base_aliases
from loonar.security import LoonarSecurityManager
from superset.security import SupersetSecurityManager

# =============================
# SUPORTE A IDIOMA PT-BR
# IMPORTANTE: Superset desabilita i18n por padrão (LANGUAGES = {}),
# então precisamos reabilitar com os idiomas desejados.
# Isso DEVE estar aqui, ANTES de qualquer outro import que possa 
# sobrescrever LANGUAGES.
LANGUAGES = {
    "en": {"flag": "us", "name": "English"},
    "pt_BR": {"flag": "br", "name": "Português (Brasil)"},
}
BABEL_DEFAULT_LOCALE = "pt_BR"
# Garanta que i18n está habilitado
# (Superset por padrão desabilita com LANGUAGES = {})
ENABLE_LANGUAGE_PACK = True

# Formato numérico D3 padrão para pt_BR (ponto como separador de milhar e vírgula decimal)
# Pode ser sobrescrito por D3_FORMAT no ambiente de produção, se desejado.
D3_FORMAT = {
    "decimal": ",",
    "thousands": ".",
    "grouping": [3],
    "currency": ["R$", ""],
}

# Diretórios onde Babel pode encontrar as traduções compiladas
BABEL_TRANSLATION_DIRECTORIES = "superset/translations"

# Garanta que o locale padrão é pt_BR (não permite fallback para pt)
# Se houver requisição para 'pt' sem '_BR', redireciona para 'pt_BR'
SUPPORTED_LANGUAGES = {
    "en": "English",
    "pt_BR": "Português (Brasil)",
}

# =============================
# BLOCO: CONFIGURAÇÃO DE AUTENTICAÇÃO - SELEÇÃO DO FORMULÁRIO DE LOGIN
ENABLE_FLASK_LOGIN = True
# =============================
# Determinar qual SecurityManager usar baseado na variável de ambiente
_LOGIN_FORM_TYPE: str = os.getenv("SUPERSET_LOGIN_FORM_TYPE", "ldap").lower()

# Escolher SecurityManager e template baseado na configuração
# Usando ternário para evitar redefinição de variáveis (problema do mypy)
_security_manager: Type[SecurityManager] = (
    SupersetSecurityManager if _LOGIN_FORM_TYPE == "superset" else LoonarSecurityManager
)
_login_template: Optional[str] = (
    None if _LOGIN_FORM_TYPE == "superset" else "security/login.html"
)

# Atribuições finais
CUSTOM_SECURITY_MANAGER = _security_manager
SECURITY_LOGIN_TEMPLATE = _login_template
APP_INITIALIZER = LoonarAppInitializer

# Logging para ajudar no debug
_logger: logging.Logger = logging.getLogger(__name__)
_logger.info(
    f"Login form type: {_LOGIN_FORM_TYPE} | Using: {CUSTOM_SECURITY_MANAGER.__name__}"
)

# =============================
# BLOCO: SEGURANÇA ORIGINAL
# =============================

# Security
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY") or os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    raise ValueError("SECRET_KEY must be set in production")

# Usar LDAP quando LoonarSecurityManager estiver ativo, caso contrário DB
AUTH_TYPE = AUTH_LDAP if _LOGIN_FORM_TYPE == "ldap" else AUTH_DB
_auth_user_registration_default = "true" if _LOGIN_FORM_TYPE == "ldap" else "false"
AUTH_USER_REGISTRATION = (
    os.getenv("AUTH_USER_REGISTRATION", _auth_user_registration_default).strip().lower()
    == "true"
)
AUTH_USER_REGISTRATION_ROLE = "Gamma"

_ldap_mode = os.getenv("LOONAR_LDAP_MODE", "real").strip().lower()
AUTH_LDAP_SERVER = (
    get_ldap_setting("LOONAR_LDAP_SERVER_MOCK")
    if _ldap_mode == "mock"
    else get_ldap_setting("LOONAR_LDAP_SERVER_REAL")
)
AUTH_LDAP_USE_TLS = (
    get_ldap_setting("LOONAR_LDAP_USE_SSL_MOCK", "false")
    if _ldap_mode == "mock"
    else get_ldap_setting("LOONAR_LDAP_USE_SSL_REAL", "false")
).lower() == "true"
AUTH_LDAP_BIND_USER = (
    get_ldap_setting("LOONAR_LDAP_BIND_DN_MOCK")
    if _ldap_mode == "mock"
    else get_ldap_setting("LOONAR_LDAP_BIND_DN_REAL")
)
AUTH_LDAP_BIND_PASSWORD = (
    get_ldap_setting("LOONAR_LDAP_BIND_PASSWORD_MOCK")
    if _ldap_mode == "mock"
    else get_ldap_setting("LOONAR_LDAP_BIND_PASSWORD_REAL")
)
_ldap_user_base_aliases = get_ldap_user_base_aliases("")
AUTH_LDAP_SEARCH = next(iter(_ldap_user_base_aliases.values()), "")
AUTH_LDAP_UID_FIELD = os.getenv("LOONAR_LDAP_UID_ATTR", "sAMAccountName")
AUTH_LDAP_FIRSTNAME_FIELD = os.getenv("LOONAR_LDAP_FIRSTNAME_ATTR", "givenName")
AUTH_LDAP_LASTNAME_FIELD = os.getenv("LOONAR_LDAP_LASTNAME_ATTR", "sn")
AUTH_LDAP_EMAIL_FIELD = os.getenv("LOONAR_LDAP_EMAIL_ATTR", "mail")
AUTH_LDAP_ALLOW_SELF_SIGNED = True
AUTH_LDAP_BIND_FIRST = False
AUTH_LDAP_TLS_DEMAND = False
AUTH_LDAP_TLS_CACERTDIR: str | None = None
AUTH_LDAP_TLS_CACERTFILE: str | None = None
AUTH_LDAP_TLS_CERTFILE: str | None = None
AUTH_LDAP_TLS_KEYFILE: str | None = None
AUTH_LDAP_APPEND_DOMAIN: str | None = None
AUTH_LDAP_USERNAME_FORMAT: str | None = None
AUTH_LDAP_SEARCH_FILTER: str | None = None
AUTH_LDAP_GROUP_FIELD = "memberOf"

# Nota: CUSTOM_SECURITY_MANAGER e SECURITY_LOGIN_TEMPLATE foram movidos
# para a seção de
# "CONFIGURAÇÃO DE AUTENTICAÇÃO - SELEÇÃO DO FORMULÁRIO DE LOGIN"
# acima, pois precisam ser condicionados pela variável SUPERSET_LOGIN_FORM_TYPE


# Ensure reCAPTCHA keys are always present in the config to avoid KeyError
RECAPTCHA_PUBLIC_KEY = os.environ.get("RECAPTCHA_PUBLIC_KEY", "")
RECAPTCHA_PRIVATE_KEY = os.environ.get("RECAPTCHA_PRIVATE_KEY", "")

SUPERSET_ENV = "production"

# Allowed host (used by some reverse proxy setups)
SUPERSET_HOST = os.environ.get("SUPERSET_HOST", "localhost")

# Database
DATABASE_DIALECT = os.environ.get("DATABASE_DIALECT", "postgresql")
DATABASE_USER = os.environ.get("DATABASE_USER", "superset")
DATABASE_PASSWORD = os.environ.get("DATABASE_PASSWORD", "")
DATABASE_HOST = os.environ.get("DATABASE_HOST", "db")
DATABASE_PORT = os.environ.get("DATABASE_PORT", "5432")
DATABASE_DB = os.environ.get("DATABASE_DB", "superset")
SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL") or (
    f"{DATABASE_DIALECT}://{DATABASE_USER}:{DATABASE_PASSWORD}"
    f"@{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_DB}"
)
SQLALCHEMY_TRACK_MODIFICATIONS = False
SQLALCHEMY_ENGINE_OPTIONS = {
    "pool_size": 10,
    "pool_recycle": 3600,
    "pool_pre_ping": True,
    "max_overflow": 20,
}

# Redis
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD", os.environ.get("REDIS_PASS", ""))
REDIS_CELERY_DB = int(os.environ.get("REDIS_CELERY_DB", 0))
REDIS_RESULTS_DB = int(os.environ.get("REDIS_RESULTS_DB", 1))

REDIS_URL = f"redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/{REDIS_CELERY_DB}"
REDIS_RESULTS_URL = (
    f"redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/{REDIS_RESULTS_DB}"
)

RESULTS_BACKEND = RedisCache(
    host=REDIS_HOST,
    port=REDIS_PORT,
    password=REDIS_PASSWORD or None,
    db=REDIS_RESULTS_DB,
    key_prefix="superset_results_",
)

# Cache
CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_REDIS_URL": (f"redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/2"),
}

DATA_CACHE_CONFIG = {
    **CACHE_CONFIG,
    "CACHE_DEFAULT_TIMEOUT": 3600,
    "CACHE_KEY_PREFIX": "superset_data_",
}


# Celery
class CeleryConfig:
    broker_url = REDIS_URL
    imports = ("superset.sql_lab", "superset.tasks.scheduler")
    result_backend = REDIS_RESULTS_URL
    worker_prefetch_multiplier = 1
    task_acks_late = True
    task_annotations = {
        "sql_lab.get_sql_results": {"rate_limit": "100/s"},
        "email_reports.send": {
            "rate_limit": "1/s",
            "time_limit": 120,
            "soft_time_limit": 150,
        },
    }
    beat_schedule = {
        "reports.scheduler": {
            "task": "reports.scheduler",
            "schedule": crontab(minute="*", hour="*"),
        },
        "reports.prune_log": {
            "task": "reports.prune_log",
            "schedule": crontab(minute=0, hour=0),
        },
    }


CELERY_CONFIG = CeleryConfig

# Static assets / CDN support
STATIC_ASSETS_PREFIX = os.environ.get("STATIC_ASSETS_PREFIX", "").rstrip("/")


def _parse_extra_csp_hosts() -> set[str]:
    hosts: set[str] = set()
    if asset_prefix := STATIC_ASSETS_PREFIX:
        parsed = urlparse(asset_prefix)
        if parsed.scheme and parsed.netloc:
            hosts.add(f"{parsed.scheme}://{parsed.netloc}")

    extra_hosts = os.environ.get("CSP_ADDITIONAL_HOSTS", "")
    for host in (value.strip() for value in extra_hosts.split(",")):
        if host:
            hosts.add(host)

    return hosts


def _extend_csp_sources(base_sources: list[str]) -> list[str]:
    extra_hosts = _parse_extra_csp_hosts()
    extras = [host for host in extra_hosts if host not in base_sources]
    return base_sources + extras if extras else base_sources


# Security Settings
GOOGLE_FONTS_STYLE_SRC = "https://fonts.googleapis.com"
GOOGLE_FONTS_FONT_SRC = "https://fonts.gstatic.com"

TALISMAN_ENABLED = True
TALISMAN_CONFIG = {
    "content_security_policy": {
        "default-src": _extend_csp_sources(["'self'"]),
        "img-src": _extend_csp_sources(["'self'", "data:", "https:"]),
        "script-src": _extend_csp_sources(
            ["'self'", "'unsafe-inline'", "'unsafe-eval'"]
        ),
        "style-src": _extend_csp_sources(
            ["'self'", "'unsafe-inline'", GOOGLE_FONTS_STYLE_SRC]
        ),
        "font-src": _extend_csp_sources(["'self'", "data:", GOOGLE_FONTS_FONT_SRC]),
    },
    "force_https": True,
    "force_https_permanent": True,
    "strict_transport_security": True,
    "strict_transport_security_max_age": 31536000,
    "strict_transport_security_include_subdomains": True,
    "strict_transport_security_preload": True,
}

# CORS
enable_cors = os.environ.get("ENABLE_CORS", "false").lower() == "true"
ENABLE_CORS = enable_cors
CORS_OPTIONS: dict[str, Any] = {}

# Feature Flags
FEATURE_FLAGS = {
    "ALERT_REPORTS": True,
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "DASHBOARD_RBAC": True,
    "EMBEDDABLE_CHARTS": True,
    "ENABLE_TEMPLATE_PROCESSING": True,
    "SCHEDULED_QUERIES": True,
    "SQL_VALIDATORS_BY_ENGINE": True,
    "THUMBNAILS": True,
    "THUMBNAILS_SQLA_LISTENERS": True,
    "ENABLE_FLASK_LOGIN": True,
    "DISABLE_REACT_LOGIN": True,
}

# WebDriver for thumbnails/alerts
WEBDRIVER_TYPE = os.environ.get("WEBDRIVER_TYPE", "chrome")
WEBDRIVER_OPTION_ARGS = [
    "--force-device-scale-factor=2.0",
    "--high-dpi-support=2.0",
    "--headless",
    "--disable-gpu",
    "--disable-dev-shm-usage",
    "--no-sandbox",
    "--disable-setuid-sandbox",
    "--disable-extensions",
]

# Alerts and Reports
ALERT_REPORTS_NOTIFICATION_DRY_RUN = False
SCREENSHOT_SELENIUM_USER = os.environ.get("SCREENSHOT_SELENIUM_USER", "admin")

# Email
SMTP_HOST = os.environ.get("SMTP_HOST")
SMTP_PORT = int(os.environ.get("SMTP_PORT", 587))
SMTP_STARTTLS = os.environ.get("SMTP_STARTTLS", "True").lower() == "true"
SMTP_SSL = os.environ.get("SMTP_SSL", "False").lower() == "true"
SMTP_USER = os.environ.get("SMTP_USER")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD")
SMTP_MAIL_FROM = os.environ.get("SMTP_MAIL_FROM", "superset@example.com")

EMAIL_NOTIFICATIONS = bool(SMTP_HOST)

# Logging
ENABLE_TIME_ROTATE = True
_log_level = os.environ.get("SUPERSET_LOG_LEVEL", "INFO")
LOG_LEVEL = _log_level.upper() if isinstance(_log_level, str) else _log_level
LOG_FORMAT = "%(asctime)s:%(levelname)s:%(name)s:%(message)s"

# Session
# Tempo máximo de inatividade antes de expirar a sessão (em minutos)
# Configura via variável de ambiente AUTH_SESSION_TIMEOUT (padrão: 20 minutos)
_session_timeout_minutes = int(os.environ.get("AUTH_SESSION_TIMEOUT", "20"))
PERMANENT_SESSION_LIFETIME = timedelta(minutes=_session_timeout_minutes)
# Revalida o timeout a cada request para manter expiração por inatividade
SESSION_REFRESH_EACH_REQUEST = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_SAMESITE = "Lax"

# WTF CSRF
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None
WTF_CSRF_SSL_STRICT = True

# Application
ROW_LIMIT = 50000
VIZ_ROW_LIMIT = 10000
SAMPLES_ROW_LIMIT = 1000
FILTER_SELECT_ROW_LIMIT = 10000

# SQL Lab
SQLLAB_ASYNC_TIME_LIMIT_SEC = 300
SQLLAB_TIMEOUT = 300
SUPERSET_WEBSERVER_TIMEOUT = 300

# Performance
COMPRESS_REGISTER = True

# Public role restrictions
PUBLIC_ROLE_LIKE: Optional[str] = None

# Additional security headers
HTTP_HEADERS = {
    "X-Frame-Options": "SAMEORIGIN",
}

# Mapbox (if needed)
MAPBOX_API_KEY = os.environ.get("MAPBOX_API_KEY", "")

# ------------------------------------------------------------------
# Loonar branding (logos + theming)
# ------------------------------------------------------------------
_BRAND_LOGO_BASE = "/static/assets/images/loonar"
# SVG = nítido em qualquer DPI (preferido para header/branding HPE-style)
_LIGHT_LOGO_PATH = f"{_BRAND_LOGO_BASE}/logo-light.svg"
_DARK_LOGO_PATH = f"{_BRAND_LOGO_BASE}/logo-dark.svg"
_FAVICON_PATH = f"{_BRAND_LOGO_BASE}/favicon.svg"
# Fallbacks PNG (mantidos para clientes/exportações que não renderizam SVG)
_LIGHT_LOGO_PNG = f"{_BRAND_LOGO_BASE}/logo-light.png"

APP_NAME = os.environ.get("APP_NAME", "Loonar FinOps")
APP_ICON = _LIGHT_LOGO_PATH
LOGO_TOOLTIP = "Loonar FinOps - Powered by Superset"

FAVICONS = [{"href": _FAVICON_PATH}]

# THEME_DEFAULT: dict[str, Any] = {
#     "token": {
#         "brandLogoUrl": _LIGHT_LOGO_PATH,
#         "brandLogoAlt": "Loonar FinOps",
#         "brandLogoHeight": "40px",
#     }
# }

# THEME_DARK: dict[str, Any] = {
#     "token": {
#         "brandLogoUrl": _DARK_LOGO_PATH,
#         "brandLogoAlt": "Loonar FinOps",
#         "brandLogoHeight": "40px",
#     }
# }


ENABLE_UI_THEME_ADMINISTRATION = True

THEME_DEFAULT = {
    "token": {
        "brandAppName": "Loonar FinOps",
        "brandLogoAlt": "Loonar FinOps",
        "brandLogoUrl": _LIGHT_LOGO_PATH,
        "brandLogoHref": "/",
        "brandLogoHeight": "28px",
        "brandLogoMargin": "16px 0 18px 0",
        # MetricHPE é proprietária HPE; usamos Metropolis (Google Fonts)
        # como substituta web livre estilisticamente próxima ao design HPE Morpheus.
        "fontUrls": [
            "https://fonts.googleapis.com/css2?family=Metropolis:wght@400;500;600;700&display=swap",
            "https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&display=swap"
        ],
        "fontFamily": "'Metropolis', 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif",
        "fontFamilyCode": "'IBM Plex Mono', 'Courier New', monospace",

        "colorPrimary": "#01A982",
        "colorLink": "#01A982",
        "colorSuccess": "#01A982",
        "colorInfo": "#01A982",
        "colorWarning": "#F6C343",
        "colorError": "#E85D75",

        "colorTextBase": "#111827",
        "colorText": "#111827",
        "colorTextSecondary": "#4B5563",
        "colorTextTertiary": "#6B7280",
        "colorTextQuaternary": "#9CA3AF",

        "colorBgBase": "#F7F9FB",
        "colorBgLayout": "#F5F7FA",
        "colorBgContainer": "#FFFFFF",
        "colorBgElevated": "#FCFCFD",
        "colorFillAlter": "#F1F5F9",

        "colorBorder": "#D9E1E8",
        "colorBorderSecondary": "#E7EDF3",

        "borderRadius": 8,
        "wireframe": False,

        "fontSize": 14,
        "sizeUnit": 4
    },
    "components": {
        "Layout": {
            "bodyBg": "#F5F7FA",
            "headerBg": "#FFFFFF",
            "siderBg": "#FFFFFF",
            "triggerBg": "#F7F9FB",
            "triggerColor": "#111827"
        },
        "Menu": {
            "itemBg": "#FFFFFF",
            "subMenuItemBg": "#FCFCFD",
            "itemColor": "#4B5563",
            "itemHoverColor": "#111827",
            "itemHoverBg": "rgba(1,169,130,0.08)",
            "itemSelectedColor": "#016B53",
            "itemSelectedBg": "rgba(1,169,130,0.14)",
            "itemBorderRadius": 6
        },
        "Button": {
            "primaryColor": "#FFFFFF",
            "defaultBg": "#FFFFFF",
            "defaultBorderColor": "#D9E1E8",
            "defaultColor": "#111827",
            "defaultHoverBg": "#F9FBFC",
            "defaultHoverBorderColor": "#01A982",
            "defaultHoverColor": "#016B53",
            "defaultActiveBg": "#F3F8F6",
            "defaultActiveBorderColor": "#01A982",
            "defaultActiveColor": "#016B53",
            "borderRadius": 8
        },
        "Input": {
            "colorBgContainer": "#FFFFFF",
            "colorBorder": "#D9E1E8",
            "hoverBorderColor": "#01A982",
            "activeBorderColor": "#01A982",
            "activeShadow": "0 0 0 2px rgba(1,169,130,0.14)",
            "colorText": "#111827",
            "colorTextPlaceholder": "#9CA3AF"
        },
        "Card": {
            "colorBgContainer": "#FFFFFF",
            "headerBg": "#FFFFFF",
            "colorBorderSecondary": "#E7EDF3"
        },
        "Tabs": {
            "itemColor": "#6B7280",
            "itemSelectedColor": "#016B53",
            "itemHoverColor": "#111827",
            "inkBarColor": "#01A982"
        },
        "Table": {
            "headerBg": "#F9FAFB",
            "headerColor": "#111827",
            "rowHoverBg": "rgba(1,169,130,0.05)",
            "borderColor": "#E7EDF3"
        }
    },
    "echartsOptionsOverrides": {
        "color": [
            "#01A982",
            "#2D9CDB",
            "#F6C343",
            "#E85D75",
            "#7C5CFC",
            "#7F8C8D",
            "#16A34A",
            "#F97316"
        ],
        "backgroundColor": "transparent",
        "textStyle": {
            "fontFamily": "Metropolis, Inter, Arial, sans-serif",
            "color": "#111827"
        },
        "title": {
            "textStyle": {
                "color": "#111827",
                "fontWeight": 600
            },
            "subtextStyle": {
                "color": "#6B7280"
            }
        },
        "legend": {
            "textStyle": {
                "color": "#4B5563",
                "fontFamily": "Metropolis, Inter, Arial, sans-serif"
            }
        },
        "grid": {
            "left": "6%",
            "right": "4%",
            "top": "12%",
            "bottom": "10%",
            "containLabel": True
        },
        "tooltip": {
            "backgroundColor": "rgba(17,24,39,0.96)",
            "borderColor": "#01A982",
            "textStyle": {
                "color": "#FFFFFF",
                "fontFamily": "Metropolis, Inter, Arial, sans-serif"
            }
        },
        "xAxis": {
            "axisLine": {
                "lineStyle": {
                    "color": "#CBD5E1"
                }
            },
            "axisLabel": {
                "color": "#6B7280",
                "fontFamily": "Metropolis, Inter, Arial, sans-serif"
            },
            "splitLine": {
                "lineStyle": {
                    "color": "#EEF2F7"
                }
            }
        },
        "yAxis": {
            "axisLine": {
                "lineStyle": {
                    "color": "#CBD5E1"
                }
            },
            "axisLabel": {
                "color": "#6B7280",
                "fontFamily": "Metropolis, Inter, Arial, sans-serif"
            },
            "splitLine": {
                "lineStyle": {
                    "color": "#EEF2F7"
                }
            }
        }
    },
    "echartsOptionsOverridesByChartType": {
        "echarts_timeseries": {
            "xAxis": {
                "axisLabel": {
                    "fontSize": 11
                }
            },
            "dataZoom": [
                {
                    "type": "inside",
                    "start": 0,
                    "end": 100
                }
            ]
        },
        "echarts_pie": {
            "legend": {
                "orient": "vertical",
                "right": 10,
                "top": "center",
                "textStyle": {
                    "fontSize": 12
                }
            }
        },
        "echarts_gauge": {
            "title": {
                "color": "#4B5563"
            },
            "detail": {
                "color": "#111827"
            }
        }
    }
}

THEME_DARK = {
    "algorithm": "dark",
    "token": {
        "brandAppName": "Loonar FinOps",
        "brandLogoAlt": "Loonar FinOps",
        "brandLogoUrl": _DARK_LOGO_PATH,
        "brandLogoHref": "/",
        "brandLogoHeight": "28px",
        "brandLogoMargin": "16px 0 18px 0",
        "fontUrls": [
            "https://fonts.googleapis.com/css2?family=Metropolis:wght@400;500;600;700&display=swap",
            "https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&display=swap"
        ],
        "fontFamily": "'Metropolis', 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif",
        "fontFamilyCode": "'IBM Plex Mono', 'Courier New', monospace",

        "colorPrimary": "#01A982",
        "colorLink": "#01A982",
        "colorSuccess": "#01A982",
        "colorInfo": "#01A982",
        "colorWarning": "#F6C343",
        "colorError": "#E85D75",

        "colorTextBase": "#F3F6F9",
        "colorText": "#F3F6F9",
        "colorTextSecondary": "#B8C2CC",
        "colorTextTertiary": "#8A97A6",
        "colorTextQuaternary": "#667281",

        "colorBgBase": "#0B0F14",
        "colorBgLayout": "#0B0F14",
        "colorBgContainer": "#121820",
        "colorBgElevated": "#161D26",
        "colorFillAlter": "#1A222D",

        "colorBorder": "#2A3441",
        "colorBorderSecondary": "#1D2630",

        "borderRadius": 8,
        "wireframe": False,

        "fontSize": 14,
        "sizeUnit": 4
    },
    "components": {
        "Layout": {
            "bodyBg": "#0B0F14",
            "headerBg": "#0F141A",
            "siderBg": "#0F141A",
            "triggerBg": "#121820",
            "triggerColor": "#F3F6F9"
        },
        "Menu": {
            "darkItemBg": "#0F141A",
            "darkSubMenuItemBg": "#121820",
            "darkItemColor": "#B8C2CC",
            "darkItemHoverColor": "#FFFFFF",
            "darkItemHoverBg": "rgba(1,169,130,0.10)",
            "darkItemSelectedColor": "#FFFFFF",
            "darkItemSelectedBg": "#01A982",
            "itemBorderRadius": 6
        },
        "Button": {
            "primaryColor": "#08110E",
            "defaultBg": "#161D26",
            "defaultBorderColor": "#2A3441",
            "defaultColor": "#F3F6F9",
            "defaultHoverBg": "#1B2430",
            "defaultHoverBorderColor": "#01A982",
            "defaultHoverColor": "#01A982",
            "defaultActiveBg": "#121820",
            "defaultActiveBorderColor": "#01A982",
            "defaultActiveColor": "#01A982",
            "borderRadius": 8
        },
        "Input": {
            "colorBgContainer": "#121820",
            "colorBorder": "#2A3441",
            "hoverBorderColor": "#01A982",
            "activeBorderColor": "#01A982",
            "activeShadow": "0 0 0 2px rgba(1,169,130,0.18)",
            "colorText": "#F3F6F9",
            "colorTextPlaceholder": "#667281"
        },
        "Card": {
            "colorBgContainer": "#121820",
            "headerBg": "#121820",
            "colorBorderSecondary": "#1D2630"
        },
        "Tabs": {
            "itemColor": "#8A97A6",
            "itemSelectedColor": "#01A982",
            "itemHoverColor": "#FFFFFF",
            "inkBarColor": "#01A982"
        },
        "Table": {
            "headerBg": "#161D26",
            "headerColor": "#F3F6F9",
            "rowHoverBg": "rgba(1,169,130,0.06)",
            "borderColor": "#1D2630"
        }
    },
    "echartsOptionsOverrides": {
        "color": [
            "#01A982",
            "#56CCF2",
            "#F6C343",
            "#E85D75",
            "#A78BFA",
            "#94A3B8",
            "#22C55E",
            "#FB923C"
        ],
        "backgroundColor": "transparent",
        "textStyle": {
            "fontFamily": "Metropolis, Inter, Arial, sans-serif",
            "color": "#F3F6F9"
        },
        "title": {
            "textStyle": {
                "color": "#F3F6F9",
                "fontWeight": 600
            },
            "subtextStyle": {
                "color": "#8A97A6"
            }
        },
        "legend": {
            "textStyle": {
                "color": "#B8C2CC",
                "fontFamily": "Metropolis, Inter, Arial, sans-serif"
            }
        },
        "grid": {
            "left": "6%",
            "right": "4%",
            "top": "12%",
            "bottom": "10%",
            "containLabel": True
        },
        "tooltip": {
            "backgroundColor": "rgba(15,20,26,0.96)",
            "borderColor": "#01A982",
            "textStyle": {
                "color": "#F3F6F9",
                "fontFamily": "Metropolis, Inter, Arial, sans-serif"
            }
        },
        "xAxis": {
            "axisLine": {
                "lineStyle": {
                    "color": "#344150"
                }
            },
            "axisLabel": {
                "color": "#8A97A6",
                "fontFamily": "Metropolis, Inter, Arial, sans-serif"
            },
            "splitLine": {
                "lineStyle": {
                    "color": "#1D2630"
                }
            }
        },
        "yAxis": {
            "axisLine": {
                "lineStyle": {
                    "color": "#344150"
                }
            },
            "axisLabel": {
                "color": "#8A97A6",
                "fontFamily": "Metropolis, Inter, Arial, sans-serif"
            },
            "splitLine": {
                "lineStyle": {
                    "color": "#1D2630"
                }
            }
        }
    },
    "echartsOptionsOverridesByChartType": {
        "echarts_timeseries": {
            "xAxis": {
                "axisLabel": {
                    "fontSize": 11
                }
            },
            "dataZoom": [
                {
                    "type": "inside",
                    "start": 0,
                    "end": 100
                }
            ]
        },
        "echarts_pie": {
            "legend": {
                "orient": "vertical",
                "right": 10,
                "top": "center",
                "textStyle": {
                    "fontSize": 12
                }
            }
        },
        "echarts_gauge": {
            "title": {
                "color": "#B8C2CC"
            },
            "detail": {
                "color": "#F3F6F9"
            }
        }
    }
}


# ------------------------------------------------------------------
# Configuração de moedas disponíveis no dropdown do frontend
# ------------------------------------------------------------------
CURRENCIES = [
    "USD",
    "GBP",
    "JPY",
    "EUR",
    "INR",
    "CNY",
    "MXN",
    "BRL",
]

# ------------------------------------------------------------------
# D3 Format - Configuração de formatação de moedas
# ------------------------------------------------------------------
# Garante que a lista de moedas seja adicionada sem sobrescrever as
# chaves numéricas (por exemplo: decimal, thousands) definidas acima.
# Utilizamos a lista `CURRENCIES` definida mais acima para evitar duplicação.
D3_FORMAT.setdefault("CURRENCIES", [
    {"symbol": "$", "name": "USD", "symbolPosition": "prefix"},
    {"symbol": "£", "name": "GBP", "symbolPosition": "prefix"},
    {"symbol": "¥", "name": "JPY", "symbolPosition": "prefix"},
    {"symbol": "€", "name": "EUR", "symbolPosition": "prefix"},
    {"symbol": "₹", "name": "INR", "symbolPosition": "prefix"},
    {"symbol": "CN¥", "name": "CNY", "symbolPosition": "prefix"},
    {"symbol": "MX$", "name": "MXN", "symbolPosition": "prefix"},
    {"symbol": "R$", "name": "BRL", "symbolPosition": "prefix"},
])
