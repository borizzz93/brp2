#!/bin/bash

# Misago Production Deployment Script - Fixed Version
# Author: MiniMax Agent
# Date: November 28, 2025
# For Ubuntu 22.04 server deployment
# Usage: ./deploy_fixed.sh [start|stop|restart|status|logs|backup]

set -e  # Exit on any error

# Configuration
PROJECT_NAME="misago"
DOMAIN="benj.run.place"
SERVER_IP="84.21.189.163"
COMPOSE_FILE="docker-compose.prod.yaml"
BACKUP_DIR="./backups"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if Docker is installed and running
check_docker() {
    log "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first:"
        echo "curl -fsSL https://get.docker.com -o get-docker.sh"
        echo "sh get-docker.sh"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker:"
        echo "sudo systemctl start docker"
        echo "sudo systemctl enable docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first:"
        echo "sudo curl -L \"https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose"
        echo "sudo chmod +x /usr/local/bin/docker-compose"
        exit 1
    fi
    
    success "Docker is installed and running"
}

# Check system requirements
check_system_requirements() {
    log "Checking system requirements..."
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu 22.04" /etc/os-release 2>/dev/null; then
        warning "This script is optimized for Ubuntu 22.04. Current version:"
        cat /etc/os-release | grep "PRETTY_NAME"
    fi
    
    # Check available disk space (minimum 5GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 5242880 ]; then  # 5GB in KB
        error "Insufficient disk space. At least 5GB required."
        exit 1
    fi
    
    # Check memory (minimum 2GB)
    total_memory=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$total_memory" -lt 2048 ]; then
        warning "Low memory detected: ${total_memory}MB. Minimum 2GB recommended."
    fi
    
    success "System requirements check passed"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p $BACKUP_DIR
    mkdir -p ./logs/nginx
    mkdir -p ./logs/app
    mkdir -p ./nginx/ssl
    mkdir -p ./nginx/sites-enabled
    mkdir -p ./ssl
    
    success "Directories created successfully"
}

# Setup environment file
setup_env() {
    log "Setting up environment file..."
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            warning "Created .env file from .env.example. Please update it with your actual values."
        else
            error ".env.example file not found!"
            exit 1
        fi
    else
        log ".env file already exists, using existing configuration"
    fi
    
    # Generate secure secret key if not set
    if grep -q "your-super-secret-key-here" .env 2>/dev/null; then
        warning "Updating default secret key with secure random key..."
        sed -i "s/your-super-secret-key-here-change-this/$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')/" .env
    fi
    
    success "Environment file setup completed"
}

# Check and resolve port conflicts
check_port_conflicts() {
    log "Checking for port conflicts..."
    
    local conflicts=0
    local standard_ports=("80" "443")
    
    for port in "${standard_ports[@]}"; do
        if lsof -i :$port &>/dev/null; then
            warning "Port $port is in use. Process details:"
            lsof -i :$port 2>/dev/null || true
            
            # Ask user to resolve conflict
            read -p "Do you want to stop the process using port $port? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                local pid=$(lsof -ti:$port)
                if [ -n "$pid" ]; then
                    sudo kill -9 $pid 2>/dev/null || true
                    sleep 2
                    if ! lsof -i :$port &>/dev/null; then
                        success "Port $port is now free"
                    else
                        error "Failed to free port $port"
                        conflicts=$((conflicts + 1))
                    fi
                fi
            else
                conflicts=$((conflicts + 1))
            fi
        fi
    done
    
    if [ $conflicts -gt 0 ]; then
        error "Port conflicts detected. Please resolve manually or use alternative ports."
        warning "Consider using: docker-compose -f docker-compose.prod.improved.yaml up -d"
        return 1
    fi
    
    success "No port conflicts detected"
}

# Generate SSL certificates
generate_ssl_cert() {
    log "Setting up SSL certificates..."
    
    if [ ! -f "./nginx/ssl/misago.crt" ]; then
        log "Generating self-signed SSL certificate for development..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ./nginx/ssl/misago.key \
            -out ./nginx/ssl/misago.crt \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN" \
            -addext "subjectAltName=DNS:$DOMAIN,DNS:www.$DOMAIN,IP:$SERVER_IP"
        
        warning "Using self-signed certificate for development."
        warning "For production, use Let's Encrypt or commercial certificate."
    fi
    
    # Copy SSL files to nginx directory structure
    cp ./nginx/ssl/misago.crt ./ssl/ 2>/dev/null || true
    cp ./nginx/ssl/misago.key ./ssl/ 2>/dev/null || true
    
    success "SSL certificates setup completed"
}

# Clean up Docker resources
cleanup_docker() {
    log "Cleaning up existing Docker resources..."
    
    # Stop and remove all containers
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # Remove unused networks
    docker network prune -f 2>/dev/null || true
    
    # Remove unused volumes (be careful with this)
    read -p "Do you want to remove unused Docker volumes? This may delete data. (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f
    fi
    
    success "Docker cleanup completed"
}

# Build and deploy
deploy() {
    log "Building and deploying Misago application..."
    
    # Create network if it doesn't exist
    docker network create misago_network 2>/dev/null || true
    
    # Build images with no cache to ensure latest
    log "Building Docker images..."
    docker-compose -f $COMPOSE_FILE build --no-cache
    
    # Start services
    log "Starting services..."
    docker-compose -f $COMPOSE_FILE up -d
    
    success "Deployment completed successfully!"
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
    
    echo -e "\n=== Container Health ==="
    docker-compose -f $COMPOSE_FILE ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
}

# Show logs
logs() {
    local service=${1:-}
    if [ -n "$service" ]; then
        log "Showing logs for $service..."
        docker-compose -f $COMPOSE_FILE logs -f --tail=100 $service
    else
        log "Showing logs for all services..."
        docker-compose -f $COMPOSE_FILE logs -f --tail=100
    fi
}

# Database operations
backup_database() {
    log "Creating database backup..."
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_file="$BACKUP_DIR/misago_backup_$timestamp.sql"
    
    if docker-compose -f $COMPOSE_FILE exec -T postgres pg_dump -U misago misago > $backup_file 2>/dev/null; then
        # Also backup media files
        if [ -d "./media_data" ]; then
            tar -czf "$BACKUP_DIR/media_backup_$timestamp.tar.gz" ./media_data 2>/dev/null || true
        fi
        success "Backup created: $backup_file"
    else
        error "Database backup failed"
        return 1
    fi
}

# Run database migrations
migrate_database() {
    log "Running database migrations..."
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    for i in {1..30}; do
        if docker-compose -f $COMPOSE_FILE exec -T postgres pg_isready -U misago &>/dev/null; then
            break
        fi
        log "Waiting for database... ($i/30)"
        sleep 5
    done
    
    # Run migrations
    if docker-compose -f $COMPOSE_FILE exec web python manage.py migrate --noinput; then
        success "Database migrations completed"
    else
        error "Database migrations failed"
        return 1
    fi
    
    # Collect static files
    log "Collecting static files..."
    if docker-compose -f $COMPOSE_FILE exec web python manage.py collectstatic --noinput; then
        success "Static files collected"
    else
        warning "Static files collection failed"
    fi
}

# Health check
health_check() {
    log "Performing comprehensive health check..."
    
    local failed=0
    
    # Check if services are running
    if ! docker-compose -f $COMPOSE_FILE ps | grep -q "Up"; then
        error "Some services are not running"
        failed=1
    fi
    
    # Check HTTP endpoints
    sleep 10  # Give services time to start
    if curl -f -s http://localhost/health/ > /dev/null; then
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
        echo -e "\n🌟 Misago is ready to use:"
        echo "   Main site: http://$DOMAIN"
        echo "   Admin panel: http://$DOMAIN/admin/"
        echo "   Health check: http://$DOMAIN/health/"
    else
        error "Some health checks failed!"
        echo "Check logs with: $0 logs"
        return 1
    fi
}

# Setup admin user
setup_admin() {
    log "Setting up admin user..."
    
    docker-compose -f $COMPOSE_FILE exec web python manage.py shell -c "
from django.contrib.auth.models import User
try:
    User.objects.get(username='admin')
    print('Admin user already exists')
except User.DoesNotExist:
    User.objects.create_superuser('admin', 'admin@$DOMAIN', '$(date +%s)')
    print('Admin user created successfully')
"
    success "Admin user setup completed"
}

# Monitor resources
monitor() {
    log "Resource Usage:"
    echo "=== Docker Containers ==="
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    
    echo -e "\n=== Disk Usage ==="
    df -h | grep -E "(Filesystem|/dev/)"
    
    echo -e "\n=== Memory Usage ==="
    free -h
    
    echo -e "\n=== Docker System Info ==="
    echo "Images: $(docker images -q | wc -l)"
    echo "Containers: $(docker ps -a -q | wc -l)"
    echo "Networks: $(docker network ls -q | wc -l)"
}

# Clean up system
cleanup() {
    log "Cleaning up system..."
    
    # Remove unused containers, networks, images
    docker system prune -f
    
    # Remove unused volumes (ask for confirmation)
    read -p "Remove unused volumes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f
    fi
    
    # Remove unused images
    read -p "Remove unused images? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker image prune -f
    fi
    
    success "System cleanup completed"
}

# Show help
show_help() {
    echo "Misago Production Deployment Script - Fixed Version"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup           Setup the deployment environment"
    echo "  check           Check system requirements and dependencies"
    echo "  deploy          Build and deploy the application"
    echo "  start           Start all services"
    echo "  stop            Stop all services"
    echo "  restart         Restart all services"
    echo "  status          Show service status"
    echo "  logs [service]  Show logs (optionally for specific service)"
    echo "  backup          Create database backup"
    echo "  migrate         Run database migrations"
    echo "  health          Perform health checks"
    echo "  admin           Setup admin user"
    echo "  monitor         Show resource usage"
    echo "  cleanup         Clean up Docker resources"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 check"
    echo "  $0 deploy"
    echo "  $0 logs web"
    echo "  $0 backup"
}

# Main script logic
main() {
    log "🚀 Misago Production Deployment Script"
    log "Domain: $DOMAIN | Server: $SERVER_IP"
    echo ""
    
    case "${1:-}" in
        check)
            check_system_requirements
            check_docker
            ;;
        setup)
            check_system_requirements
            check_docker
            create_directories
            setup_env
            generate_ssl_cert
            success "Setup completed! Please review and update .env file."
            ;;
        deploy)
            check_system_requirements
            check_docker
            setup_env
            check_port_conflicts || warning "Continuing with port conflicts..."
            cleanup_docker
            deploy
            migrate_database
            setup_admin
            health_check
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
            backup_database
            ;;
        migrate)
            migrate_database
            ;;
        health)
            health_check
            ;;
        admin)
            setup_admin
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