#!/bin/bash

# User configurable variables
# NGINX_DOMAIN=${NGINX_DOMAIN:-"localhost"}
# CERTBOT_EMAIL=${CERTBOT_EMAIL:-"admin@localhost"}
# ODOO_PORT=${ODOO_PORT:-8069}
# ODOO_LONGPOLLING_PORT=${ODOO_LONGPOLLING_PORT:-8072}
# POSTGRES_PORT=${POSTGRES_PORT:-5432}

NGINX_DOMAIN=demo.moxogo.com
CERTBOT_EMAIL=wizearch55@gmail.com
ODOO_PORT=8080
ODOO_LONGPOLLING_PORT=8072
POSTGRES_PORT=5432
POSTGRES_USER=odoo
POSTGRES_PASSWORD=odoo
POSTGRES_HOST=db

# Generate random admin password if not set
ODOO_ADMIN_PASSWD=$(openssl rand -base64 12)
# Set a fixed admin password for testing
# ODOO_ADMIN_PASSWD="admin123"

# Save the password to a file for reference
echo "Odoo Admin Password: ${ODOO_ADMIN_PASSWD}" > "/odoo/odoo_admin_password.txt"
chmod 600 "/odoo/odoo_admin_password.txt"

# Installation directory
INSTALL_DIR="/odoo"

# Required directories
REQUIRED_DIRS=(
    "${INSTALL_DIR}/config"
    "${INSTALL_DIR}/logs"
    "${INSTALL_DIR}/addons"
    "${INSTALL_DIR}/backups"
    "${INSTALL_DIR}/nginx/conf"
    "${INSTALL_DIR}/nginx/ssl"
    "${INSTALL_DIR}/nginx/letsencrypt"
    "${INSTALL_DIR}/moxogo18"
)

# Required files to copy
REQUIRED_FILES=(
    "docker-compose.yml"
    "Dockerfile"
    "requirements.txt"
    "requirements.custom.txt"
)

# Configuration files
CONFIG_FILES=(
    "odoo.conf"
    "postgresql.conf"
    "pg_hba.conf"
    "init-postgres.sh"
    "nginx.conf"
)

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
    
    # Check disk space
    FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$FREE_SPACE" -lt 20 ]; then
        error "Minimum 20GB free space required, found: ${FREE_SPACE}GB"
        exit 1
    fi
    log "Disk space check passed: ${FREE_SPACE}GB available"
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
    
    log "Docker installation verified successfully"
}

# Function to verify SSL certificates
verify_ssl_certificates() {
    log "Verifying SSL certificate paths..."
    local ssl_dir="/odoo/nginx/ssl/live/${NGINX_DOMAIN}"
    
    if [ ! -f "${ssl_dir}/fullchain.pem" ] || [ ! -f "${ssl_dir}/privkey.pem" ]; then
        warn "SSL certificates not found at ${ssl_dir}"
        warn "You will need to obtain SSL certificates using certbot"
        warn "Run: certbot certonly --webroot -w /odoo/nginx/letsencrypt -d ${NGINX_DOMAIN}"
    else
        log "SSL certificates found"
    fi
}

# Function to verify container configurations
verify_container_configs() {
    log "Verifying container configurations..."
    
    # Check restart policies
    if ! grep -q "restart: unless-stopped" docker-compose.yml; then
        error "Container restart policy not properly configured"
        exit 1
    fi
    
    # Validate mount points
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            error "Required mount point $dir does not exist"
            exit 1
        fi
    done
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

# Function to copy Docker Compose files
copy_docker_files() {
    log "Copying Docker Compose files..."
    
    local SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Create necessary directories
    for dir in "${REQUIRED_DIRS[@]}"; do
        mkdir -p "$dir"
    done
    
    # Copy configuration files
    for file in "${REQUIRED_FILES[@]}"; do
        cp -f "$file" "${INSTALL_DIR}/"
    done
    
    # Clean up any existing config files that might be directories
    for file in "${CONFIG_FILES[@]}"; do
        target="${INSTALL_DIR}/config/$file"
        if [ -d "$target" ]; then
            rm -rf "$target"
        fi
    done
    
    # Copy config files
    for file in "${CONFIG_FILES[@]}"; do
        cp -f "config/$file" "${INSTALL_DIR}/config/"
    done
    
    # Ensure entrypoint.sh is copied
    cp -f "config/entrypoint.sh" "${INSTALL_DIR}/config/entrypoint.sh"
    
    # Set proper permissions
    chmod 644 "${INSTALL_DIR}/config/postgresql.conf" "${INSTALL_DIR}/config/pg_hba.conf" "${INSTALL_DIR}/config/odoo.conf"
    chmod +x "${INSTALL_DIR}/config/init-postgres.sh"
    
    # Create .env file if it doesn't exist
    if [ ! -f "${INSTALL_DIR}/.env" ]; then
        cat > "${INSTALL_DIR}/.env" << EOL
NGINX_DOMAIN=${NGINX_DOMAIN}
CERTBOT_EMAIL=${CERTBOT_EMAIL}
ODOO_PORT=${ODOO_PORT}
ODOO_LONGPOLLING_PORT=${ODOO_LONGPOLLING_PORT}
POSTGRES_PORT=${POSTGRES_PORT}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_HOST=${POSTGRES_HOST}
POSTGRES_DB=postgres
POSTGRES_IMAGE=postgres:16
ODOO_IMAGE=odoo:18
REDIS_IMAGE=redis:7-alpine
NGINX_IMAGE=nginx:alpine
ODOO_PROXY_MODE=true
REDIS_HOST=redis
REDIS_PASSWORD=odoo
ODOO_ADMIN_PASSWD=${ODOO_ADMIN_PASSWD}
EOL
        echo -e "\n\033[1;32m=== IMPORTANT: Odoo Admin Password ===\033[0m"
        echo -e "\033[1;33mPassword: ${ODOO_ADMIN_PASSWD}\033[0m"
        echo -e "This password has been saved to: ${INSTALL_DIR}/odoo_admin_password.txt"
        echo -e "Please save this password securely!\n"
    fi
    
    log "Docker Compose files copied successfully"
}

# Function to generate or retrieve stored passwords
handle_passwords() {
    local password_file="$INSTALL_DIR/.passwords"
    
    # Initialize passwords
    POSTGRES_PASSWORD=""
    ODOO_ADMIN_PASSWORD=""
    REDIS_PASSWORD=""
    
    # If password file exists, load the passwords
    if [ -f "$password_file" ]; then
        log "Loading existing passwords..."
        source "$password_file"
        
        # Check if Redis password exists in old file, if not generate it
        if [ -z "$REDIS_PASSWORD" ]; then
            log "Generating new Redis password..."
            REDIS_PASSWORD=$(openssl rand -base64 32)
            {
                echo "POSTGRES_PASSWORD='$POSTGRES_PASSWORD'"
                echo "ODOO_ADMIN_PASSWORD='$ODOO_ADMIN_PASSWORD'"
                echo "REDIS_PASSWORD='$REDIS_PASSWORD'"
            } > "$password_file"
            chmod 600 "$password_file"
        fi
    else
        log "Generating new passwords..."
        # Generate new passwords
        POSTGRES_PASSWORD=$(openssl rand -base64 32)
        ODOO_ADMIN_PASSWORD=$(openssl rand -base64 32)
        REDIS_PASSWORD=$(openssl rand -base64 32)
        
        # Store passwords in file
        {
            echo "POSTGRES_PASSWORD='$POSTGRES_PASSWORD'"
            echo "ODOO_ADMIN_PASSWORD='$ODOO_ADMIN_PASSWORD'"
            echo "REDIS_PASSWORD='$REDIS_PASSWORD'"
        } > "$password_file"
        
        # Secure the password file
        chmod 600 "$password_file"
    fi
    
    # Verify all passwords are set
    if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$ODOO_ADMIN_PASSWORD" ] || [ -z "$REDIS_PASSWORD" ]; then
        error "One or more passwords are not set properly"
        exit 1
    fi
}

# Function to create or update .env file
create_env_file() {
    local env_file="$INSTALL_DIR/.env"
    local backup_suffix=$(date +%Y%m%d_%H%M%S)
    
    # Load or generate passwords
    handle_passwords
    
    # Backup existing .env if it exists
    if [ -f "$env_file" ]; then
        cp "$env_file" "${env_file}.backup.${backup_suffix}"
        log "Backed up existing .env file to ${env_file}.backup.${backup_suffix}"
    fi
    
    # Create new .env file
    cat > "$env_file" <<EOF
# PostgreSQL Configuration
POSTGRES_IMAGE=postgres:16
POSTGRES_DB=postgres
POSTGRES_USER=odoo
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST=db
POSTGRES_PORT=$POSTGRES_PORT

# Odoo Configuration
ODOO_ADMIN_PASSWD=$ODOO_ADMIN_PASSWORD
ODOO_DB_HOST=db
ODOO_DB_PORT=$POSTGRES_PORT
ODOO_DB_USER=odoo
ODOO_DB_PASSWORD=$POSTGRES_PASSWORD
ODOO_PROXY_MODE=True

# Container Configuration
ODOO_IMAGE=odoo:18
NGINX_IMAGE=nginx:alpine
CERTBOT_IMAGE=certbot/certbot

# Ports (used only in development)
ODOO_PORT=$ODOO_PORT
ODOO_LONGPOLLING_PORT=$ODOO_LONGPOLLING_PORT
POSTGRES_PORT_FORWARD=$POSTGRES_PORT

# Volumes
ODOO_ADDONS_PATH=/mnt/extra-addons,/mnt/extra-addons/moxogo18
ODOO_DATA_DIR=/var/lib/odoo
POSTGRES_DATA_DIR=/var/lib/postgresql/data

# Nginx & SSL Configuration
NGINX_PORT=80
NGINX_SSL_PORT=443
NGINX_DOMAIN=$NGINX_DOMAIN
CERTBOT_EMAIL=$CERTBOT_EMAIL

# Redis Configuration
REDIS_IMAGE=redis:7.0
REDIS_HOST=redis
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_PORT=6379
EOF

    # Secure the .env file
    chmod 640 "$env_file"
    log "Created new .env file with secure permissions"
    
    # Display important information
    log "Important: Your passwords are stored in $INSTALL_DIR/.passwords"
    log "Make sure to keep this file secure and backed up"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to copy shell scripts to production
copy_shell_scripts() {
    echo "Copying shell scripts to production..."
    
    # Create scripts directory if it doesn't exist
    mkdir -p "$INSTALL_DIR/scripts"
    
    # List of scripts to copy
    local scripts=(
        "init-letsencrypt.sh"
        "security_audit.sh"
        "post_deploy.sh"
        "monitor.sh"
        "harden_ubuntu.sh"
        "deploy.sh"
        "cleanup_docker.sh"
        "cleanup.sh"
        "backup.sh"
    )
    
    # Copy each script and make it executable
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            cp "$script" "$INSTALL_DIR/scripts/"
            chmod +x "$INSTALL_DIR/scripts/$script"
            echo "Copied and made executable: $script"
        else
            echo "Warning: Script not found: $script"
        fi
    done
    
    # Copy config scripts if they exist
    if [ -d "config" ]; then
        mkdir -p "$INSTALL_DIR/config"
        cp config/*.sh "$INSTALL_DIR/config/" 2>/dev/null || true
        chmod +x "$INSTALL_DIR/config/"*.sh 2>/dev/null || true
        echo "Copied config scripts"
    fi
}

# Check if Docker is installed
if ! command_exists docker; then
  echo "Docker is not installed. Installing Docker..."
  # Install Docker
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm get-docker.sh
  sudo usermod -aG docker $USER
  echo "Docker installed successfully."
else
  echo "Docker is already installed."
fi

# Check if Docker Compose is installed
if ! command_exists docker-compose; then
  echo "Docker Compose is not installed. Installing Docker Compose..."
  # Install Docker Compose
  sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  echo "Docker Compose installed successfully."
else
  echo "Docker Compose is already installed."
fi

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

echo "Docker and Docker Compose are ready."

# Main installation process
main() {
    log "=== Starting Odoo Production Installation ==="

    # Show configuration
    log "Installation Configuration:"
    log "  Domain: $NGINX_DOMAIN"
    log "  Email: $CERTBOT_EMAIL"
    log "  Odoo Port: $ODOO_PORT"
    log "  Longpolling Port: $ODOO_LONGPOLLING_PORT"
    log "  PostgreSQL Port: $POSTGRES_PORT"
    echo ""
    read -p "Press Enter to continue with these settings, or Ctrl+C to abort..."

    # Initial checks
    check_system_requirements
    verify_docker
    
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
    for dir in "${REQUIRED_DIRS[@]}"; do
        if ! sudo mkdir -p "$dir"; then
            error "Failed to create directory structure"
            exit 1
        fi
    done
    
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
    create_env_file
    
    # 9. Create SSL directories
    log "Creating SSL directories for domain: ${NGINX_DOMAIN}"
    sudo mkdir -p "/odoo/nginx/ssl/live/${NGINX_DOMAIN}"
    sudo chmod -R 750 "/odoo/nginx/ssl"
    sudo mkdir -p "/odoo/nginx/letsencrypt"
    sudo chmod 755 "/odoo/nginx/letsencrypt"
    
    # 10. Verify container configurations
    verify_container_configs
    
    # 11. Verify SSL certificates
    verify_ssl_certificates

    # 11. Configure firewall
    # log "11. Configuring firewall..."
    # sudo ufw allow 22/tcp
    # sudo ufw allow 80/tcp
    # sudo ufw allow 443/tcp
    # sudo ufw allow 8069/tcp
    # sudo ufw allow 8072/tcp
    # echo "y" | sudo ufw enable

    # 12. Copy shell scripts to production
    copy_shell_scripts

    # Final setup
    log "=== Installation Complete ==="
    log "Next steps:"
    echo "1. Update the .env file with your domain and email"
    echo "2. Get SSL certificate:"
    echo "   sudo certbot certonly --webroot -w /odoo/nginx/letsencrypt -d your-domain.com"
    echo "3. Start the services:"
    echo "   cd /odoo && docker compose up -d"
    echo "docker compose -f /odoo/docker-compose.yml up -d"
    echo "4. Check the logs:"
    echo "   docker compose logs -f"
    echo ""
    warn "=== Remember to save these passwords securely! ==="
}
    log "Postgres Password (save this): ${POSTGRES_PASSWORD}"
    log "Admin Password (save this): ${ODOO_ADMIN_PASSWD}"

# Execute main function
main