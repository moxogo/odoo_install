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
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            error "Port $port is already in use"
            echo "Please free up port $port before continuing"
            exit 1
        fi
    done
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
    
    # Check if port 80 is in use
    if sudo lsof -i :80 >/dev/null 2>&1; then
        warn "Port 80 is currently in use"
        
        # Stop and disable system Nginx
        if systemctl is-active --quiet nginx; then
            log "Stopping system Nginx..."
            sudo systemctl stop nginx
            log "Disabling system Nginx..."
            sudo systemctl disable nginx
        fi

        # Remove Nginx packages
        if dpkg -l | grep -q "^ii.*nginx"; then
            log "Removing system Nginx packages..."
            sudo apt-get remove nginx nginx-common -y
            sudo apt-get autoremove -y
        fi

        # Clean up Nginx directories
        if [ -d "/etc/nginx" ] || [ -d "/var/log/nginx" ]; then
            log "Cleaning up Nginx directories..."
            sudo rm -rf /etc/nginx
            sudo rm -rf /var/log/nginx
        fi
    fi

    log "Port 80 is now available for use"
}

# Function to handle PostgreSQL
handle_postgres() {
    log "Checking for existing PostgreSQL installation..."
    
    # Check all potential PostgreSQL processes
    if pgrep -x "postgres" > /dev/null || systemctl is-active --quiet postgresql; then
        warn "PostgreSQL is running on the system"
        warn "This might conflict with Docker PostgreSQL"
        
        while true; do
            read -p "Do you want to (S)top, (R)emove, or (K)eep the system PostgreSQL? [S/R/K] " -n 1 -r
            echo
            case $REPLY in
                [Ss]* )
                    log "Stopping PostgreSQL..."
                    sudo systemctl stop postgresql
                    sudo systemctl disable postgresql
                    break;;
                [Rr]* )
                    log "Removing PostgreSQL..."
                    sudo systemctl stop postgresql
                    sudo systemctl disable postgresql
                    sudo apt-get remove --purge postgresql* -y
                    sudo rm -rf /var/lib/postgresql/
                    break;;
                [Kk]* )
                    warn "Keeping system PostgreSQL. Docker PostgreSQL will use alternate port."
                    break;;
                * ) echo "Please answer S, R, or K.";;
            esac
        done
    fi
}

# Function to verify Docker installation
verify_docker() {
    log "Verifying Docker installation..."
    
    # Test Docker installation
    if ! docker run hello-world > /dev/null 2>&1; then
        error "Docker installation verification failed"
        exit 1
    fi
    log "Docker installation verified successfully"
    
    # Test Docker Compose installation
    if ! docker compose version > /dev/null 2>&1; then
        error "Docker Compose installation verification failed"
        exit 1
    }
    log "Docker Compose installation verified successfully"
}

# Main installation process
main() {
    log "=== Starting Odoo Production Installation ==="

    # Initial checks
    check_system_requirements
    check_network_ports
    backup_existing_config

    # 1. Handle existing services
    log "1. Handling existing services..."
    handle_nginx
    handle_postgres

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
    umask 027
    sudo mkdir -p /odoo/{config,addons,nginx/{conf,ssl,letsencrypt},logs,moxogo18,static}
    sudo chown -R root:$USER /odoo
    sudo chmod -R 750 /odoo
    sudo chmod 770 /odoo/{logs,nginx/ssl,nginx/letsencrypt}

    # 7. Generate secure passwords
    log "7. Generating secure passwords..."
    POSTGRES_PASSWORD=$(openssl rand -hex 32)
    ADMIN_PASSWORD=$(openssl rand -hex 32)

    # 8. Create .env file
    log "8. Creating .env file..."
    cat > /odoo/.env << EOL
POSTGRES_DB=postgres
POSTGRES_USER=odoo
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
ODOO_ADMIN_PASSWD=${ADMIN_PASSWORD}
DOMAIN=your-domain.com
EMAIL=your-email@domain.com
PGDATA=/var/lib/postgresql/data/pgdata
EOL

    # Set secure permissions for .env
    sudo chown root:$USER /odoo/.env
    sudo chmod 640 /odoo/.env

    # 9. Configure firewall
    log "9. Configuring firewall..."
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 8069/tcp
    sudo ufw allow 8072/tcp
    echo "y" | sudo ufw enable

    # Final setup
    log "=== Installation Complete ==="
    log "Please save these credentials:"
    echo "PostgreSQL Password: $POSTGRES_PASSWORD"
    echo "Admin Password: $ADMIN_PASSWORD"
    echo ""
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