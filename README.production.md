# Misago Production Deployment
## Production-Ready Forum Software for Ubuntu 22.04

This repository contains a production-ready deployment configuration for Misago, a modern Django-based forum software, configured for deployment on Ubuntu 22.04 server.

### 🚀 Quick Start

1. **Clone and Setup**
   ```bash
   git clone https://borizzz93/brp2.git
   cd brp1
   ```

2. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   nano .env
   ```

3. **Deploy**
   ```bash
   ./deploy.sh setup
   ./deploy.sh deploy
   ./deploy.sh setup-initial
   ```

4. **Access Your Forum**
   - Application: https://benj.run.place
   - Admin Panel: https://benj.run.place/admin/
   - Health Check: https://benj.run.place/health/

### 📋 Features

- **Production-Ready**: Optimized for high-performance production use
- **Docker Deployment**: Containerized with Docker Compose
- **Nginx Reverse Proxy**: SSL termination and static file serving
- **PostgreSQL Database**: Production-grade database setup
- **Redis Caching**: High-performance caching layer
- **Celery Workers**: Background task processing
- **Health Monitoring**: Comprehensive health check endpoints
- **Automated Backups**: Database and file backup automation
- **Security Hardened**: SSL, security headers, and rate limiting
- **Performance Optimized**: Caching, compression, and resource optimization

### 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │────│    Nginx        │────│   Django App    │
│   (Optional)    │    │  Reverse Proxy  │    │   (Web)         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                ┌─────────────────┐    │
                                │   PostgreSQL    │◄───┼──┐
                                │   Database      │    │  │
                                └─────────────────┘    │  │
                                ┌─────────────────┐    │  │
                                │     Redis       │◄───┼──┤
                                │     Cache       │    │  │
                                └─────────────────┘    │  │
                                ┌─────────────────┐    │  │
                                │  Celery Worker  │◄───┘  │
                                │ Background Tasks│       │
                                └─────────────────┘       │
                                ┌─────────────────┐       │
                                │   Nginx         │       │
                                │ Static/Media    │◄──────┘
                                │   Files         │
                                └─────────────────┘
```

### 🔧 Configuration

#### Environment Variables

Key environment variables that need to be configured in `.env`:

```bash
# Django
DJANGO_SECRET_KEY=your-super-secret-key
DJANGO_DEBUG=False
ALLOWED_HOSTS=benj.run.place,84.21.189.163

# Database
POSTGRES_DB=misago
POSTGRES_USER=misago
POSTGRES_PASSWORD=secure-password
POSTGRES_HOST=postgres

# Redis
REDIS_PASSWORD=secure-redis-password

# Email
EMAIL_HOST=smtp.gmail.com
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-password
```

#### Production Settings

- **Debug Mode**: Disabled for production
- **SSL**: Enforced with HSTS headers
- **Database**: PostgreSQL with connection pooling
- **Cache**: Redis for session and data caching
- **Static Files**: Served by Nginx with caching
- **Security**: CSP headers, rate limiting, CSRF protection

### 🛠️ Management Commands

#### Using Deployment Script
```bash
./deploy.sh setup          # Setup environment
./deploy.sh deploy         # Deploy application
./deploy.sh start          # Start services
./deploy.sh stop           # Stop services
./deploy.sh restart        # Restart services
./deploy.sh status         # Check status
./deploy.sh logs           # View logs
./deploy.sh backup         # Create backup
./deploy.sh health         # Health check
```

#### Using Make
```bash
make help                  # Show all commands
make setup                 # Setup environment
make deploy                # Deploy application
make logs-web              # View web logs
make backup                # Create backup
make health                # Check health
make migrate               # Run migrations
make collectstatic         # Collect static files
```

### 📊 Monitoring & Health Checks

#### Health Check Endpoints

- `/health/` - Overall health status
- `/ready/` - Kubernetes readiness probe
- `/live/` - Kubernetes liveness probe  
- `/metrics/` - Application metrics

#### Monitoring Commands

```bash
# Check service status
./deploy.sh status
make status

# Monitor resource usage
./deploy.sh monitor
make monitor

# View application logs
./deploy.sh logs web
make logs-web

# Database status
make dbshell
```

### 🔐 Security Features

- **SSL/TLS**: HTTPS enforcement with modern ciphers
- **Security Headers**: CSP, HSTS, X-Frame-Options, etc.
- **Rate Limiting**: Protection against DDoS and abuse
- **CSRF Protection**: Cross-site request forgery prevention
- **SQL Injection Protection**: Django ORM with parameterized queries
- **XSS Protection**: Content Security Policy and output escaping
- **Secure Cookies**: HttpOnly and Secure flags
- **Docker Security**: Non-root containers, minimal images

### 💾 Backup & Recovery

#### Automatic Backups

Database backups are created automatically. Configure in crontab:
```bash
# Daily backup at 2 AM
0 2 * * * cd /opt/misago && ./deploy.sh backup >> backup.log 2>&1
```

#### Manual Backup/Restore

```bash
# Create backup
./deploy.sh backup
# or
make backup

# Restore from backup
./deploy.sh restore ./backups/misago_backup_20231228_120000.sql
# or
make restore BACKUP=./backups/backup.sql
```

### 🚀 Performance Optimization

#### Caching Strategy
- **Redis**: Session storage and data caching
- **Nginx**: Static file caching with gzip compression
- **Django**: Template and data caching
- **Database**: Query optimization and indexing

#### Resource Limits
- **Memory**: Limited container memory usage
- **CPU**: Process limits and optimization
- **Storage**: Efficient storage with volume management
- **Network**: Connection pooling and keep-alive

### 🔄 Updates & Maintenance

#### Application Updates

```bash
# Pull latest changes
git pull origin production-setup

# Update application
./deploy.sh update
# or
make update
```

#### System Maintenance

```bash
# Clean up Docker resources
make clean

# Check for security issues
make security-check

# Update system packages (on host)
sudo apt update && sudo apt upgrade
```

### 🐛 Troubleshooting

#### Common Issues

1. **Database Connection Failed**
   ```bash
   docker-compose -f docker-compose.prod.yaml logs postgres
   ```

2. **Static Files Not Loading**
   ```bash
   make collectstatic
   sudo nginx -t && sudo systemctl restart nginx
   ```

3. **SSL Certificate Issues**
   ```bash
   sudo certbot certificates
   sudo certbot renew --dry-run
   ```

4. **High Memory Usage**
   ```bash
   make monitor
   ./deploy.sh logs --tail=100
   ```

#### Log Locations

- **Application Logs**: `./logs/app/`
- **Nginx Logs**: `./logs/nginx/`
- **Docker Logs**: `docker-compose logs`
- **System Logs**: `/var/log/`

### 📈 Scaling

#### Horizontal Scaling

For high traffic, consider:

1. **Load Balancer**: Add HAProxy or AWS ELB
2. **Multiple Web Instances**: Scale Django containers
3. **Database Scaling**: Read replicas or sharding
4. **Redis Cluster**: Distributed caching
5. **CDN**: CloudFlare or AWS CloudFront

#### Resource Requirements

- **Minimum**: 2GB RAM, 2 CPU cores, 20GB storage
- **Recommended**: 4GB RAM, 4 CPU cores, 50GB storage
- **High Traffic**: 8GB+ RAM, 8+ CPU cores, 100GB+ storage

### 📚 Additional Resources

- **Misago Documentation**: https://misago.gitbook.io/docs/
- **Django Documentation**: https://docs.djangoproject.com/
- **Docker Documentation**: https://docs.docker.com/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **Nginx Documentation**: https://nginx.org/en/docs/

### 🆘 Support

For issues and support:

1. Check the logs first: `./deploy.sh logs`
2. Run health check: `./deploy.sh health`
3. Review configuration: `make info`
4. Check system resources: `make monitor`

### 📄 License

This deployment configuration is provided under the same license as Misago itself. See LICENSE.rst for details.

---

**Production Ready Forum Deployment for Ubuntu 22.04**  
Configured for benj.run.place (84.21.189.163)  
Last updated: 2025-11-28