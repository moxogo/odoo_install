#!/bin/bash

# Load environment variables
source .env

# Create required directories
mkdir -p ./certbot/conf/live/${NGINX_DOMAIN}
mkdir -p ./certbot/www

# Stop existing containers
docker-compose down

# Start nginx
docker-compose up -d nginx

# Get SSL certificate
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --force-renewal \
    --email ${ADMIN_EMAIL} \
    --agree-tos \
    --no-eff-email \
    -d ${NGINX_DOMAIN}

# Restart containers
docker-compose down
docker-compose up -d
