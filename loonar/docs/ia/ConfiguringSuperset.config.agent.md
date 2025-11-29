# Superset General Configuration Agent Mode

## Overview
Centralizes all Superset configuration via `superset_config.py` or environment variables. Manages secrets, database URIs, feature flags, and Flask extensions.

## Key Configurations & Variables
- `SUPERSET_CONFIG_PATH` (path to config file)
- `SECRET_KEY` / `SUPERSET_SECRET_KEY` (app secret)
- `SQLALCHEMY_DATABASE_URI` (metadata DB)
- `ROW_LIMIT`, `WTF_CSRF_ENABLED`, `WTF_CSRF_EXEMPT_LIST`
- `FEATURE_FLAGS` (enable/disable features)
- `MAPBOX_API_KEY` (map visualizations)
- `AUTH_TYPE`, `OAUTH_PROVIDERS`, `AUTH_USER_REGISTRATION`, `AUTH_USER_REGISTRATION_ROLE`

## Best Practices
- Always set a strong, unique `SECRET_KEY` for production
- Use PostgreSQL/MySQL for metadata DB (not SQLite)
- Store secrets in `.env` and automate rotation
- Use feature flags for modular enablement
- Mount config file via Docker Compose for overrides

## Docker Compose Integration
- Mount custom `superset_config.py`
- Use `.env` for all secrets and DB URIs
- Validate health at `/health` endpoint

## Security & Automation Notes
- Rotate `SECRET_KEY` and DB passwords regularly
- Use RBAC and feature flags for access control
- Validate config loading and permissions
