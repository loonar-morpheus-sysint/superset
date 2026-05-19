# Configuration Guide - Loonar Superset 6.0

Environment variables and configuration settings for Loonar-customized Apache Superset 6.0.

## Environment Variables

### Core Superset Configuration

```bash
# Flask environment
FLASK_ENV=production              # production, development, testing
SUPERSET_ENV=production           # Superset-specific environment
SECRET_KEY=your-secret-key-min-32  # Minimum 32 characters, use openssl rand -hex 16

# Admin user
SUPERSET_ADMIN_USER=admin
SUPERSET_ADMIN_PASSWORD=secure-password
```

### Database Configuration

```bash
# PostgreSQL database
DATABASE_URL=postgresql://superset:password@localhost:5432/superset
SQLALCHEMY_POOL_SIZE=10
SQLALCHEMY_POOL_RECYCLE=3600
SQLALCHEMY_MAX_OVERFLOW=20
```

### Redis Cache Configuration

```bash
# Redis server for caching and session storage
REDIS_URL=redis://localhost:6379/0
REDIS_PASSWORD=redis-password-if-needed
CACHE_TYPE=redis
CACHE_REDIS_URL=redis://localhost:6379/1
```

### LDAP Authentication (if enabled)

```bash
# LDAP configuration for user authentication
LDAP_ENABLED=true
LDAP_SERVER=ldap://ldap.example.com:389
LDAP_BIND_DN=cn=admin,dc=example,dc=com
LDAP_BIND_PASSWORD=ldap-bind-password
LDAP_BASE_DN=ou=users,dc=example,dc=com
LDAP_USER_FILTER=(uid={})
LDAP_GROUP_FILTER=(cn=*)

# LDAP role mapping (custom)
LDAP_ADMIN_GROUP=superset-admins
LDAP_USER_GROUP=superset-users
LDAP_AUTO_CREATE_USERS=true
```

### Email Configuration

```bash
# SMTP settings for email alerts and notifications
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=app-specific-password
MAIL_USE_TLS=true
MAIL_USE_SSL=false
MAIL_DEFAULT_SENDER=superset@example.com
```

### Morpheus Data Integration

```bash
# Morpheus Data API credentials
MORPHEUS_ENABLED=true
MORPHEUS_API_KEY=your-api-key
MORPHEUS_API_URL=https://morpheus.example.com/api
MORPHEUS_TENANT_ID=your-tenant-id
MORPHEUS_SYNC_INTERVAL=3600  # seconds
```

### Logging Configuration

```bash
# Logging levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_LEVEL=INFO
SUPERSET_LOG_LEVEL=INFO

# Log files
LOG_FILE=/var/log/superset/superset.log
ACCESS_LOG_FILE=/var/log/superset/access.log
```

### Security Configuration

```bash
# SSL/TLS
SUPERSET_ENABLE_SSL=true
SSL_CERT_PATH=/path/to/cert.pem
SSL_KEY_PATH=/path/to/key.pem

# Security headers
TALISMAN_ENABLED=true
ENFORCE_HTTPS=true

# Session configuration
PERMANENT_SESSION_LIFETIME=3600
SESSION_COOKIE_SECURE=true
SESSION_COOKIE_HTTPONLY=true
SESSION_COOKIE_SAMESITE=Lax
```

## Configuration File (.env.example)

```bash
# Copy to .env and customize
cp .env.example .env
nano .env
```

## Superset Configuration Class

The `superset_config.py` file controls advanced Superset settings:

```python
# docker/pythonpath_dev/superset_config.py
import os

# Flask
FLASK_ENV = os.environ.get("FLASK_ENV", "production")
SECRET_KEY = os.environ.get("SECRET_KEY", "change-me")

# Database
SQLALCHEMY_DATABASE_URI = os.environ.get(
    "DATABASE_URL",
    "postgresql://superset:superset@localhost/superset"
)

# Redis
CACHE_CONFIG = {
    "CACHE_TYPE": "redis",
    "CACHE_REDIS_URL": os.environ.get("REDIS_URL", "redis://localhost:6379/0"),
}

# Feature flags
FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
    "VERSIONED_EXPORT": True,
    "ALERT_REPORTS": True,
}
```

## Docker Environment File (.env)

For Docker Compose deployment, use `.env`:

```bash
# Server
SUPERSET_ENV=production
SECRET_KEY=$(openssl rand -hex 16)

# Database
DB_USER=superset
DB_PASSWORD=secure-password
DB_NAME=superset
DB_PORT=5432

# Redis
REDIS_PASSWORD=redis-secure-password

# LDAP (optional)
LDAP_ENABLED=true
LDAP_SERVER=ldap://ldap.example.com:389

# Morpheus Data (optional)
MORPHEUS_ENABLED=true
MORPHEUS_API_KEY=your-api-key
```

## Configuration Override

Create `docker-compose.override.yml` for environment-specific settings:

```yaml
version: '3'
services:
  superset:
    environment:
      - SUPERSET_ENV=staging
      - LOG_LEVEL=DEBUG
      - LDAP_ENABLED=false
    volumes:
      - ./custom_config:/app/custom_config
```

## Customization Examples

### LDAP with Role Auto-Provisioning

```python
# Enable in superset_config.py
AUTH_TYPE = AUTH_LDAP
AUTH_LDAP_SERVER = "ldap://ldap.example.com"
AUTH_LDAP_TLS_DEMAND = False
AUTH_LDAP_SEARCH = "ou=users,dc=example,dc=com"
AUTH_LDAP_UID_FIELD = "uid"
AUTH_LDAP_FIRSTNAME_FIELD = "givenName"
AUTH_LDAP_LASTNAME_FIELD = "sn"
AUTH_LDAP_EMAIL_FIELD = "mail"
AUTH_LDAP_BIND_USER = "cn=admin,dc=example,dc=com"
AUTH_LDAP_BIND_PASSWORD = "password"

# Role mapping
AUTH_LDAP_GROUP_FIELD = "cn"
AUTH_LDAP_GROUP_MEMBER_FIELD = "memberUid"
AUTH_LDAP_GROUP_ROLE_MAPPING = {
    "superset-admins": ["Admin"],
    "superset-users": ["Alpha"],
}
```

### Morpheus Data Integration

```python
# Enable in superset_config.py
MORPHEUS_API_ENABLED = True
MORPHEUS_API_KEY = os.environ.get("MORPHEUS_API_KEY")
MORPHEUS_API_URL = os.environ.get("MORPHEUS_API_URL")

# Database discovery from Morpheus Data
SQLALCHEMY_TRACK_MODIFICATIONS = False
SQLALCHEMY_ECHO = False
```

## Validation

After configuration changes:

1. Verify environment variables: `docker-compose exec superset env | grep SUPERSET`
2. Check logs: `docker-compose logs -f superset`
3. Test connectivity: `docker-compose exec superset python -c "from superset import db; db.session.execute('SELECT 1')"`
4. Restart services: `docker-compose restart superset`

## Troubleshooting

### Database Connection Errors
```bash
# Verify DATABASE_URL format
echo $DATABASE_URL
# Format: postgresql://user:password@host:port/database

# Test connection
psql $DATABASE_URL -c "SELECT 1"
```

### LDAP Connection Errors
```bash
# Test LDAP connectivity
ldapsearch -H ldap://ldap.example.com -x -D "cn=admin,dc=example,dc=com" -w password

# Check LDAP configuration
docker-compose exec superset cat /app/pythonpath/superset_config.py | grep -i ldap
```

### Redis Connection Errors
```bash
# Test Redis connectivity
redis-cli -u $REDIS_URL PING

# Should return: PONG
```

## Default Credentials

After initial setup, access Superset with:
- URL: http://localhost:8088
- Username: (value of SUPERSET_ADMIN_USER)
- Password: (value of SUPERSET_ADMIN_PASSWORD)

**Change default credentials on first login!**

## References

- Apache Superset Configuration: https://superset.apache.org/docs/installation/configuring-superset
- Superset Configuration Class: https://github.com/apache/superset/blob/master/superset/config.py
- Morpheus Data API: https://morpheus.example.com/api/docs
