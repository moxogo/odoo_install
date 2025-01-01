#!/bin/bash

echo "Stopping containers..."
docker-compose down

echo "Removing SSL certificates and certbot data..."
rm -rf ./certbot/conf/*
rm -rf ./certbot/www/*

echo "Restoring nginx configuration to HTTP-only..."
# Comment out SSL server block in nginx.conf
sed -i 's/^[^#].*listen 443 ssl/#    listen 443 ssl/' ./config/nginx.conf
sed -i 's/^[^#].*http2 on/#    http2 on/' ./config/nginx.conf

echo "Recreating certbot directories..."
mkdir -p ./certbot/conf
mkdir -p ./certbot/www
chmod -R 755 ./certbot

echo "Restarting containers..."
docker-compose up -d

echo "SSL cleanup complete. The site should now be running in HTTP-only mode."
