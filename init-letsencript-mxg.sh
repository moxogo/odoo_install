#!/bin/bash

# Create required directories
mkdir -p ./certbot/conf/live/hub.mxgsoft.com
mkdir -p ./certbot/conf/live/moxogo.com
mkdir -p ./certbot/www
chmod -R 755 ./certbot

# Stop existing containers
docker-compose down

# Start nginx
docker-compose up -d nginx

# Get SSL certificate
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --force-renewal \
    --email wizearch55@gmail.com \
    --agree-tos \
    --no-eff-email \
    -d hub.mxgsoft.com -d moxogo.com

# Restart containers
docker-compose down
docker-compose up -d
