#!/bin/bash

# Load environment variables
set -a
source .env
set +a

echo "Stopping all containers..."
docker-compose down

echo "Removing old containers..."
docker rm -f odoo18 odoo18_db odoo18_nginx odoo18_certbot 2>/dev/null || true

echo "Cleaning up networks..."
docker network rm odoo18_network 2>/dev/null || true

# Don't remove volumes by default to preserve data
if [ "$1" == "--remove-volumes" ]; then
    echo "Removing volumes..."
    docker volume rm odoo18_web_data odoo18_db_data 2>/dev/null || true
    
    echo "Cleaning up SSL certificates..."
    rm -rf ./certbot/conf/* ./certbot/www/* 2>/dev/null || true
fi

echo "Cleanup complete!"
