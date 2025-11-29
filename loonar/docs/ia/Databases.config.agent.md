# Superset Databases Configuration Agent Mode

## Overview
Automates connection and management of supported databases in Superset. Handles driver installation, connection strings, and secure credential storage.

## Key Configurations & Variables
- `SQLALCHEMY_DATABASE_URI` (metadata DB)
- Database-specific connection strings (see docs)
- `requirements-local.txt` (driver installation)
- `SQLALCHEMY_CUSTOM_PASSWORD_STORE` (external password store)
- `FEATURE_FLAGS` (enable meta database)

## Best Practices
- Use official drivers and dialects for each DB
- Store credentials in environment variables or external stores
- Use secure connection strings (SSL, encrypted passwords)
- Validate DB connectivity via UI and CLI
- Automate driver installation via Docker Compose

## Docker Compose Integration
- Add required drivers to `docker/requirements-local.txt`
- Use `.env` for DB credentials
- Mount custom config for password store

## Security & Automation Notes
- Rotate DB passwords and API keys
- Restrict access to sensitive connection info
- Monitor DB logs for errors and permission issues
