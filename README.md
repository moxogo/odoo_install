# Odoo 18 Production Installation Guide

This repository contains a production-ready Odoo 18 setup using Docker with enhanced security features, monitoring, and automated deployment capabilities.

## System Requirements

- Docker Engine 20.10.x or later
- Docker Compose V2
- Minimum 20GB free disk space

Core services (Odoo, PostgreSQL, Nginx, Redis) are handled by Docker containers.

## Features

### Container-Based Architecture
- Isolated services in containers
- Automatic dependency management
- Consistent environment across deployments
- Easy scaling and updates

### Security Features
- Container isolation
- UFW firewall configuration
- SSL/TLS with Certbot integration
- Protected environment variables
- Non-root container execution
- Limited container capabilities
- Read-only root filesystem
- Network isolation

### Host System Tools
- Certbot for SSL certificate management
- UFW for firewall management
- Network monitoring tools
- System maintenance utilities

### Performance Optimizations
- Redis session store for improved performance
- PostgreSQL optimized configuration
- Worker and process management
- Memory management and limits
- Connection pooling

### Monitoring & Maintenance
- Container health checks
- Resource usage monitoring
- Automated database backups
- Log rotation and management
- Redis cache monitoring

### Development Tools
- pgAdmin 4 web interface (dev profile)
- Database management tools
- Enhanced logging for debugging
- Test environment configuration

## Quick Start

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd odoo_install
   ```

2. Run the installation script:
   ```bash
   chmod +x install_production.sh
   sudo ./install_production.sh
   ```

3. Start development tools (optional):
   ```bash
   docker compose --profile dev up -d
   ```

## Configuration Files

### Environment Variables (.env)
```bash
# PostgreSQL Configuration
POSTGRES_DB=postgres
POSTGRES_USER=odoo
POSTGRES_PASSWORD=<generated>
POSTGRES_HOST=db
POSTGRES_PORT=5432

# Odoo Configuration
ODOO_ADMIN_PASSWD=<generated>
ODOO_DB_USER=odoo
ODOO_PROXY_MODE=True

# Nginx & SSL Configuration
NGINX_DOMAIN=your-domain.com
CERTBOT_EMAIL=your-email@example.com

# Backup Configuration
BACKUP_SCHEDULE=@daily
BACKUP_KEEP_DAYS=7
BACKUP_KEEP_WEEKS=4
BACKUP_KEEP_MONTHS=6

# Development Tools
PGADMIN_EMAIL=admin@localhost
PGADMIN_PASSWORD=admin
```

### Redis Configuration
Redis is configured for session storage with the following settings:
```ini
session_redis = True
session_redis_host = ${REDIS_HOST}
session_redis_port = 6379
session_redis_prefix = odoo
session_redis_expiration = 86400
```

### PostgreSQL Optimization
Key PostgreSQL settings for optimal performance:
```ini
shared_buffers = 1GB
effective_cache_size = 3GB
maintenance_work_mem = 256MB
work_mem = 10485kB
max_connections = 100
```

## Installation Process

The installation script performs the following:

### Pre-installation Checks
1. System Requirements
   - Disk space validation
   - Docker installation verification
   - Docker Compose version check

2. System Security
   - UFW firewall configuration
   - SSL certificate setup with Certbot
   - Secure file permissions

3. Service Conflict Resolution
   - Handles existing service conflicts
   - Verifies port availability
   - Manages existing data backup

### Required Packages
```bash
# Core utilities
apt-transport-https
ca-certificates
curl
software-properties-common
git

# SSL and security
certbot
python3-certbot-nginx
openssl
ufw

# Development tools
nano
python3-pip
net-tools
```

### Firewall Configuration
```bash
# Default SSH access
ufw allow 22/tcp

# Web traffic
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS

# Odoo ports
ufw allow 8069/tcp # Web interface
ufw allow 8072/tcp # Live chat/Longpolling
```

### Container Setup
1. Directory Structure
   ```
   /odoo/
   ├── config/
   │   ├── odoo.conf
   │   ├── postgresql.conf
   │   └── entrypoint.sh
   ├── nginx/
   │   ├── conf/
   │   ├── ssl/
   │   └── letsencrypt/
   ├── addons/
   ├── logs/
   ├── data/
   └── backup/
   ```

2. Security Configuration
   - Secure file permissions
   - Protected password storage
   - SSL certificate management

3. Container Health Checks
   - Service availability monitoring
   - Resource usage tracking
   - Automated recovery

## Services

### Core Services
- Odoo 18 Application Server
- PostgreSQL 16 Database
- Nginx Reverse Proxy
- Redis Session Store

### Maintenance Services
- Automated Database Backup
- Log Management
- Health Monitoring

### Development Services (Optional)
- pgAdmin 4 Web Interface
- Database Management Tools

## Maintenance Commands

### Service Management
```bash
# Start all services
docker compose up -d

# Start with development tools
docker compose --profile dev up -d

# View logs
docker compose logs -f [service_name]

# Stop services
docker compose down
```

### Backup Management
```bash
# Manual backup
docker exec odoo18_backup backup

# View backup logs
docker compose logs backup

# List backups
ls -l /odoo/backups
```

### Cache Management
```bash
# Clear Redis cache
docker compose exec redis redis-cli FLUSHALL

# Monitor Redis
docker compose exec redis redis-cli info
```

## Monitoring

### Health Checks
- Odoo application health check at `/web/health`
- PostgreSQL connection monitoring
- Redis connection status
- Backup service status

### Resource Monitoring
- Container CPU and memory usage
- Disk space monitoring
- Network traffic monitoring
- Cache hit/miss rates

### Log Management
- Centralized logging
- Log rotation
- Error tracking
- Performance metrics

## Security Best Practices

### System Security
- Regular security updates
- Firewall configuration
- SSL/TLS configuration
- File permissions

### Container Security
- Non-root execution
- Limited capabilities
- Read-only filesystem
- Network isolation

### Access Control
- Strong password policies
- API access control
- Database access restrictions
- Admin interface protection

## Troubleshooting

### Common Issues

1. Redis Connection Issues:
   ```bash
   docker compose logs redis
   docker compose exec redis redis-cli ping
   ```

2. Backup Service Issues:
   ```bash
   docker compose logs backup
   docker compose exec backup ls -l /backups
   ```

3. Performance Issues:
   ```bash
   # Check Redis stats
   docker compose exec redis redis-cli info stats

   # Check PostgreSQL activity
   docker compose exec db psql -U odoo -c "SELECT * FROM pg_stat_activity;"
   ```

### Log Locations
- Odoo: `/var/log/odoo/odoo.log`
- PostgreSQL: `/var/log/postgresql/`
- Nginx: `/var/log/nginx/`
- Redis: stdout of Redis container
- Backup: stdout of backup container

## Troubleshooting Installation Issues

#### Common Issues

1. SSL Certificate Problems
   ```bash
   # Generate new certificates
   certbot certonly --webroot -w /odoo/nginx/letsencrypt -d your-domain.com
   ```

2. Permission Issues
   ```bash
   # Fix common permission problems
   sudo chown -R $USER:$USER /odoo
   sudo chmod -R 750 /odoo
   sudo chmod 600 /odoo/.passwords
   ```

3. Container Mount Issues
   ```bash
   # Verify mount points
   docker compose config
   # Check volume permissions
   ls -la /odoo/*/
   ```

## Support and Updates

For support:
1. Check the logs
2. Review configuration files
3. Verify service health
4. Check resource usage
5. Review security settings

Regular updates:
```bash
# Update all services
docker compose pull
docker compose up -d

# Update system packages
sudo apt update && sudo apt upgrade -y
