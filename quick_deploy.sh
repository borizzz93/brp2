#!/bin/bash

# Quick deployment script with port conflict resolution
# Author: MiniMax Agent

set -e

echo "🚀 Misago Quick Deploy - Port Conflict Resolution"
echo "=================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    exit 1
fi

# Stop existing containers
print_status "Stopping existing containers..."
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Check port availability
print_status "Checking port availability..."
PORT_80_STATUS="available"
PORT_443_STATUS="available"

if lsof -i :80 &>/dev/null; then
    print_warning "Port 80 is in use"
    PORT_80_STATUS="busy"
fi

if lsof -i :443 &>/dev/null; then
    print_warning "Port 443 is in use"
    PORT_443_STATUS="busy"
fi

# Choose compose file
COMPOSE_FILE="docker-compose.prod.yaml"
if [ "$PORT_80_STATUS" = "busy" ]; then
    print_status "Using improved compose file with alternative ports..."
    COMPOSE_FILE="docker-compose.prod.improved.yaml"
    
    # Start with backup ports first
    print_status "Starting services with backup ports (8080, 8443)..."
    COMPOSE_FILE="docker-compose.prod.improved.yaml" docker-compose up -d postgres redis web celery-worker celery-beat
    
    # Wait for services
    print_status "Waiting for services to start..."
    sleep 60
    
    # Test connectivity
    print_status "Testing service connectivity..."
    if curl -f http://localhost:8080/health/ &>/dev/null; then
        print_status "✅ Services running on backup ports!"
        print_status "🌐 Access your site at: http://benj.run.place:8080"
        print_status "⚠️  Note: You'll need to configure port forwarding for port 8080"
    else
        print_error "Services failed to start properly"
        docker-compose -f docker-compose.prod.improved.yaml logs
        exit 1
    fi
else
    # Standard ports are available
    print_status "Standard ports (80, 443) are available!"
    COMPOSE_FILE="docker-compose.prod.yaml" docker-compose up -d
    
    print_status "Waiting for services to start..."
    sleep 60
    
    # Test connectivity
    if curl -f http://localhost/health/ &>/dev/null; then
        print_status "✅ Services running on standard ports!"
        print_status "🌐 Access your site at: http://benj.run.place"
    else
        print_error "Services failed to start properly"
        docker-compose logs
        exit 1
    fi
fi

# Final status
echo ""
echo "🎉 Deployment Status:"
echo "======================"
docker-compose -f $COMPOSE_FILE ps

echo ""
echo "📊 Service URLs:"
if [ "$PORT_80_STATUS" = "busy" ]; then
    echo "  🌍 Main site: http://benj.run.place:8080"
    echo "  👤 Admin: http://benj.run.place:8080/admin/"
    echo "  ❤️  Health: http://benj.run.place:8080/health/"
    echo ""
    echo "⚠️  Configure port forwarding for port 8080 to access from internet"
else
    echo "  🌍 Main site: http://benj.run.place"
    echo "  👤 Admin: http://benj.run.place/admin/"
    echo "  ❤️  Health: http://benj.run.place/health/"
fi

echo ""
echo "🛠️  Useful Commands:"
echo "  View logs: docker-compose -f $COMPOSE_FILE logs -f"
echo "  Restart: docker-compose -f $COMPOSE_FILE restart"
echo "  Stop: docker-compose -f $COMPOSE_FILE down"
echo ""
print_status "Setup complete! 🎉"