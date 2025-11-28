#!/bin/bash

# Script to fix and deploy Misago on Ubuntu 22.04 server
# This script resolves common deployment issues

set -e  # Exit on any error

echo "========================================="
echo "Misago Fix & Deploy Script"
echo "Author: MiniMax Agent"
echo "Date: $(date)"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. Consider using a regular user with sudo privileges."
fi

print_status "Starting deployment fix process..."

# 1. Check Docker status
print_status "Checking Docker status..."
if ! systemctl is-active --quiet docker; then
    print_error "Docker is not running. Starting Docker..."
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# 2. Stop all Docker containers and clean up
print_status "Cleaning up existing Docker containers and images..."
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker rmi -f $(docker images -q) 2>/dev/null || true

# 3. Remove Docker networks
print_status "Removing Docker networks..."
docker network prune -f

# 4. Clean up Docker volumes (optional)
print_status "Cleaning up Docker volumes (optional)..."
docker volume prune -f

# 5. Restart Docker daemon
print_status "Restarting Docker daemon..."
sudo systemctl restart docker

# 6. Check port conflicts
print_status "Checking port conflicts..."
PORT_80_USED=$(lsof -i :80 2>/dev/null | wc -l)
PORT_443_USED=$(lsof -i :443 2>/dev/null | wc -l)

if [ "$PORT_80_USED" -gt 0 ]; then
    print_warning "Port 80 is in use. Processes using port 80:"
    lsof -i :80 2>/dev/null || true
    
    # Ask user if they want to kill processes
    read -p "Do you want to stop processes using port 80? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Killing processes using port 80..."
        sudo lsof -ti:80 | xargs sudo kill -9 2>/dev/null || true
    fi
fi

if [ "$PORT_443_USED" -gt 0 ]; then
    print_warning "Port 443 is in use. Processes using port 443:"
    lsof -i :443 2>/dev/null || true
    
    read -p "Do you want to stop processes using port 443? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Killing processes using port 443..."
        sudo lsof -ti:443 | xargs sudo kill -9 2>/dev/null || true
    fi
fi

# 7. Create necessary directories
print_status "Creating necessary directories..."
sudo mkdir -p /var/lib/misago/static
sudo mkdir -p /var/lib/misago/media
sudo mkdir -p /etc/misago
sudo mkdir -p /var/log/misago

# 8. Set proper permissions
print_status "Setting permissions..."
sudo chown -R $(whoami):$(whoami) /var/lib/misago /etc/misago /var/log/misago 2>/dev/null || true

# 9. Check if .env file exists
if [ ! -f ".env" ]; then
    print_warning ".env file not found. Creating from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_warning "Please edit .env file with your actual values!"
    else
        print_error ".env.example file not found. Creating basic .env..."
        cat > .env << EOF
# Django settings
DJANGO_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')
DEBUG=False
ALLOWED_HOSTS=benj.run.place,localhost,127.0.0.1

# Database settings
DATABASE_URL=postgresql://misago:misago_password@postgres:5432/misago_db
POSTGRES_DB=misago_db
POSTGRES_USER=misago
POSTGRES_PASSWORD=misago_password

# Redis settings
REDIS_URL=redis://redis:6379/0

# Email settings
EMAIL_HOST=localhost
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=

# Domain and SSL
DOMAIN_NAME=benj.run.place
SSL_EMAIL=admin@benj.run.place

# Sentry (optional)
SENTRY_DSN=

# Admin user
DJANGO_ADMIN_USERNAME=admin
DJANGO_ADMIN_EMAIL=admin@benj.run.place
DJANGO_ADMIN_PASSWORD=admin_password_$(date +%s)
EOF
        print_status "Basic .env file created. Please edit it with your actual values!"
    fi
fi

# 10. Build and start services
print_status "Building and starting services..."
docker-compose -f docker-compose.prod.yaml build --no-cache
docker-compose -f docker-compose.prod.yaml up -d

# 11. Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 30

# 12. Check service status
print_status "Checking service status..."
docker-compose -f docker-compose.prod.yaml ps

# 13. Run database migrations
print_status "Running database migrations..."
docker-compose -f docker-compose.prod.yaml exec web python manage.py migrate

# 14. Collect static files
print_status "Collecting static files..."
docker-compose -f docker-compose.prod.yaml exec web python manage.py collectstatic --noinput

# 15. Create superuser (if it doesn't exist)
print_status "Creating superuser..."
docker-compose -f docker-compose.prod.yaml exec web python manage.py shell -c "
from django.contrib.auth.models import User
try:
    User.objects.get(username='admin')
    print('Admin user already exists')
except User.DoesNotExist:
    User.objects.create_superuser('admin', 'admin@benj.run.place', 'admin_password_$(date +%s)')
    print('Admin user created')
"

# 16. Test health endpoints
print_status "Testing health endpoints..."
sleep 10
if curl -f http://localhost/health/ > /dev/null 2>&1; then
    print_status "Health check passed!"
else
    print_warning "Health check failed. Check logs with: docker-compose -f docker-compose.prod.yaml logs web"
fi

# 17. Show final status
print_status "Deployment completed!"
echo ""
echo "========================================="
echo "DEPLOYMENT SUMMARY"
echo "========================================="
echo "Domain: http://benj.run.place"
echo "Admin URL: http://benj.run_place/admin/"
echo ""
echo "To view logs:"
echo "  docker-compose -f docker-compose.prod.yaml logs -f"
echo ""
echo "To stop services:"
echo "  docker-compose -f docker-compose.prod.yaml down"
echo ""
echo "To restart services:"
echo "  docker-compose -f docker-compose.prod.yaml restart"
echo ""
echo "To update application:"
echo "  git pull origin production-setup"
echo "  docker-compose -f docker-compose.prod.yaml build"
echo "  docker-compose -f docker-compose.prod.yaml up -d"
echo ""

# 18. Display service URLs
echo "Service URLs (after DNS setup):"
echo "  - Main site: http://benj.run.place"
echo "  - Admin: http://benj.run.place/admin/"
echo "  - Health check: http://benj.run.place/health/"
echo ""
print_status "Setup complete! Please configure DNS for benj.run.place to point to this server."

print_status "Don't forget to:"
print_status "1. Configure DNS A record for benj.run.place"
print_status "2. Setup SSL certificate with Let's Encrypt"
print_status "3. Test all endpoints"
print_status "4. Configure backups"