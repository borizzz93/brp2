# Misago Production Deployment Guide
## Ubuntu 22.04 Server Setup

### Overview
This guide provides step-by-step instructions for deploying Misago forum software on Ubuntu 22.04 server with Docker and Docker Compose.

**Server Details:**
- IP Address: 84.21.189.163
- Domain: benj.run.place
- OS: Ubuntu 22.04 LTS

### Prerequisites

#### System Requirements
- Ubuntu 22.04 LTS server
- Minimum 2GB RAM (4GB recommended)
- Minimum 20GB disk space
- Root or sudo access

#### Required Software
- Docker Engine 24.0+
- Docker Compose 2.0+
- Nginx (for reverse proxy)
- Certbot (for SSL certificates)

### Step 1: Server Preparation

#### 1.1 Update System
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

#### 1.2 Install Docker
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin -y
```

#### 1.3 Install Additional Tools
```bash
sudo apt install -y curl wget unzip htop nginx certbot python3-certbot-nginx
```

### Step 2: Application Deployment

#### 2.1 Clone Repository
```bash
# Navigate to app directory
cd /opt

# If repository is not already cloned:
sudo git clone https://borizzz93/brp2.git misago
cd misago
```

#### 2.2 Setup Environment
```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env
```

**Required .env Configuration:**
```bash
# Django Configuration
DJANGO_SECRET_KEY=your-super-secret-key-here-generate-with-django-secret-key-generator
DJANGO_DEBUG=False
ALLOWED_HOSTS=benj.run.place,84.21.189.163,www.benj.run.place

# Database Configuration
POSTGRES_DB=misago
POSTGRES_USER=misago
POSTGRES_PASSWORD=generate-strong-database-password
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# Redis Configuration
REDIS_PASSWORD=generate-strong-redis-password

# Email Configuration
EMAIL_HOST=your-smtp-server
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@example.com
EMAIL_HOST_PASSWORD=your-email-password
DEFAULT_FROM_EMAIL=Misago <noreply@benj.run.place>

# Domain Configuration
DOMAIN_NAME=benj.run.place
SERVER_IP=84.21.189.163
```

#### 2.3 Run Deployment Script
```bash
# Make script executable
chmod +x deploy.sh

# Setup deployment environment
./deploy.sh setup

# Deploy the application
./deploy.sh deploy

# Setup initial data
./deploy.sh setup-initial
```

### Step 3: Nginx Configuration

#### 3.1 Update Nginx Configuration
```bash
# Copy production nginx config
sudo cp nginx/nginx.conf /etc/nginx/nginx.conf

# Copy site configuration
sudo cp nginx/sites-available/misago /etc/nginx/sites-available/misago

# Enable the site
sudo ln -sf /etc/nginx/sites-available/misago /etc/nginx/sites-enabled/

# Remove default site
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

#### 3.2 SSL Certificate Setup (Let's Encrypt)
```bash
# Install certbot if not already installed
sudo apt install certbot python3-certbot-nginx -y

# Obtain SSL certificate
sudo certbot --nginx -d benj.run.place -d www.benj.run.place

# Test automatic renewal
sudo certbot renew --dry-run
```

### Step 4: Systemd Service Setup

#### 4.1 Create Systemd Service
```bash
# Copy service file
sudo cp misago.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable and start service
sudo systemctl enable misago
sudo systemctl start misago
```

### Step 5: Firewall Configuration

#### 5.1 Configure UFW Firewall
```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow ssh

# Allow HTTP and HTTPS
sudo ufw allow 'Nginx Full'

# Allow custom ports if needed
sudo ufw allow 5432/tcp  # PostgreSQL (internal only)

# Check status
sudo ufw status
```

### Step 6: Monitoring and Maintenance

#### 6.1 Health Monitoring
```bash
# Check application health
./deploy.sh health

# Monitor resource usage
./deploy.sh monitor

# View logs
./deploy.sh logs web
```

#### 6.2 Backup Strategy
```bash
# Create manual backup
./deploy.sh backup

# Setup automated backups (add to crontab)
# 0 2 * * * /opt/misago/deploy.sh backup >> /var/log/misago-backup.log 2>&1
```

#### 6.3 Log Rotation
Create `/etc/logrotate.d/misago`:
```bash
/opt/misago/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    copytruncate
}
```

### Step 7: Performance Optimization

#### 7.1 Database Optimization
Edit PostgreSQL configuration in `docker-compose.prod.yaml`:
```yaml
postgres:
  image: postgres:15-alpine
  command: postgres -c shared_buffers=256MB -c effective_cache_size=1GB -c work_mem=4MB -c maintenance_work_mem=64MB
```

#### 7.2 Redis Optimization
Add Redis configuration to environment:
```bash
# Redis optimization settings
REDIS_MAXMEMORY=512mb
REDIS_MAXMEMORY_POLICY=allkeys-lru
```

### Step 8: Security Hardening

#### 8.1 Server Hardening
```bash
# Disable root SSH login
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Install fail2ban
sudo apt install fail2ban -y

# Configure fail2ban for nginx
sudo tee /etc/fail2ban/jail.local > /dev/null << EOF
[nginx-http-auth]
enabled = true

[nginx-noscript]
enabled = true

[nginx-badbots]
enabled = true
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

#### 8.2 Application Security
- Keep SECRET_KEY secure and unique
- Use strong passwords for all accounts
- Regularly update dependencies
- Monitor logs for suspicious activity
- Enable rate limiting

### Step 9: Troubleshooting

#### Common Issues and Solutions

**1. Database Connection Issues**
```bash
# Check PostgreSQL logs
docker-compose -f docker-compose.prod.yaml logs postgres

# Test database connection
docker-compose -f docker-compose.prod.yaml exec web python manage.py dbshell
```

**2. Static Files Not Loading**
```bash
# Collect static files
docker-compose -f docker-compose.prod.yaml exec web python manage.py collectstatic --noinput

# Check Nginx configuration
sudo nginx -t
```

**3. Memory Issues**
```bash
# Monitor resource usage
./deploy.sh monitor

# Check container logs
docker stats
```

**4. SSL Certificate Issues**
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates manually
sudo certbot renew
```

### Step 10: Maintenance Tasks

#### Regular Maintenance
1. **Daily**: Check application logs and system resources
2. **Weekly**: Update system packages and application backups
3. **Monthly**: Review security logs and update dependencies
4. **Quarterly**: SSL certificate renewal and security audit

#### Update Procedure
```bash
# Pull latest changes
git pull origin production-setup

# Run update script
./deploy.sh update

# Verify deployment
./deploy.sh health
```

### Contact and Support

For deployment issues or questions:
- Check application logs: `./deploy.sh logs`
- Review system status: `./deploy.sh status`
- Monitor resources: `./deploy.sh monitor`

### Production Checklist

- [ ] Server hardened and secured
- [ ] SSL certificates installed and working
- [ ] Database backups configured
- [ ] Monitoring and alerting setup
- [ ] Firewall rules configured
- [ ] Log rotation configured
- [ ] Health checks working
- [ ] Performance optimized
- [ ] Security audit completed
- [ ] Documentation updated

---

**Note**: This deployment is configured for production use with security, performance, and monitoring optimizations. Regularly review and update configurations based on your specific requirements and security best practices.