#!/bin/bash

# Load environment variables
set -a
source .env
set +a

# Function to print status messages
print_status() {
    echo "==> $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_status "Please run as root"
    exit 1
fi

# Configuration
BACKUP_DIR="/var/backups/odoo"
BACKUP_RETENTION_DAYS=7
GPG_RECIPIENT="your-gpg-key@email.com"  # Change this to your GPG key email
timestamp=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to cleanup old backups
cleanup_old_backups() {
    print_status "Cleaning up old backups..."
    find "$BACKUP_DIR" -type f -name "*.tar.gz.gpg" -mtime +$BACKUP_RETENTION_DAYS -delete
}

# Function to check available disk space
check_disk_space() {
    local required_space=5120  # 5GB in MB
    local available_space=$(df -m "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_status "Error: Not enough disk space. Required: 5GB, Available: ${available_space}MB"
        exit 1
    fi
}

# Check prerequisites
print_status "Checking prerequisites..."
if ! command -v gpg >/dev/null 2>&1; then
    print_status "Installing GPG..."
    apt-get update && apt-get install -y gnupg
fi

# Check disk space
check_disk_space

# Create temporary directory
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

# Backup Odoo filestore
print_status "Backing up Odoo filestore..."
docker-compose exec -T odoo tar czf - /var/lib/odoo > "$temp_dir/filestore.tar.gz"

# Backup PostgreSQL database
print_status "Backing up PostgreSQL database..."
docker-compose exec -T db pg_dumpall -U "$POSTGRES_USER" > "$temp_dir/db_backup.sql"

# Backup configuration files
print_status "Backing up configuration files..."
cp -r config nginx certbot "$temp_dir/"
cp docker-compose.yml .env postgresql.conf "$temp_dir/"

# Create backup archive
print_status "Creating backup archive..."
backup_file="$BACKUP_DIR/odoo_backup_${timestamp}.tar.gz"
tar -czf "$backup_file" -C "$temp_dir" .

# Encrypt backup
print_status "Encrypting backup..."
gpg --recipient "$GPG_RECIPIENT" --encrypt "$backup_file"
rm "$backup_file"  # Remove unencrypted backup

# Verify backup
print_status "Verifying backup..."
if gpg --list-only "$backup_file.gpg" >/dev/null 2>&1; then
    print_status "Backup verified successfully"
else
    print_status "Error: Backup verification failed"
    exit 1
fi

# Cleanup old backups
cleanup_old_backups

print_status "Backup completed successfully!"
print_status "Backup location: $backup_file.gpg"
print_status "To decrypt: gpg --decrypt $backup_file.gpg > $backup_file"

# Create backup report
cat << EOF > "$BACKUP_DIR/backup_report_${timestamp}.txt"
Backup Report
============
Date: $(date)
Backup File: $backup_file.gpg
Size: $(ls -lh "$backup_file.gpg" | awk '{print $5}')

Contents:
- Odoo Filestore
- PostgreSQL Database
- Configuration Files
- Docker Compose Files
- Environment Files

To restore this backup:
1. Decrypt the backup:
   gpg --decrypt $backup_file.gpg > $backup_file

2. Extract the backup:
   tar -xzf $backup_file

3. Stop the current Odoo instance:
   docker-compose down

4. Restore the database:
   cat db_backup.sql | docker-compose exec -T db psql -U $POSTGRES_USER

5. Restore the filestore:
   tar -xzf filestore.tar.gz -C /var/lib/odoo

6. Update configuration if needed

7. Restart Odoo:
   docker-compose up -d
EOF

print_status "Backup report created: $BACKUP_DIR/backup_report_${timestamp}.txt"
