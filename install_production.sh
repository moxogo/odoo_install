#!/bin/bash

# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Function to handle errors
handle_error() {
    local line_num=$1
    local error_code=$2
    local last_command=${BASH_COMMAND}
    
    error "Error occurred in script at line: $line_num"
    error "Last command executed: $last_command"
    error "Error code: $error_code"
    
    # Cleanup on error if specified
    if [ "${CLEANUP_ON_ERROR:-false}" = "true" ] && [ -d "/odoo" ]; then
        warn "Cleaning up /odoo directory..."
        sudo rm -rf /odoo
    fi
    
    exit $error_code
}

# Set up error handling
trap 'handle_error ${LINENO} $?' ERR

# Function to check system requirements
check_system_requirements() {
    log "Checking system requirements..."
    
    # Check OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            error "This script requires Ubuntu. Current OS: $ID"
            exit 1
        fi
        if [[ "${VERSION_ID}" < "20.04" ]]; then
            error "This script requires Ubuntu 20.04 or later. Current version: $VERSION_ID"
            exit 1
        fi
    else
        error "Cannot determine OS version"
        exit 1
    fi

    # Check CPU cores
    CPU_CORES=$(nproc)
    if [ "$CPU_CORES" -lt 2 ]; then
        error "Minimum 2 CPU cores required, found: $CPU_CORES"
        exit 1
    fi
    log "CPU cores check passed: $CPU_CORES cores available"
    
    # Check RAM
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_RAM" -lt 4 ]; then
        error "Minimum 4GB RAM required, found: ${TOTAL_RAM}GB"
        exit 1
    fi
    log "RAM check passed: ${TOTAL_RAM}GB available"
    
    # Check disk space
    FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$FREE_SPACE" -lt 20 ]; then
        error "Minimum 20GB free space required, found: ${FREE_SPACE}GB"
        exit 1
    fi
    log "Disk space check passed: ${FREE_SPACE}GB available"
}

# Function to check network ports
check_network_ports() {
    log "Checking network ports..."
    local ports=(80 443 5432 8069 8072)
    local used_ports=()
    
    for port in "${ports[@]}"; do
        if sudo lsof -i ":$port" &>/dev/null || netstat -tuln | grep -q ":$port "; then
            used_ports+=("$port")
        fi
    done
    
    if [ ${#used_ports[@]} -ne 0 ]; then
        error "The following ports are in use: ${used_ports[*]}"
        echo "Please free up these ports before continuing"
        exit 1
    fi
    
    log "All required ports are available"
}

# Function to backup existing configuration
backup_existing_config() {
    if [ -d "/odoo" ]; then
        local BACKUP_DIR="/odoo_backup_$(date +%Y%m%d_%H%M%S)"
        warn "Existing /odoo directory found"
        log "Backing up existing /odoo directory to $BACKUP_DIR"
        sudo cp -r /odoo "$BACKUP_DIR"
        log "Backup completed"
    fi
}

# Function to handle Nginx
handle_nginx() {
    log "Checking for existing Nginx installation..."
    
    # Check if Nginx is running
    if pgrep -x "nginx" > /dev/null || systemctl is-active --quiet nginx; then
        warn "Nginx is currently running"
        
        # Stop Nginx service
        if systemctl is-active --quiet nginx; then
            log "Stopping Nginx service..."
            if ! sudo systemctl stop nginx; then
                error "Failed to stop Nginx service"
                exit 1
            fi
            log "Disabling Nginx service..."
            if ! sudo systemctl disable nginx; then
                warn "Failed to disable Nginx service"
            fi
        fi

        # Kill any remaining Nginx processes
        if pgrep -x "nginx" > /dev/null; then
            log "Killing remaining Nginx processes..."
            if ! sudo pkill -f nginx; then
                error "Failed to kill Nginx processes"
                exit 1
            fi
        fi

        # Remove Nginx packages if requested
        while true; do
            read -p "Do you want to (R)emove Nginx packages or just (K)eep them stopped? [R/K] " -n 1 -r
            echo
            case $REPLY in
                [Rr]* )
                    log "Removing Nginx packages..."
                    if ! sudo apt-get remove nginx nginx-common -y; then
                        warn "Failed to remove Nginx packages"
                    fi
                    if ! sudo apt-get autoremove -y; then
                        warn "Failed to autoremove packages"
                    fi
                    # Clean up Nginx directories
                    if [ -d "/etc/nginx" ] || [ -d "/var/log/nginx" ]; then
                        log "Cleaning up Nginx directories..."
                        sudo rm -rf /etc/nginx /var/log/nginx
                    fi
                    break;;
                [Kk]* )
                    log "Keeping Nginx packages but service is stopped"
                    break;;
                * ) echo "Please answer R or K.";;
            esac
        done
    fi

    # Verify port 80 is free
    for i in {1..5}; do
        if ! netstat -tuln | grep -q ":80 "; then
            log "Port 80 is now available"
            return 0
        fi
        log "Waiting for port 80 to be released... (attempt $i/5)"
        sleep 2
    done

    error "Port 80 is still in use after stopping Nginx. Please check for other services using this port."
    exit 1
}

# Function to handle PostgreSQL
check_postgresql() {
    log "Checking for existing PostgreSQL installation..."
    if systemctl is-active --quiet postgresql || dpkg -l | grep -q postgresql; then
        log "WARNING: PostgreSQL is running on the system"
        log "WARNING: This might conflict with Docker PostgreSQL"
        while true; do
            read -p "Do you want to (S)top, (R)emove, or (K)eep the system PostgreSQL? [S/R/K] " choice
            case "$choice" in
                [Ss]* )
                    log "Stopping PostgreSQL..."
                    systemctl stop postgresql || true
                    systemctl disable postgresql || true
                    break;;
                [Rr]* )
                    log "Removing PostgreSQL..."
                    systemctl stop postgresql || true
                    systemctl disable postgresql || true
                    apt-get remove --purge -y postgresql* || true
                    apt-get autoremove -y || true
                    rm -rf /var/lib/postgresql || true
                    rm -rf /var/log/postgresql || true
                    rm -rf /etc/postgresql || true
                    break;;
                [Kk]* )
                    log "Keeping PostgreSQL..."
                    break;;
                * )
                    log "Please answer S, R, or K.";;
            esac
        done
    else
        log "No existing PostgreSQL installation found."
    fi
}

# Function to verify Docker installation
verify_docker() {
    log "Verifying Docker installation..."
    
    # Test Docker installation
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        exit 1
    fi
    
    if ! docker run --rm hello-world &> /dev/null; then
        error "Docker installation verification failed"
        exit 1
    fi
    log "Docker installation verified successfully"
    
    # Test Docker Compose installation
    if ! command -v docker compose &> /dev/null; then
        error "Docker Compose is not installed"
        exit 1
    fi
    
    local compose_version
    if ! compose_version=$(docker compose version --short 2>/dev/null); then
        error "Failed to get Docker Compose version"
        exit 1
    fi
    
    if ! awk -v ver="$compose_version" 'BEGIN{if (ver < 2.0) exit 1; exit 0}'; then
        error "Docker Compose version must be 2.0 or higher. Found: $compose_version"
        exit 1
    fi
    
    log "Docker Compose installation verified successfully"
}

# Function to copy Docker Compose files
copy_docker_files() {
    log "Copying Docker Compose files..."
    
    local SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    local REQUIRED_FILES=(
        "docker-compose.yml"
        "Dockerfile"
        "requirements.txt"
        "requirements.custom.txt"
    )
    
    local CONFIG_FILES=(
        "postgresql.conf"
        "odoo.conf"
        "nginx.conf"
    )
    
    # Check if required files exist in script directory
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$file" ]; then
            error "Required file $file not found in script directory"
            exit 1
        fi
    done
    
    # Copy required files with error handling
    for file in "${REQUIRED_FILES[@]}"; do
        if ! sudo cp "$SCRIPT_DIR/$file" "/odoo/$file"; then
            error "Failed to copy $file to /odoo"
            exit 1
        fi
        # Set proper permissions
        if ! sudo chown root:$USER "/odoo/$file"; then
            error "Failed to set ownership for /odoo/$file"
            exit 1
        fi
        if ! sudo chmod 640 "/odoo/$file"; then
            error "Failed to set permissions for /odoo/$file"
            exit 1
        fi
    done
    
    # Handle configuration files
    log "Setting up configuration files..."
    
    # Create default configuration files if they don't exist
    if [ ! -f "$SCRIPT_DIR/odoo.conf" ]; then
        log "Creating default odoo.conf..."
        cat > "$SCRIPT_DIR/odoo.conf" << 'EOL'
[options]
addons_path = /mnt/extra-addons
data_dir = /var/lib/odoo
admin_passwd = ${ADMIN_PASSWORD}

# HTTP Service Configuration
http_port = 8069
http_interface = 0.0.0.0
proxy_mode = True
xmlrpc_port = 8069

# Database Configuration
db_host = db
db_port = 5432
db_user = ${POSTGRES_USER}
db_password = ${POSTGRES_PASSWORD}
db_name = ${POSTGRES_DB}

# Performance Tuning
workers = 4
max_cron_threads = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

# Logging Configuration
log_level = info
logfile = /var/log/odoo/odoo.log
logrotate = True

# Security
list_db = False
server_wide_modules = web,base
EOL
    fi
    
    if [ ! -f "$SCRIPT_DIR/nginx.conf" ]; then
        log "Creating default nginx.conf..."
        cat > "$SCRIPT_DIR/nginx.conf" << 'EOL'
upstream odoo {
    server odoo:8069;
}

upstream odoochat {
    server odoo:8072;
}

server {
    listen 80;
    server_name ${DOMAIN};

    # Redirect all HTTP requests to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        try_files $uri =404;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/${DOMAIN}/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Modern configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;

    # Proxy headers
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;

    # Log files
    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;

    # Cache static files
    location ~* /web/static/ {
        proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
        proxy_cache_valid 200 60m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo;
    }

    # Websocket support for Odoo chat
    location /websocket {
        proxy_pass http://odoochat;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Common locations
    location / {
        proxy_pass http://odoo;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_min_length 1000;
    gzip_proxied expired no-cache no-store private auth;
}
EOL
    fi
    
    # Copy configuration files to their respective locations
    for file in "${CONFIG_FILES[@]}"; do
        if [ -f "$SCRIPT_DIR/$file" ]; then
            case "$file" in
                "odoo.conf")
                    if ! sudo cp "$SCRIPT_DIR/$file" "/odoo/config/$file"; then
                        error "Failed to copy $file to config directory"
                        exit 1
                    fi
                    if ! sudo chown root:$USER "/odoo/config/$file"; then
                        error "Failed to set ownership for $file"
                        exit 1
                    fi
                    if ! sudo chmod 640 "/odoo/config/$file"; then
                        error "Failed to set permissions for $file"
                        exit 1
                    fi
                    ;;
                "nginx.conf")
                    if ! sudo cp "$SCRIPT_DIR/$file" "/odoo/nginx/conf/$file"; then
                        error "Failed to copy $file"
                        exit 1
                    fi
                    if ! sudo chown root:$USER "/odoo/nginx/conf/$file"; then
                        error "Failed to set ownership for $file"
                        exit 1
                    fi
                    if ! sudo chmod 640 "/odoo/nginx/conf/$file"; then
                        error "Failed to set permissions for $file"
                        exit 1
                    fi
                    ;;
                "postgresql.conf")
                    if ! sudo cp "$SCRIPT_DIR/$file" "/odoo/$file"; then
                        error "Failed to copy $file"
                        exit 1
                    fi
                    if ! sudo chown root:$USER "/odoo/$file"; then
                        error "Failed to set ownership for $file"
                        exit 1
                    fi
                    if ! sudo chmod 640 "/odoo/$file"; then
                        error "Failed to set permissions for $file"
                        exit 1
                    fi
                    ;;
            esac
        else
            warn "Optional configuration file $file not found, skipping..."
        fi
    done
    
    log "Docker Compose files copied successfully"
}

# Function to handle .env file
handle_env_file() {
    log "Setting up .env file..."
    local SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Check if .env exists in script directory
    if [ -f "$SCRIPT_DIR/.env" ]; then
        log "Found existing .env file in script directory"
        
        # Create backup of existing .env in /odoo if it exists
        if [ -f "/odoo/.env" ]; then
            warn "Existing .env file found in /odoo. Creating backup..."
            sudo cp "/odoo/.env" "/odoo/.env.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Copy .env file from script directory
        if ! sudo cp "$SCRIPT_DIR/.env" "/odoo/.env"; then
            error "Failed to copy .env file to /odoo"
            exit 1
        fi
        
        # Set proper permissions
        if ! sudo chown root:$USER "/odoo/.env"; then
            error "Failed to set ownership for .env file"
            exit 1
        fi
        if ! sudo chmod 640 "/odoo/.env"; then
            error "Failed to set permissions for .env file"
            exit 1
        fi
        
        log ".env file copied successfully"
    else
        warn "No .env file found in script directory, will create default"
        
        # Generate secure passwords
        local POSTGRES_PASSWORD=$(openssl rand -hex 32)
        local ADMIN_PASSWORD=$(openssl rand -hex 32)
        
        # Create default .env file
        if ! cat > "/tmp/odoo.env" << EOL
# PostgreSQL Configuration
POSTGRES_DB=postgres
POSTGRES_USER=odoo
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
PGDATA=/var/lib/postgresql/data/pgdata

# Odoo Configuration
ODOO_ADMIN_PASSWD=${ADMIN_PASSWORD}

# Domain Configuration
DOMAIN=your-domain.com
EMAIL=your-email@domain.com

# Application Paths
ODOO_EXTRA_ADDONS=/mnt/extra-addons
ODOO_DATA_DIR=/var/lib/odoo

# Resource Limits
ODOO_WORKERS=4
ODOO_MAX_CRON_THREADS=2
ODOO_LIMIT_MEMORY_HARD=2684354560
ODOO_LIMIT_MEMORY_SOFT=2147483648
ODOO_LIMIT_REQUEST=8192
ODOO_LIMIT_TIME_CPU=600
ODOO_LIMIT_TIME_REAL=1200

# Logging
ODOO_LOG_LEVEL=info
ODOO_LOGFILE=/var/log/odoo/odoo.log
EOL
        then
            error "Failed to create temporary .env file"
            exit 1
        fi
        
        # Move .env file to final location
        if ! sudo mv "/tmp/odoo.env" "/odoo/.env"; then
            error "Failed to move .env file to final location"
            exit 1
        fi
        
        # Set proper permissions
        if ! sudo chown root:$USER "/odoo/.env"; then
            error "Failed to set ownership for .env file"
            exit 1
        fi
        if ! sudo chmod 640 "/odoo/.env"; then
            error "Failed to set permissions for .env file"
            exit 1
        fi
        
        log "Default .env file created successfully"
        log "Please save these credentials:"
        echo "PostgreSQL Password: $POSTGRES_PASSWORD"
        echo "Admin Password: $ADMIN_PASSWORD"
    fi
}

# Main installation process
main() {
    log "=== Starting Odoo Production Installation ==="

    # Initial checks
    check_system_requirements
    
    # Handle existing services first
    log "1. Handling existing services..."
    handle_nginx
    check_postgresql
    
    # Now check ports after services are handled
    check_network_ports
    backup_existing_config

    # 2. Update system
    log "2. Updating system..."
    sudo apt-get update
    sudo apt-get upgrade -y

    # 3. Install required packages
    log "3. Installing required packages..."
    sudo apt-get install -y \
        apt-transport-https \
        nano \
        ca-certificates \
        curl \
        software-properties-common \
        git \
        python3-pip \
        certbot \
        python3-certbot-nginx \
        openssl \
        net-tools \
        ufw

    # 4. Install Docker
    log "4. Installing Docker..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi

    # 5. Install Docker Compose
    log "5. Installing Docker Compose..."
    if ! command -v docker-compose &> /dev/null; then
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi

    # Verify Docker installations
    verify_docker

    # 6. Create directory structure with secure permissions
    log "6. Creating directory structure..."
    if ! sudo mkdir -p /odoo/{config,addons,nginx/{conf,ssl,letsencrypt},logs,moxogo18,static}; then
        error "Failed to create directory structure"
        exit 1
    fi
    
    # Set secure permissions with error handling
    if ! sudo chown -R root:$USER /odoo; then
        error "Failed to set ownership on /odoo directory"
        exit 1
    fi
    
    if ! sudo chmod -R 750 /odoo; then
        error "Failed to set permissions on /odoo directory"
        exit 1
    fi
    
    if ! sudo chmod 770 /odoo/{logs,nginx/ssl,nginx/letsencrypt}; then
        error "Failed to set permissions on sensitive directories"
        exit 1
    fi

    # 7. Copy Docker Compose files
    copy_docker_files
    
    # 8. Handle .env file
    handle_env_file

    # 9. Configure firewall
    # log "9. Configuring firewall..."
    # sudo ufw allow 22/tcp
    # sudo ufw allow 80/tcp
    # sudo ufw allow 443/tcp
    # sudo ufw allow 8069/tcp
    # sudo ufw allow 8072/tcp
    # echo "y" | sudo ufw enable

    # Final setup
    log "=== Installation Complete ==="
    log "Next steps:"
    echo "1. Update the .env file with your domain and email"
    echo "2. Get SSL certificate:"
    echo "   sudo certbot certonly --webroot -w /odoo/nginx/letsencrypt -d your-domain.com"
    echo "3. Start the services:"
    echo "   cd /odoo && docker compose up -d"
    echo "4. Check the logs:"
    echo "   docker compose logs -f"
    echo ""
    warn "=== Remember to save these passwords securely! ==="
}

# Execute main function
main