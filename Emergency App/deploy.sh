#!/bin/bash

# ============================================================================
# Smart Cane Emergency App - Automated Deployment Script
# ============================================================================
# Usage: bash deploy.sh [environment] [action]
# Examples:
#   bash deploy.sh dev setup    - Setup development environment
#   bash deploy.sh prod setup   - Setup production environment
#   bash deploy.sh dev start    - Start application
#   bash deploy.sh dev stop     - Stop application
#   bash deploy.sh dev logs     - View logs
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# ============================================================================
# FUNCTIONS
# ============================================================================

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_requirements() {
    print_header "Checking Requirements"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo "Install from: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker installed"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        echo "Install from: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_success "Docker Compose installed"
    
    # Check .env file
    if [ ! -f "$ENV_FILE" ]; then
        print_warning ".env file not found"
        echo "Creating .env from .env.example..."
        if [ -f "$ENV_EXAMPLE" ]; then
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            print_success ".env created from .env.example"
            print_warning "Please edit .env and configure your variables"
            exit 1
        else
            print_error ".env.example not found"
            exit 1
        fi
    fi
    print_success ".env file found"
}

install_docker_compose() {
    print_header "Installing Docker Compose"
    
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
    echo "Downloading Docker Compose ${DOCKER_COMPOSE_VERSION}..."
    
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installed successfully"
}

setup_dev() {
    print_header "Setting up Development Environment"
    
    check_requirements
    
    # Create directories
    mkdir -p backend/logs backend/staticfiles backend/media
    print_success "Directories created"
    
    # Build images
    print_header "Building Docker images"
    docker-compose -f "$DOCKER_COMPOSE_FILE" build
    print_success "Docker images built"
    
    # Start services
    print_header "Starting services"
    docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
    print_success "Services started"
    
    # Run migrations
    print_header "Running migrations"
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T backend python manage.py migrate
    print_success "Migrations completed"
    
    # Create superuser prompt
    print_warning "Creating superuser..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec backend python manage.py createsuperuser
    
    # Collect static files
    print_header "Collecting static files"
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T backend python manage.py collectstatic --noinput
    print_success "Static files collected"
    
    print_header "Development Setup Complete!"
    echo -e "${GREEN}Backend:${NC} http://localhost:8000"
    echo -e "${GREEN}Admin Panel:${NC} http://localhost:8000/admin"
    echo -e "${GREEN}API Documentation:${NC} http://localhost:8000/api/schema/swagger/"
    echo -e "${GREEN}Database:${NC} localhost:5432"
    echo -e "${GREEN}Redis:${NC} localhost:6379"
}

setup_prod() {
    print_header "Setting up Production Environment"
    
    check_requirements
    
    print_warning "Production setup requires manual SSL configuration"
    echo "Steps:"
    echo "1. Update .env with production values"
    echo "2. Configure SSL certificates in /etc/letsencrypt/"
    echo "3. Configure nginx.conf with your domain"
    echo "4. Run: bash deploy.sh prod start"
    
    # Build images
    print_header "Building Docker images"
    docker-compose -f "$DOCKER_COMPOSE_FILE" build --no-cache
    print_success "Docker images built"
}

start_services() {
    print_header "Starting Services"
    
    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found"
        exit 1
    fi
    
    docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
    
    # Wait for services to start
    echo "Waiting for services to start..."
    sleep 10
    
    # Check health
    print_header "Checking service health"
    
    if docker-compose -f "$DOCKER_COMPOSE_FILE" ps | grep -q "healthy"; then
        print_success "Services are healthy"
    else
        print_warning "Services are starting, please wait..."
        sleep 15
    fi
    
    # Display service info
    docker-compose -f "$DOCKER_COMPOSE_FILE" ps
}

stop_services() {
    print_header "Stopping Services"
    docker-compose -f "$DOCKER_COMPOSE_FILE" down
    print_success "Services stopped"
}

restart_services() {
    print_header "Restarting Services"
    docker-compose -f "$DOCKER_COMPOSE_FILE" restart
    print_success "Services restarted"
}

view_logs() {
    print_header "Viewing Logs"
    
    SERVICE=${2:-backend}
    
    case $SERVICE in
        all)
            docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f
            ;;
        backend)
            docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f backend
            ;;
        celery)
            docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f celery_worker celery_beat
            ;;
        db)
            docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f db
            ;;
        redis)
            docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f redis
            ;;
        nginx)
            docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f nginx
            ;;
        *)
            docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f $SERVICE
            ;;
    esac
}

migrate_db() {
    print_header "Running Database Migrations"
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T backend python manage.py migrate
    print_success "Migrations completed"
}

create_superuser() {
    print_header "Creating Superuser"
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec backend python manage.py createsuperuser
}

collect_static() {
    print_header "Collecting Static Files"
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T backend python manage.py collectstatic --noinput
    print_success "Static files collected"
}

backup_database() {
    print_header "Backing Up Database"
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="backups/smart_cane_db_$TIMESTAMP.sql"
    
    mkdir -p backups
    
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T db pg_dump \
        -U postgres smart_cane_db > "$BACKUP_FILE"
    
    print_success "Database backed up to $BACKUP_FILE"
}

restore_database() {
    print_header "Restoring Database"
    
    if [ -z "$2" ]; then
        print_error "Please provide backup file path"
        echo "Usage: bash deploy.sh [env] restore <backup_file>"
        exit 1
    fi
    
    BACKUP_FILE=$2
    
    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    print_warning "This will overwrite the current database!"
    read -p "Are you sure? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        print_warning "Restore cancelled"
        exit 0
    fi
    
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T db psql \
        -U postgres smart_cane_db < "$BACKUP_FILE"
    
    print_success "Database restored from $BACKUP_FILE"
}

clean_docker() {
    print_header "Cleaning Docker Resources"
    print_warning "This will remove containers, images, and volumes"
    read -p "Are you sure? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        print_warning "Cleanup cancelled"
        exit 0
    fi
    
    docker-compose -f "$DOCKER_COMPOSE_FILE" down -v
    print_success "Docker resources cleaned"
}

run_tests() {
    print_header "Running Tests"
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T backend python manage.py test
}

shell() {
    print_header "Starting Django Shell"
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec backend python manage.py shell
}

show_help() {
    cat << EOF
${BLUE}Smart Cane Emergency App - Deployment Script${NC}

${BLUE}Usage:${NC}
  bash deploy.sh [environment] [action] [options]

${BLUE}Environments:${NC}
  dev                Development environment
  prod               Production environment

${BLUE}Actions:${NC}
  setup              Setup environment (build images, migrations, etc.)
  start              Start all services
  stop               Stop all services
  restart            Restart all services
  logs               View logs (default: backend)
  migrate            Run database migrations
  superuser          Create a superuser
  static             Collect static files
  backup             Backup database
  restore <file>     Restore database from backup
  clean              Remove all Docker containers and volumes
  test               Run tests
  shell              Start Django shell
  help               Show this help message

${BLUE}Examples:${NC}
  bash deploy.sh dev setup              # Setup development environment
  bash deploy.sh prod start             # Start production services
  bash deploy.sh dev logs               # View backend logs
  bash deploy.sh dev logs celery        # View Celery logs
  bash deploy.sh dev migrate            # Run migrations
  bash deploy.sh dev backup             # Backup database
  bash deploy.sh dev restore backups/smart_cane_db_20260302.sql

${BLUE}Services:${NC}
  - Backend (Django + Gunicorn): http://localhost:8000
  - PostgreSQL: localhost:5432
  - Redis: localhost:6379
  - Admin Panel: http://localhost:8000/admin
  - API Docs: http://localhost:8000/api/schema/swagger/

EOF
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

ENVIRONMENT=$1
ACTION=${2:-help}
OPTION=$3

case "$ACTION" in
    setup)
        case "$ENVIRONMENT" in
            dev)
                setup_dev
                ;;
            prod)
                setup_prod
                ;;
            *)
                print_error "Unknown environment: $ENVIRONMENT"
                echo "Use 'dev' or 'prod'"
                exit 1
                ;;
        esac
        ;;
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    logs)
        view_logs "$ENVIRONMENT" "$OPTION"
        ;;
    migrate)
        migrate_db
        ;;
    superuser)
        create_superuser
        ;;
    static)
        collect_static
        ;;
    backup)
        backup_database
        ;;
    restore)
        restore_database "$ENVIRONMENT" "$OPTION"
        ;;
    clean)
        clean_docker
        ;;
    test)
        run_tests
        ;;
    shell)
        shell
        ;;
    help)
        show_help
        ;;
    *)
        print_error "Unknown action: $ACTION"
        show_help
        exit 1
        ;;
esac
