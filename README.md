# Odoo 18 Docker Installation Guide

This repository contains Docker configuration for running Odoo 18 in a production-ready environment with proper security settings and resource management.

## Prerequisites

- Docker Engine (20.10.x or later)
- Docker Compose V2 (2.x or later)
- Git
- 4GB RAM minimum (8GB recommended)
- 10GB free disk space

## Directory Structure

```
.
├── addons/             # Custom and community addons
├── config/             # Odoo configuration files
├── logs/               # Odoo log files
├── docker-compose.yml  # Docker compose configuration
├── Dockerfile         # Odoo image build configuration
└── .env               # Environment variables (create from .env.example)
```

## Quick Start

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd odoo_install
   ```

2. Create and configure the environment file:
   ```bash
   cp .env.example .env
   # Edit .env file with your settings
   ```

3. Start the containers:
   ```bash
   docker compose up -d
   ```

4. Access Odoo:
   - Web Interface: http://localhost:8069
   - Master password: Check your .env file

## Configuration

### Environment Variables (.env)

- `ODOO_DB_USER`: PostgreSQL user for Odoo
- `ODOO_DB_PASSWORD`: PostgreSQL password
- `POSTGRES_DB`: Default database name
- `POSTGRES_PASSWORD`: PostgreSQL admin password
- `ODOO_ADMIN_PASSWD`: Odoo master password

### Resource Limits

The docker-compose.yml includes resource limits for stability:
- CPU: 2 cores maximum
- Memory: 4GB maximum
- Reserved: 1 CPU core, 2GB RAM

### Security Features

- Non-root user execution
- Limited container capabilities
- Read-only file system where possible
- Health checks enabled
- Automatic container restart

## Shell Scripts

This repository includes several utility scripts to help manage your Odoo installation:

### Security Scripts

#### `security_audit.sh`
Performs comprehensive security audit of the system:
- Gathers system information (OS, CPU, memory, disk usage)
- Checks installed security packages
- Audits firewall rules and open ports
- Scans for rootkits and malware
- Generates detailed audit report

Usage:
```bash
sudo ./security_audit.sh
```

#### `harden_ubuntu.sh`
System hardening script for Ubuntu servers:
- Configures UFW firewall
- Sets up fail2ban
- Hardens SSH configuration
- Updates system packages
- Configures secure kernel parameters

Usage:
```bash
sudo ./harden_ubuntu.sh
```

### Backup and Maintenance

#### `backup.sh`
Automated backup script with encryption:
- Creates encrypted backups of Odoo database
- Supports GPG encryption for secure storage
- Implements backup rotation (default: 7 days)
- Checks available disk space before backup
- Compresses backup files

Usage:
```bash
sudo ./backup.sh
```

Configuration in script:
- `BACKUP_DIR`: Backup storage location
- `BACKUP_RETENTION_DAYS`: Number of days to keep backups
- `GPG_RECIPIENT`: GPG key for encryption

#### `cleanup.sh`
System cleanup and maintenance:
- Removes old Docker containers and images
- Cleans up temporary files
- Purges old logs
- Optimizes disk space

Usage:
```bash
sudo ./cleanup.sh
```

### Deployment Scripts

#### `deploy.sh`
Manages deployment of Odoo instance:
- Pulls latest code changes
- Rebuilds Docker containers
- Updates Python dependencies
- Performs database migrations
- Restarts services

Usage:
```bash
./deploy.sh [environment]
```

#### `post_deploy.sh`
Post-deployment configuration and checks:
- Updates Odoo modules
- Rebuilds assets
- Verifies system health
- Sets up cron jobs
- Configures logging

Usage:
```bash
sudo ./post_deploy.sh
```

#### `init-letsencrypt.sh`
Sets up SSL certificates using Let's Encrypt:
- Obtains SSL certificates
- Configures Nginx for HTTPS
- Sets up auto-renewal
- Creates strong DH parameters

Usage:
```bash
sudo ./init-letsencrypt.sh
```

### Monitoring

#### `monitor.sh`
System monitoring and alerting:
- Monitors system resources (CPU, memory, disk)
- Checks container health
- Monitors Odoo log files
- Sends alerts for critical issues
- Generates performance reports

Usage:
```bash
./monitor.sh [--alert-email=admin@example.com]
```

## Environment Variables

The following environment variables can be configured in your `.env` file:

### Database Configuration
```bash
POSTGRES_DB=postgres
POSTGRES_USER=odoo
POSTGRES_PASSWORD=your_secure_password
```

### Odoo Configuration
```bash
ODOO_DB_HOST=db
ODOO_DB_USER=odoo
ODOO_DB_PASSWORD=your_secure_password
ODOO_ADMIN_PASSWD=admin_secure_password
```

### Backup Configuration
```bash
BACKUP_DIR=/var/backups/odoo
BACKUP_RETENTION_DAYS=7
GPG_RECIPIENT=your-gpg-key@email.com
```

## Maintenance Commands

### Backup Database
```bash
docker exec -t odoo18 odoo-bin -c /etc/odoo/odoo.conf backup --database=[DB_NAME] --master-password=[MASTER_PASSWORD]
```

### Update Modules
```bash
docker exec -t odoo18 odoo-bin -c /etc/odoo/odoo.conf -d [DB_NAME] -u [MODULE_NAME]
```

### View Logs
```bash
docker compose logs -f odoo
```

## Production Deployment

Additional considerations for production:
1. Configure SSL/TLS with a reverse proxy (e.g., Nginx)
2. Set up regular database backups
3. Monitor container health and resource usage
4. Configure proper logging rotation

## Troubleshooting

1. Container won't start:
   - Check logs: `docker compose logs odoo`
   - Verify PostgreSQL connection
   - Ensure correct file permissions

2. Performance issues:
   - Review and adjust resource limits
   - Monitor system resources
   - Check Odoo logs for bottlenecks

3. Database connection issues:
   - Verify environment variables
   - Check network connectivity
   - Ensure PostgreSQL container is healthy

## Upgrading

To upgrade to a newer version:

1. Backup your database
2. Update the Odoo version in Dockerfile
3. Rebuild containers:
   ```bash
   docker compose down
   docker compose build --no-cache
   docker compose up -d
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
