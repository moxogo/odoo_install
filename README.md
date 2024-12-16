# Odoo 18 Production Installation Guide

This repository contains a production-ready Odoo 18 setup using Docker with enhanced security features, monitoring, and automated deployment capabilities.

## System Requirements

- Ubuntu 20.04 LTS or later
- Minimum 2 CPU cores
- Minimum 4GB RAM (8GB recommended)
- Minimum 20GB free disk space
- Docker Engine 20.10.x or later
- Docker Compose V2

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

## Detailed Installation Steps

### 1. Pre-Installation Checks

The installation script automatically performs these checks:
- System requirements verification
- Port availability (80, 443, 5432, 8069, 8072)
- Existing services (Nginx, PostgreSQL)
- Directory permissions
- Docker installation

### 2. Security Features

- Automatic firewall configuration with UFW
- Secure file permissions
- Protected environment variables
- Non-root container execution
- Limited container capabilities
- Automated security updates
- SSL/TLS configuration

### 3. Directory Structure

```
/odoo/
├── addons/             # Custom and community addons
├── config/             # Odoo configuration
├── nginx/              # Nginx configuration
│   ├── conf/          # Server blocks
│   ├── ssl/           # SSL certificates
│   └── letsencrypt/   # Let's Encrypt challenges
├── logs/              # Log files
└── static/            # Static files
```

### 4. Configuration Files

#### Environment Variables (.env)
```bash
POSTGRES_DB=postgres
POSTGRES_USER=odoo
POSTGRES_PASSWORD=<generated>
ODOO_ADMIN_PASSWD=<generated>
DOMAIN=your-domain.com
EMAIL=your-email@domain.com
```

#### PostgreSQL Configuration
- Optimized for production use
- Automatic backup configuration
- Connection pooling
- Performance monitoring

#### Nginx Configuration
- SSL/TLS configuration
- HTTP/2 support
- Reverse proxy settings
- Load balancing (if multiple workers)

## Maintenance Commands

### Database Management

1. Create Backup:
   ```bash
   docker exec -t odoo16-db pg_dump -U odoo postgres > backup.sql
   ```

2. Restore Backup:
   ```bash
   cat backup.sql | docker exec -i odoo16-db psql -U odoo postgres
   ```

### Container Management

1. Start Services:
   ```bash
   cd /odoo && docker compose up -d
   ```

2. Stop Services:
   ```bash
   docker compose down
   ```

3. View Logs:
   ```bash
   docker compose logs -f
   ```

4. Update Containers:
   ```bash
   docker compose pull
   docker compose up -d
   ```

### SSL Certificate Management

1. Initial Certificate:
   ```bash
   sudo certbot certonly --webroot -w /odoo/nginx/letsencrypt -d your-domain.com
   ```

2. Renew Certificate:
   ```bash
   sudo certbot renew
   ```

## Monitoring

### System Monitoring
- Container health checks
- Resource usage monitoring
- Log monitoring
- Database performance monitoring

### Security Monitoring
- Failed login attempts
- System access logs
- File integrity monitoring
- Network security monitoring

## Backup Strategy

### Automated Backups
- Daily database backups
- Weekly full system backups
- Secure offsite storage
- Backup rotation policy

### Backup Verification
- Automated backup testing
- Restore verification
- Data integrity checks

## Troubleshooting

### Common Issues

1. Port Conflicts:
   ```bash
   sudo netstat -tulpn | grep -E ':(80|443|5432|8069|8072)'
   ```

2. Permission Issues:
   ```bash
   sudo chown -R root:$USER /odoo
   sudo chmod -R 750 /odoo
   ```

3. Docker Issues:
   ```bash
   docker compose down
   docker system prune
   docker compose up -d
   ```

### Log Locations
- Odoo Logs: `/odoo/logs/odoo/`
- Nginx Logs: `/odoo/logs/nginx/`
- PostgreSQL Logs: `/odoo/logs/postgresql/`

## Security Best Practices

1. Regular Updates:
   ```bash
   sudo apt update && sudo apt upgrade -y
   docker compose pull
   ```

2. Firewall Rules:
   ```bash
   sudo ufw status
   sudo ufw enable
   ```

3. SSL/TLS Configuration:
   - Minimum TLS 1.2
   - Strong cipher suites
   - HSTS enabled
   - Regular certificate renewal

## Performance Tuning

### Odoo Configuration
- Worker configuration
- Memory management
- Cache settings
- Database optimization

### PostgreSQL Tuning
- Memory allocation
- Connection pooling
- Query optimization
- Vacuum settings

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and feature requests, please create an issue in the repository.
