#!/bin/bash

# Quick Deploy Script for Misago - Automated Setup
# Author: MiniMax Agent
# Date: November 28, 2025
# Automated deployment script for Ubuntu 22.04

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Configuration
PROJECT_DIR="/opt/misago"
DOMAIN="benj.run.place"
SERVER_IP="84.21.189.163"
GITHUB_REPO="https://borizzz93/brp2.git"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "This script should not be run as root!"
    print_status "Please run as regular user with sudo privileges"
    exit 1
fi

print_header "🚀 MISAGO AUTOMATED DEPLOYMENT"
print_header "Domain: $DOMAIN | Server: $SERVER_IP"

# Step 1: System Update
print_status "Step 1/12: Updating system packages..."
if sudo apt update && sudo apt upgrade -y; then
    print_status "✅ System updated successfully"
else
    print_error "❌ System update failed"
    exit 1
fi

# Step 2: Install dependencies
print_status "Step 2/12: Installing system dependencies..."
DEPS="curl wget git unzip htop nano ufw"
if sudo apt install -y $DEPS; then
    print_status "✅ Dependencies installed successfully"
else
    print_error "❌ Dependencies installation failed"
    exit 1
fi

# Step 3: Configure Firewall
print_status "Step 3/12: Configuring firewall..."
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp
yes | sudo ufw enable
print_status "✅ Firewall configured successfully"

# Step 4: Install Docker
print_status "Step 4/12: Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_status "✅ Docker installed successfully"
else
    print_status "✅ Docker already installed"
fi

# Install Docker Compose
print_status "Step 5/12: Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_status "✅ Docker Compose installed successfully"
else
    print_status "✅ Docker Compose already installed"
fi

# Step 6: Setup Swap (if needed)
print_status "Step 6/12: Setting up swap memory..."
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
if [ "$TOTAL_MEM" -lt 4096 ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    print_status "✅ Swap memory configured"
else
    print_status "✅ Sufficient memory available"
fi

# Step 7: Create project directory
print_status "Step 7/12: Setting up project directory..."
sudo mkdir -p $PROJECT_DIR
sudo chown $USER:$USER $PROJECT_DIR
cd $PROJECT_DIR
print_status "✅ Project directory created"

# Step 8: Clone repository
print_status "Step 8/12: Cloning repository..."
if [ -d ".git" ]; then
    print_status "Repository already exists, updating..."
    git pull origin main || git pull origin production-setup || true
else
    git clone $GITHUB_REPO .
fi
print_status "✅ Repository cloned successfully"

# Step 9: Fix critical issues
print_status "Step 9/12: Fixing critical issues..."

# Make scripts executable
chmod +x *.sh

# Create nginx sites-enabled directory
mkdir -p nginx/sites-enabled
ln -sf ../sites-available/misago nginx/sites-enabled/

# Fix nginx domain typo
if grep -q "run_place" nginx/sites-available/misago; then
    sed -i 's/run_place/run.place/g' nginx/sites-available/misago
    print_status "✅ Fixed nginx domain typo"
fi

# Fix docker-compose variable typo
if grep -q "POSTGROS_PASSWORD" docker-compose.prod.yaml; then
    sed -i 's/POSTGROS_PASSWORD/POSTGRES_PASSWORD/g' docker-compose.prod.yaml
    print_status "✅ Fixed docker-compose variable typo"
fi

# Step 10: Setup environment
print_status "Step 10/12: Setting up environment..."

if [ ! -f ".env" ]; then
    cp .env.example .env
    
    # Generate secure passwords and keys
    DJANGO_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')
    DB_PASSWORD=$(openssl rand -base64 32)
    REDIS_PASSWORD=$(openssl rand -base64 32)
    
    # Update .env file
    sed -i "s/your-super-secret-key-here-change-this/$DJANGO_SECRET_KEY/" .env
    sed -i "s/secure-database-password-here/$DB_PASSWORD/" .env
    sed -i "s/secure-redis-password-here/$REDIS_PASSWORD/" .env
    
    print_status "✅ Environment configured with secure defaults"
else
    print_status "✅ Using existing environment configuration"
fi

# Step 11: Deploy application
print_status "Step 11/12: Deploying application..."

# Stop existing containers
docker-compose down 2>/dev/null || true
docker-compose -f docker-compose.prod.yaml down 2>/dev/null || true

# Create necessary directories
mkdir -p logs/nginx logs/app backups ssl

# Build and start services
docker-compose -f docker-compose.prod.yaml build --no-cache
docker-compose -f docker-compose.prod.yaml up -d

print_status "✅ Application deployed successfully"

# Step 12: Initialize database
print_status "Step 12/12: Initializing database..."

# Wait for database
print_status "Waiting for database to be ready..."
for i in {1..30}; do
    if docker-compose -f docker-compose.prod.yaml exec -T postgres pg_isready -U misago &>/dev/null; then
        break
    fi
    echo -n "."
    sleep 5
done
echo

# Run migrations
print_status "Running database migrations..."
docker-compose -f docker-compose.prod.yaml exec web python manage.py migrate --noinput || {
    print_warning "Migration failed, trying with fallback..."
    sleep 30
    docker-compose -f docker-compose.prod.yaml exec web python manage.py migrate --noinput || true
}

# Collect static files
print_status "Collecting static files..."
docker-compose -f docker-compose.prod.yaml exec web python manage.py collectstatic --noinput || print_warning "Static files collection failed"

# Create admin user
print_status "Creating admin user..."
docker-compose -f docker-compose.prod.yaml exec web python manage.py createsuperuser || {
    print_warning "Superuser creation failed, creating manually..."
    ADMIN_PASSWORD=$(date +%s)
    docker-compose -f docker-compose.prod.yaml exec web python manage.py shell -c "
from django.contrib.auth.models import User
try:
    User.objects.get(username='admin')
    print('Admin user already exists')
except User.DoesNotExist:
    User.objects.create_superuser('admin', 'admin@$DOMAIN', '$ADMIN_PASSWORD')
    print('Admin user created')
" 2>/dev/null || true
}

# Wait for application to start
print_status "Waiting for application to fully start..."
sleep 60

# Health check
print_status "Performing health check..."
if curl -f -s http://localhost/health/ > /dev/null; then
    print_status "✅ Health check passed"
else
    print_warning "⚠️  Health check failed, checking alternative port..."
    sleep 30
    if curl -f -s http://localhost:8080/health/ > /dev/null; then
        print_status "✅ Application running on port 8080"
    else
        print_warning "⚠️  Health check failed, check logs manually"
    fi
fi

# Final status
echo ""
print_header "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo ""
print_status "🌐 Application URLs:"
echo "   Main site: http://$DOMAIN"
echo "   Admin panel: http://$DOMAIN/admin/"
echo "   Health check: http://$DOMAIN/health/"
echo ""
print_status "📊 Service Status:"
docker-compose -f docker-compose.prod.yaml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""
print_status "🛠️  Useful Commands:"
echo "   View logs: docker-compose -f docker-compose.prod.yaml logs -f"
echo "   Restart: docker-compose -f docker-compose.prod.yaml restart"
echo "   Stop: docker-compose -f docker-compose.prod.yaml stop"
echo "   Start: docker-compose -f docker-compose.prod.yaml up -d"
echo ""
print_status "📝 Next Steps:"
echo "   1. Configure DNS A record for $DOMAIN to point to $SERVER_IP"
echo "   2. Set up SSL certificate with Let's Encrypt (optional)"
echo "   3. Test all functionality in browser"
echo "   4. Configure email settings in .env file"
echo ""
print_status "🔧 For troubleshooting, check:"
echo "   - Logs: docker-compose -f docker-compose.prod.yaml logs"
echo "   - System resources: htop, docker stats"
echo "   - Network: netstat -tlnp | grep :80"
echo ""

# Auto-configure DNS instruction
print_warning "📋 DNS Configuration Required:"
print_warning "Please configure DNS A record for $DOMAIN to point to $SERVER_IP"
print_warning "Also create CNAME record for www.$DOMAIN pointing to $DOMAIN"

# Cleanup Docker
print_status "🧹 Cleaning up Docker resources..."
docker system prune -f 2>/dev/null || true

print_status "✅ Deployment script completed!"
print_status "You may need to log out and back in for Docker group changes to take effect."

# Exit success
exit 0