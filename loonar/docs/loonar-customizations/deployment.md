# Deployment Guide - Loonar Superset 6.0

Complete step-by-step guide for deploying Loonar-customized Apache Superset 6.0 to various environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment Methods](#deployment-methods)
- [Development](#development)
- [Staging](#staging)
- [Production](#production)
- [Troubleshooting](#troubleshooting)
- [Rollback Procedures](#rollback-procedures)

---

## Prerequisites

### System Requirements

- **OS**: Linux (Ubuntu 22.04 LTS or 24.04 LTS recommended)
- **Docker**: 20.10+
- **Docker Compose**: 2.10+
- **Git**: 2.30+
- **Python**: 3.10+ (for local development)
- **Node.js**: 16+ (for UI development)

### Access Requirements

- GitHub access to `loonar-morpheus-sysint/superset`
- Server credentials for target environment
- Registry access for container images (if using private registry)
- Database credentials and connectivity

### Network Requirements

- Port 8088: Superset application (configurable)
- Port 5432: PostgreSQL database (if local)
- Port 6379: Redis cache (if local)
- SSH access for deployment (if remote)

---

## Deployment Methods

### Method 1: Docker Compose (Recommended)

Fastest and most consistent deployment method using Docker Compose.

#### 1.1 Initial Setup

```bash
# Clone repository
git clone https://github.com/loonar-morpheus-sysint/superset.git
cd superset

# Checkout branch
git checkout 6.0

# Copy override template
cp docs/loonar-customizations/templates/docker-compose.override.yml .

# Create environment file
cp .env.example .env

# Edit configuration
nano .env
```

#### 1.2 Environment Configuration

Update `.env` file with your environment-specific settings:

```env
# Superset Configuration
SUPERSET_ENV=production
SUPERSET_SECRET_KEY=your-secret-key-here-min-32-chars
SUPERSET_ADMIN_USER=admin
SUPERSET_ADMIN_PASSWORD=secure-password

# Database
DATABASE_URL=postgresql://user:password@db:5432/superset
REDIS_URL=redis://redis:6379/0

# LDAP Configuration (if enabled)
LDAP_ENABLED=true
LDAP_SERVER=ldap://your-ldap-server:389
LDAP_BIND_DN=cn=admin,dc=example,dc=com
LDAP_BIND_PASSWORD=ldap-password

# Morpheus Data Integration
MORPHEUS_API_KEY=your-morpheus-api-key
MORPHEUS_API_URL=https://your-morpheus-instance/api

# Email Configuration
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
```

#### 1.3 Build and Deploy

```bash
# Build images
docker-compose build

# Start services in background
docker-compose up -d

# Verify services are running
docker-compose ps

# View logs
docker-compose logs -f superset

# Wait for database initialization
docker-compose logs superset | grep "Superset is ready"
```

#### 1.4 Post-Deployment Verification

```bash
# Check application health
curl http://localhost:8088/health

# Login to test
# Navigate to http://localhost:8088
# Use admin credentials from .env
```

### Method 2: Kubernetes Deployment

For production environments using Kubernetes.

```bash
# Create namespace
kubectl create namespace superset

# Create secrets
kubectl create secret generic superset-config \
  --from-file=superset_config.py \
  -n superset

# Deploy
kubectl apply -f k8s/
kubectl rollout status deployment/superset -n superset

# Port forward for testing
kubectl port-forward svc/superset 8088:80 -n superset
```

### Method 3: Manual Installation

For custom environments or development.

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Database initialization
superset db upgrade

# Load default data
superset load_examples

# Create admin user
superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@example.com \
  --password admin

# Initialize roles and permissions
superset init

# Run development server
superset run -p 8088 --with-threads --reload
```

---

## Environment-Specific Deployments

### Development

```bash
# Use docker-compose with development overrides
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Enable hot-reload and debugging
export FLASK_ENV=development
export FLASK_DEBUG=1

# Run with debug logging
superset run --debug
```

### Staging

```bash
# Backup production data first
./docs/loonar-customizations/scripts/backup-config.sh staging

# Deploy staging environment
ENVIRONMENT=staging docker-compose up -d

# Run smoke tests
./tests/smoke-tests.sh staging

# Monitor for issues
docker-compose logs -f
```

### Production

```bash
# ALWAYS backup before production deployment
./docs/loonar-customizations/scripts/backup-config.sh production

# Run pre-deployment checks
./docs/loonar-customizations/scripts/pre-deploy-checks.sh

# Deploy production environment
ENVIRONMENT=production docker-compose up -d

# Verify deployment
./docs/loonar-customizations/scripts/post-deploy-checks.sh

# Monitor application
tail -f /var/log/superset/superset.log
```

---

## Configuration Files

### docker-compose.override.yml

Create this file to override default settings per environment:

```yaml
version: '3'
services:
  superset:
    environment:
      - SUPERSET_ENV=production
      - SUPERSET_LOG_LEVEL=INFO
    volumes:
      - ./docker/pythonpath_dev:/app/pythonpath
      - /path/to/backups:/app/backups
```

### .env File Structure

```
# Server
SUPERSET_ENV=development|staging|production
SUPERSET_SECRET_KEY=<min 32 chars>

# Database
DATABASE_URL=postgresql://user:pass@host:5432/db

# Redis
REDIS_URL=redis://host:6379/0

# Custom Configurations
LDAP_ENABLED=true|false
MORPHEUS_API_KEY=<key>
```

---

## Troubleshooting

### Common Issues

#### Issue: Database Connection Failed

```bash
# Verify database is running
docker-compose ps | grep db

# Check database connectivity
docker-compose exec db psql -U postgres

# View database logs
docker-compose logs db
```

#### Issue: Superset Port Already in Use

```bash
# Find process using port 8088
lsof -i :8088

# Kill process or change port in .env
# Then restart: docker-compose down && docker-compose up
```

#### Issue: LDAP Connection Failed

```bash
# Test LDAP connection
docker-compose exec superset ldapsearch -h <ldap-server> -x -D "<bind-dn>" -w <password>

# Check LDAP configuration in logs
docker-compose logs superset | grep -i ldap
```

---

## Rollback Procedures

### Rollback to Previous Version

```bash
# List available backups
ls -la /path/to/backups/

# Restore configuration backup
./docs/loonar-customizations/scripts/backup-config.sh restore <backup-date>

# Checkout previous git version
git checkout <previous-commit-hash>

# Rebuild and restart
docker-compose down
docker-compose build
docker-compose up -d

# Verify rollback
curl http://localhost:8088/health
```

---

## Monitoring & Logs

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f superset

# Last 100 lines
docker-compose logs --tail=100 superset

# Follow errors only
docker-compose logs -f superset | grep ERROR
```

### Health Checks

```bash
# Application health
curl http://localhost:8088/health

# Database connection
docker-compose exec superset flask shell
>>> from superset import db
>>> db.session.execute('SELECT 1')

# Cache connection
docker-compose exec redis redis-cli ping
```

---

## Production Checklist

- [ ] Environment variables verified and secure
- [ ] Database backed up
- [ ] SSL/TLS certificates configured
- [ ] LDAP/authentication tested
- [ ] Data integrations verified
- [ ] Custom dashboards and charts accessible
- [ ] Backup and restore scripts tested
- [ ] Monitoring and alerting configured
- [ ] Documentation updated
- [ ] Team trained on new features

---

## Support

For deployment issues:

1. Check logs: `docker-compose logs -f`
2. Refer to main README.md
3. Check Apache Superset documentation
4. Review GitHub issues in loonar-morpheus-sysint/superset
