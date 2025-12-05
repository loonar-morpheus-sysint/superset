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

import os
from datetime import timedelta
from typing import Any, Optional
from urllib.parse import urlparse

from cachelib.redis import RedisCache
from celery.schedules import crontab

# Security
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY") or os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    raise ValueError("SECRET_KEY must be set in production")

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
SQLALCHEMY_DATABASE_URI = (
    os.environ.get("DATABASE_URL")
    or f"{DATABASE_DIALECT}://{DATABASE_USER}:{DATABASE_PASSWORD}@{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_DB}"
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
    "CACHE_REDIS_URL": f"redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/2",
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
TALISMAN_ENABLED = True
TALISMAN_CONFIG = {
    "content_security_policy": {
        "default-src": _extend_csp_sources(["'self'"]),
        "img-src": _extend_csp_sources(["'self'", "data:", "https:"]),
        "script-src": _extend_csp_sources(
            ["'self'", "'unsafe-inline'", "'unsafe-eval'"]
        ),
        "style-src": _extend_csp_sources(["'self'", "'unsafe-inline'"]),
        "font-src": _extend_csp_sources(["'self'", "data:"]),
    },
    "force_https": True,
    "force_https_permanent": True,
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
PERMANENT_SESSION_LIFETIME = timedelta(days=1)
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
_LIGHT_LOGO_PATH = f"{_BRAND_LOGO_BASE}/logo-light.png"
_DARK_LOGO_PATH = f"{_BRAND_LOGO_BASE}/logo-dark.png"

APP_NAME = os.environ.get("APP_NAME", "Loonar FinOps")
APP_ICON = _LIGHT_LOGO_PATH
LOGO_TOOLTIP = "Loonar FinOps - Powered by Superset"

FAVICONS = [{"href": _LIGHT_LOGO_PATH}]

THEME_DEFAULT: dict[str, Any] = {
    "token": {
        "brandLogoUrl": _LIGHT_LOGO_PATH,
        "brandLogoAlt": "Loonar FinOps",
        "brandLogoHeight": "40px",
    }
}

THEME_DARK: dict[str, Any] = {
    "token": {
        "brandLogoUrl": _DARK_LOGO_PATH,
        "brandLogoAlt": "Loonar FinOps",
        "brandLogoHeight": "40px",
    }
}
