# Misago Production Makefile
# Provides convenient commands for deployment and maintenance

.PHONY: help setup deploy start stop restart status logs clean backup restore test lint format security-check

# Variables
DOCKER_COMPOSE = docker-compose -f docker-compose.prod.yaml
PROJECT_NAME = misago
DOMAIN = benj.run.place
BACKUP_DIR = ./backups

# Default target
help:
	@echo "Misago Production Deployment Commands"
	@echo ""
	@echo "Available commands:"
	@echo "  setup            Setup deployment environment"
	@echo "  deploy           Deploy application to production"
	@echo "  start            Start all services"
	@echo "  stop             Stop all services"
	@echo "  restart          Restart all services"
	@echo "  status           Show service status"
	@echo "  logs             Show application logs"
	@echo "  logs-<service>   Show logs for specific service (web, postgres, redis, celery-worker)"
	@echo "  clean            Clean up Docker resources"
	@echo "  backup           Create database backup"
	@echo "  restore          Restore from backup (requires backup file)"
	@echo "  update           Update application to latest version"
	@echo "  test             Run application tests"
	@echo "  lint             Run code linting"
	@echo "  format           Format code"
	@echo "  security-check   Run security checks"
	@echo "  health           Check application health"
	@echo "  migrate          Run database migrations"
	@echo "  collectstatic    Collect static files"
	@echo "  shell            Open Django shell"
	@echo "  manage-<cmd>     Run Django management command"
	@echo ""
	@echo "Examples:"
	@echo "  make logs-web"
	@echo "  make backup"
	@echo "  make restore BACKUP=./backups/backup_20231228.sql"
	@echo "  make manage Createsuperuser"

# Setup
setup:
	@echo "Setting up deployment environment..."
	cp .env.example .env || true
	mkdir -p $(BACKUP_DIR) logs/nginx logs/app nginx/ssl
	@echo "Environment setup complete. Please update .env file with your values."

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	docker-compose -f docker-compose.yaml build
	docker-compose -f docker-compose.yaml up -d postgres redis
	@echo "Development environment is ready. Run 'make dev' to start development server."

# Deploy to production
deploy: setup
	@echo "Deploying Misago to production..."
	$(DOCKER_COMPOSE) build --no-cache
	$(DOCKER_COMPOSE) up -d
	@echo "Deployment complete!"

# Start services
start:
	@echo "Starting services..."
	$(DOCKER_COMPOSE) up -d

# Stop services
stop:
	@echo "Stopping services..."
	$(DOCKER_COMPOSE) stop

# Restart services
restart:
	@echo "Restarting services..."
	$(DOCKER_COMPOSE) restart

# Service management
status:
	@echo "Service Status:"
	$(DOCKER_COMPOSE) ps

logs:
	$(DOCKER_COMPOSE) logs -f

logs-web:
	$(DOCKER_COMPOSE) logs -f web

logs-postgres:
	$(DOCKER_COMPOSE) logs -f postgres

logs-redis:
	$(DOCKER_COMPOSE) logs -f redis

logs-celery:
	$(DOCKER_COMPOSE) logs -f celery-worker

logs-nginx:
	$(DOCKER_COMPOSE) logs -f nginx

# Database operations
backup:
	@echo "Creating database backup..."
	@mkdir -p $(BACKUP_DIR)
	$(DOCKER_COMPOSE) exec postgres pg_dump -U misago misago > $(BACKUP_DIR)/misago_backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Backup created successfully!"

restore:
	@if [ -z "$(BACKUP)" ]; then \
		echo "Please specify backup file: make restore BACKUP=./backups/backup.sql"; \
		exit 1; \
	fi
	@echo "Restoring database from $(BACKUP)..."
	@read -p "This will replace the current database. Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	$(DOCKER_COMPOSE) exec -T postgres psql -U misago misago < $(BACKUP)

# Application maintenance
update:
	@echo "Updating application..."
	@if [ -d ".git" ]; then \
		git pull origin production-setup || true; \
	fi
	$(DOCKER_COMPOSE) build --no-cache
	$(DOCKER_COMPOSE) up -d
	$(DOCKER_COMPOSE) exec web python manage.py migrate --noinput
	$(DOCKER_COMPOSE) exec web python manage.py collectstatic --noinput
	@echo "Update complete!"

# Testing
test:
	@echo "Running tests..."
	$(DOCKER_COMPOSE) exec web python manage.py test --verbosity=2

test-coverage:
	@echo "Running tests with coverage..."
	$(DOCKER_COMPOSE) exec web coverage run --source='.' manage.py test
	$(DOCKER_COMPOSE) exec web coverage report
	$(DOCKER_COMPOSE) exec web coverage html

# Code quality
lint:
	@echo "Running code linting..."
	$(DOCKER_COMPOSE) exec web flake8 misago/
	$(DOCKER_COMPOSE) exec web pylint misago/
	$(DOCKER_COMPOSE) exec web black --check misago/
	$(DOCKER_COMPOSE) exec web isort --check-only misago/

format:
	@echo "Formatting code..."
	$(DOCKER_COMPOSE) exec web black misago/
	$(DOCKER_COMPOSE) exec web isort misago/

security-check:
	@echo "Running security checks..."
	$(DOCKER_COMPOSE) exec web python manage.py check --deploy
	$(DOCKER_COMPOSE) exec web safety check

# Health and monitoring
health:
	@echo "Performing health check..."
	@curl -f http://localhost/health/ || (echo "Health check failed!"; exit 1)
	$(DOCKER_COMPOSE) exec web python manage.py check --database default
	@echo "Health check passed!"

monitor:
	@echo "Resource Usage:"
	@echo "=== Docker Containers ==="
	docker stats --no-stream
	@echo -e "\n=== Disk Usage ==="
	df -h
	@echo -e "\n=== Memory Usage ==="
	free -h

# Django management commands
migrate:
	$(DOCKER_COMPOSE) exec web python manage.py migrate

collectstatic:
	$(DOCKER_COMPOSE) exec web python manage.py collectstatic --noinput

shell:
	$(DOCKER_COMPOSE) exec web python manage.py shell

manage-%:
	$(DOCKER_COMPOSE) exec web python manage.py $*

# Database utilities
dbshell:
	$(DOCKER_COMPOSE) exec web python manage.py dbshell

createsuperuser:
	$(DOCKER_COMPOSE) exec web python manage.py createsuperuser

# Development commands
dev:
	docker-compose -f docker-compose.yaml up -d
	@echo "Development server starting at http://localhost:8000"

dev-down:
	docker-compose -f docker-compose.yaml down

# Cleanup
clean:
	@echo "Cleaning up Docker resources..."
	docker system prune -f
	docker volume prune -f
	@echo "Cleanup complete!"

clean-all:
	@echo "WARNING: This will remove all Docker containers, images, and volumes!"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	docker system prune -a -f
	docker volume prune -a -f

# SSL Certificate management
ssl-cert:
	@echo "Generating SSL certificate..."
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout nginx/ssl/misago.key \
		-out nginx/ssl/misago.crt \
		-subj "/C=US/ST=State/L=City/O=Organization/CN=$(DOMAIN)"
	@echo "SSL certificate generated!"

# Database backup schedule
schedule-backup:
	@echo "Setting up automated backup cron job..."
	@echo "Add this line to your crontab (crontab -e):"
	@echo "0 2 * * * cd $(PWD) && make backup >> backup.log 2>&1"

# System information
info:
	@echo "Misago Production Information"
	@echo "=============================="
	@echo "Domain: $(DOMAIN)"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Docker Compose File: docker-compose.prod.yaml"
	@echo "Backup Directory: $(BACKUP_DIR)"
	@echo ""
	@echo "Quick Commands:"
	@echo "  make status     - Check service status"
	@echo "  make logs       - View application logs"
	@echo "  make backup     - Create database backup"
	@echo "  make health     - Check application health"
	@echo ""
	@echo "URLs:"
	@echo "  Application: https://$(DOMAIN)"
	@echo "  Health Check: https://$(DOMAIN)/health/"
	@echo "  Admin: https://$(DOMAIN)/admin/"

# Docker management
docker-clean:
	@echo "Cleaning Docker environment..."
	docker container prune -f
	docker image prune -f

docker-rebuild:
	@echo "Rebuilding Docker images..."
	$(DOCKER_COMPOSE) down
	$(DOCKER_COMPOSE) build --no-cache
	$(DOCKER_COMPOSE) up -d

# Performance monitoring
performance-check:
	@echo "Running performance checks..."
	$(DOCKER_COMPOSE) exec web python manage.py check --deploy --settings=devproject.settings_production
	@echo "Checking database performance..."
	$(DOCKER_COMPOSE) exec postgres psql -U misago -d misago -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
	@echo "Checking Redis performance..."
	$(DOCKER_COMPOSE) exec web redis-cli -h redis info stats

# Log analysis
logs-error:
	@echo "Analyzing error logs..."
	$(DOCKER_COMPOSE) logs --tail=100 web | grep -i error || echo "No errors found in recent logs"

logs-access:
	@echo "Recent access logs:"
	@if [ -f logs/nginx/access.log ]; then \
		tail -20 logs/nginx/access.log; \
	else \
		echo "Access log not found"; \
	fi

# Maintenance
maintenance-on:
	@echo "Putting application in maintenance mode..."
	$(DOCKER_COMPOSE) exec web python manage.py maintenance_mode on
	@echo "Maintenance mode enabled"

maintenance-off:
	@echo "Disabling maintenance mode..."
	$(DOCKER_COMPOSE) exec web python manage.py maintenance_mode off
	@echo "Maintenance mode disabled"

# Installation check
check-install:
	@echo "Checking installation..."
	@which docker || (echo "Docker not found!"; exit 1)
	@which docker-compose || (echo "Docker Compose not found!"; exit 1)
	@test -f .env || (echo ".env file not found!"; exit 1)
	@test -f docker-compose.prod.yaml || (echo "Production docker-compose file not found!"; exit 1)
	@echo "Installation check passed!"

# Show this help message when no target is provided
.DEFAULT_GOAL := help