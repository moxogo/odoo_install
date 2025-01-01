#!/bin/bash
set -e

# Configure domains
primary_domain="hub.mxgsoft.com"
secondary_domain="moxogo.com"
data_path="./certbot"
email="wizearch55@gmail.com"

echo "### Starting SSL certificate initialization"

# Clean and prepare
echo "### Cleaning up existing setup..."
docker-compose down
rm -rf "$data_path/conf"
rm -rf "$data_path/www"
mkdir -p "$data_path/conf"
mkdir -p "$data_path/www"
chmod -R 755 "$data_path"

# Start nginx with HTTP only
echo "### Starting nginx..."
docker-compose up -d nginx
sleep 5

# Get certificate for primary domain first
echo "### Requesting certificate for $primary_domain..."
docker-compose run --rm --entrypoint "\
    certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email $email \
    --agree-tos \
    --no-eff-email \
    --force-renewal" \
    certbot \
    -d $primary_domain

# Verify primary certificate
if [ ! -d "$data_path/conf/live/$primary_domain" ]; then
    echo "### Primary certificate generation failed!"
    docker-compose logs certbot
    exit 1
fi

# Get certificate for secondary domain
echo "### Requesting certificate for $secondary_domain..."
docker-compose run --rm --entrypoint "\
    certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email $email \
    --agree-tos \
    --no-eff-email \
    --force-renewal" \
    certbot \
    -d $secondary_domain

# Enable SSL in nginx config
sed -i 's/#.*listen 443 ssl/    listen 443 ssl/' ./config/nginx.conf

# Restart everything
echo "### Restarting all services..."
docker-compose down
docker-compose up -d

echo "### Testing final setup..."
sleep 5
curl -Ik https://$primary_domain
curl -Ik https://$secondary_domain
