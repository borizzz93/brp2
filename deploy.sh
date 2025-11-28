#!/bin/bash

# Misago Production Deployment Script
# For Ubuntu 22.04 server deployment
# Usage: ./deploy.sh [start|stop|restart|status|logs|backup]

set -e

# Configuration
PROJECT_NAME="misago"
DOMAIN="benj.run.place"
SERVER_IP="84.21.189.163"
COMPOSE_FILE="docker-compose.prod.yaml"
BACKUP_DIR="./backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    mkdir -p $BACKUP_DIR
    mkdir -p ./logs/nginx
    mkdir -p ./logs/app
    mkdir -p ./nginx/ssl
    mkdir -p ./nginx/sites-enabled
    success "Directories created successfully"
}

# Generate SSL certificates (self-signed for development)
generate_ssl_cert() {
    if [ ! -f "./nginx/ssl/misago.crt" ]; then
        log "Generating self-signed SSL certificate..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ./nginx/ssl/misago.key \
            -out ./nginx/ssl/misago.crt \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
        warning "Using self-signed certificate. For production, use Let's Encrypt or commercial certificate."
    fi
}

# Setup environment file
setup_env() {
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            warning "Created .env file from .env.example. Please update it with your actual values."
        else
            error ".env.example file not found!"
            exit 1
        fi
    fi
}

# Build and deploy
deploy() {
    log "Building and deploying Misago..."
    
    # Create network if it doesn't exist
    docker network create misago_network 2>/dev/null || true
    
    # Build images
    docker-compose -f $COMPOSE_FILE build --no-cache
    
    # Start services
    docker-compose -f $COMPOSE_FILE up -d
    
    success "Deployment completed successfully!"
    
    # Show status
    status
}

# Start services
start() {
    log "Starting Misago services..."
    docker-compose -f $COMPOSE_FILE up -d
    success "Services started successfully!"
    status
}

# Stop services
stop() {
    log "Stopping Misago services..."
    docker-compose -f $COMPOSE_FILE stop
    success "Services stopped successfully!"
}

# Restart services
restart() {
    log "Restarting Misago services..."
    docker-compose -f $COMPOSE_FILE restart
    success "Services restarted successfully!"
    status
}

# Show service status
status() {
    log "Service Status:"
    docker-compose -f $COMPOSE_FILE ps
}

# Show logs
logs() {
    local service=${1:-}
    if [ -n "$service" ]; then
        log "Showing logs for $service..."
        docker-compose -f $COMPOSE_FILE logs -f $service
    else
        log "Showing logs for all services..."
        docker-compose -f $COMPOSE_FILE logs -f
    fi
}

# Database backup
backup() {
    log "Creating database backup..."
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_file="$BACKUP_DIR/misago_backup_$timestamp.sql"
    
    docker-compose -f $COMPOSE_FILE exec postgres pg_dump -U misago misago > $backup_file
    
    # Also backup media files
    if [ -d "./media_data" ]; then
        tar -czf "$BACKUP_DIR/media_backup_$timestamp.tar.gz" ./media_data
    fi
    
    success "Backup created: $backup_file"
    log "Available backups:"
    ls -la $BACKUP_DIR/
}

# Database restore
restore() {
    local backup_file=$1
    if [ -z "$backup_file" ]; then
        error "Please specify backup file: ./deploy.sh restore backup_file.sql"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        error "Backup file not found: $backup_file"
        return 1
    fi
    
    warning "This will replace the current database. Are you sure? (yes/no)"
    read -r confirmation
    if [ "$confirmation" != "yes" ]; then
        log "Restore cancelled."
        return 0
    fi
    
    log "Restoring database from $backup_file..."
    docker-compose -f $COMPOSE_FILE exec -T postgres psql -U misago misago < $backup_file
    success "Database restored successfully!"
}

# Update application
update() {
    log "Updating Misago application..."
    
    # Pull latest changes (if using git)
    if [ -d ".git" ]; then
        git pull origin production-setup
    fi
    
    # Rebuild and restart
    docker-compose -f $COMPOSE_FILE build --no-cache
    docker-compose -f $COMPOSE_FILE up -d
    
    # Run migrations
    docker-compose -f $COMPOSE_FILE exec web python manage.py migrate --noinput
    
    # Collect static files
    docker-compose -f $COMPOSE_FILE exec web python manage.py collectstatic --noinput
    
    success "Update completed successfully!"
}

# Setup initial data
setup_initial() {
    log "Setting up initial data..."
    
    # Wait for database
    log "Waiting for database to be ready..."
    sleep 30
    
    # Run migrations
    docker-compose -f $COMPOSE_FILE exec web python manage.py migrate --noinput
    
    # Create superuser
    docker-compose -f $COMPOSE_FILE exec web python manage.py createsuperuser || true
    
    # Collect static files
    docker-compose -f $COMPOSE_FILE exec web python manage.py collectstatic --noinput
    
    # Load initial data (if available)
    if [ -f "initial_data.json" ]; then
        docker-compose -f $COMPOSE_FILE exec web python manage.py loaddata initial_data.json
    fi
    
    success "Initial setup completed!"
}

# Health check
health_check() {
    log "Performing health check..."
    
    # Check if services are running
    local failed=0
    
    if ! docker-compose -f $COMPOSE_FILE ps | grep -q "Up"; then
        error "Some services are not running"
        failed=1
    fi
    
    # Check HTTP endpoints
    if curl -f http://localhost/health/ > /dev/null 2>&1; then
        success "Health check endpoint is responding"
    else
        error "Health check endpoint is not responding"
        failed=1
    fi
    
    # Check database connection
    if docker-compose -f $COMPOSE_FILE exec web python manage.py check --database default > /dev/null 2>&1; then
        success "Database connection is working"
    else
        error "Database connection failed"
        failed=1
    fi
    
    if [ $failed -eq 0 ]; then
        success "All health checks passed!"
    else
        error "Some health checks failed!"
        return 1
    fi
}

# Monitor resources
monitor() {
    log "Resource usage:"
    echo "=== Docker Containers ==="
    docker stats --no-stream
    
    echo -e "\n=== Disk Usage ==="
    df -h
    
    echo -e "\n=== Memory Usage ==="
    free -h
}

# Clean up
cleanup() {
    log "Cleaning up..."
    docker system prune -f
    docker volume prune -f
    success "Cleanup completed!"
}

# Show help
show_help() {
    echo "Misago Production Deployment Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup           Setup the deployment environment"
    echo "  deploy          Build and deploy the application"
    echo "  start           Start all services"
    echo "  stop            Stop all services"
    echo "  restart         Restart all services"
    echo "  status          Show service status"
    echo "  logs [service]  Show logs (optionally for specific service)"
    echo "  backup          Create database backup"
    echo "  restore <file>  Restore from backup file"
    echo "  update          Update application to latest version"
    echo "  setup-initial   Setup initial database and data"
    echo "  health          Perform health checks"
    echo "  monitor         Show resource usage"
    echo "  cleanup         Clean up Docker resources"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 deploy"
    echo "  $0 logs web"
    echo "  $0 backup"
    echo "  $0 restore backups/misago_backup_20231228_120000.sql"
}

# Main script logic
main() {
    check_docker
    create_directories
    
    case "${1:-}" in
        setup)
            setup_env
            generate_ssl_cert
            success "Setup completed! Please update .env file with your values."
            ;;
        deploy)
            deploy
            ;;
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        logs)
            logs "$2"
            ;;
        backup)
            backup
            ;;
        restore)
            restore "$2"
            ;;
        update)
            update
            ;;
        setup-initial)
            setup_initial
            ;;
        health)
            health_check
            ;;
        monitor)
            monitor
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            error "No command specified!"
            show_help
            exit 1
            ;;
        *)
            error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"