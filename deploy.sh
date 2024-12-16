#!/bin/bash

# Load environment variables
set -a
source .env
set +a

# Function to print status messages
print_status() {
    echo "==> $1"
}

# Function to check requirements files
check_requirements() {
    if [ ! -f "requirements.txt" ] || [ ! -f "requirements.custom.txt" ]; then
        print_status "Error: requirements.txt or requirements.custom.txt is missing"
        exit 1
    fi
}

# Function to create directories
create_directories() {
    print_status "Creating required directories..."
    mkdir -p \
        ./config \
        ./addons \
        ./logs/nginx \
        ./logs/odoo \
        ./nginx/conf.d \
        ./certbot/conf \
        ./certbot/www
}

# Function to set permissions
set_permissions() {
    print_status "Setting proper permissions..."
    chmod 600 .env
    chmod 644 postgresql.conf config/odoo.conf
    chmod 644 requirements.txt requirements.custom.txt
    chmod 755 init-letsencrypt.sh cleanup.sh
}

# Function to validate configuration
validate_config() {
    print_status "Validating configuration..."
    if [ "$NGINX_DOMAIN" == "your-domain.com" ] || [ "$CERTBOT_EMAIL" == "your-email@example.com" ]; then
        print_status "Error: Please update NGINX_DOMAIN and CERTBOT_EMAIL in .env file"
        exit 1
    fi
}

# Function to initialize SSL
init_ssl() {
    if [ ! -d "./certbot/conf/live/$NGINX_DOMAIN" ]; then
        print_status "Initializing SSL certificates..."
        ./init-letsencrypt.sh
    fi
}

# Function to build and start services
start_services() {
    print_status "Building and starting services..."
    docker-compose build --pull
    docker-compose up -d
}

# Function to check service health
check_health() {
    print_status "Checking service health..."
    sleep 10
    docker-compose ps
    docker-compose logs --tail=20
}

# Main deployment process
print_status "Starting deployment process..."

# Check requirements files
check_requirements

# Create directories
create_directories

# Set permissions
set_permissions

# Validate configuration
validate_config

# Initialize SSL certificates
init_ssl

# Start services
start_services

# Check health
check_health

print_status "Deployment complete! Check the logs above for any errors."
print_status "Your Odoo server is now available at:"
echo "http://$(wget -qO- ipv4.icanhazip.com):${ODOO_PORT}"
echo "https://${NGINX_DOMAIN} (if SSL is configured)"