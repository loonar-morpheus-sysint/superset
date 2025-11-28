#!/bin/bash
#
# Deployment script for Loonar Superset 6.0
# This script automates the deployment of Superset to various environments
# Usage: ./deploy.sh [environment] [action]
# Environments: dev, staging, production
# Actions: deploy, rollback, restart, status
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
ENVIRONMENT="${1:-production}"
ACTION="${2:-deploy}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${PROJECT_ROOT}/.backups"
LOG_FILE="${PROJECT_ROOT}/logs/deploy_${TIMESTAMP}.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Validation
validate_environment() {
    case "$ENVIRONMENT" in
        dev|development)
            ENVIRONMENT="dev"
            ;;
        staging)
            ;;
        prod|production)
            ENVIRONMENT="production"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
    log_info "Deploying to environment: $ENVIRONMENT"
}

# Pre-deployment checks
pre_deploy_checks() {
    log_info "Running pre-deployment checks..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check .env file
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        log_error ".env file not found in ${PROJECT_ROOT}"
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker ps &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    log_success "Pre-deployment checks passed"
}

# Backup function
backup_config() {
    log_info "Creating configuration backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup .env
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        cp "${PROJECT_ROOT}/.env" "${BACKUP_DIR}/.env_${TIMESTAMP}"
        log_success "Backed up .env to ${BACKUP_DIR}/.env_${TIMESTAMP}"
    fi
    
    # Backup docker-compose.override.yml if exists
    if [ -f "${PROJECT_ROOT}/docker-compose.override.yml" ]; then
        cp "${PROJECT_ROOT}/docker-compose.override.yml" "${BACKUP_DIR}/docker-compose.override.yml_${TIMESTAMP}"
        log_success "Backed up docker-compose.override.yml"
    fi
    
    # Database backup (if database is running)
    if docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" ps db &> /dev/null; then
        log_info "Backing up database..."
        docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T db \
            pg_dump -U postgres superset > "${BACKUP_DIR}/superset_db_${TIMESTAMP}.sql" || \
            log_warn "Database backup failed - this is OK if database doesn't exist yet"
    fi
}

# Deployment function
deploy() {
    log_info "Starting deployment to $ENVIRONMENT..."
    
    # Backup first
    backup_config
    
    # Change to project directory
    cd "$PROJECT_ROOT"
    
    # Load environment variables
    export ENVIRONMENT="$ENVIRONMENT"
    
    # Build images
    log_info "Building Docker images..."
    docker-compose build --no-cache 2>&1 | tee -a "$LOG_FILE" || {
        log_error "Docker build failed"
        return 1
    }
    
    # Stop existing containers
    log_info "Stopping existing containers..."
    docker-compose down 2>&1 | tee -a "$LOG_FILE" || true
    
    # Start services
    log_info "Starting services..."
    docker-compose up -d 2>&1 | tee -a "$LOG_FILE" || {
        log_error "Failed to start services"
        return 1
    }
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 10
    
    # Health check
    if ! health_check; then
        log_error "Health check failed after deployment"
        return 1
    fi
    
    log_success "Deployment completed successfully"
}

# Health check function
health_check() {
    log_info "Performing health checks..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8088/health | grep -q "healthy"; then
            log_success "Health check passed"
            return 0
        fi
        
        log_info "Health check attempt $attempt/$max_attempts..."
        sleep 2
        ((attempt++))
    done
    
    log_error "Health check failed after $max_attempts attempts"
    return 1
}

# Rollback function
rollback() {
    log_warn "Rolling back deployment..."
    
    # Find latest backup
    local latest_backup=$(ls -t "${BACKUP_DIR}/.env_"* 2>/dev/null | head -1)
    
    if [ -z "$latest_backup" ]; then
        log_error "No backup found for rollback"
        return 1
    fi
    
    log_info "Restoring from backup: $latest_backup"
    cp "$latest_backup" "${PROJECT_ROOT}/.env"
    
    # Restart services
    cd "$PROJECT_ROOT"
    docker-compose down
    docker-compose up -d
    
    sleep 5
    
    if health_check; then
        log_success "Rollback completed successfully"
        return 0
    else
        log_error "Rollback failed - health check did not pass"
        return 1
    fi
}

# Status function
status() {
    log_info "Getting deployment status..."
    cd "$PROJECT_ROOT"
    docker-compose ps
}

# Main execution
main() {
    log_info "=== Superset Deployment Script ==="
    log_info "Environment: $ENVIRONMENT"
    log_info "Action: $ACTION"
    log_info "Timestamp: $TIMESTAMP"
    log_info "Log file: $LOG_FILE"
    
    validate_environment
    
    case "$ACTION" in
        deploy)
            pre_deploy_checks
            deploy
            ;;
        rollback)
            rollback
            ;;
        restart)
            cd "$PROJECT_ROOT"
            docker-compose restart
            sleep 5
            health_check
            ;;
        status)
            status
            ;;
        *)
            log_error "Unknown action: $ACTION"
            echo "Usage: $0 [environment] [action]"
            echo "Environments: dev, staging, production"
            echo "Actions: deploy, rollback, restart, status"
            exit 1
            ;;
    esac
    
    log_success "Script execution completed"
}

# Run main function
main
