#!/bin/bash
set -e

domains=(hub.mxgsoft.com moxogo.com)
rsa_key_size=4096
data_path="./certbot"
email="wizearch55@gmail.com"

echo "### Starting SSL certificate initialization"

# (1) Stop all containers and cleanup
echo "### Cleaning up existing setup..."
docker-compose down
rm -rf "$data_path/conf/*"
rm -rf "$data_path/www/*"

# (2) Create directories
echo "### Creating directories..."
mkdir -p "$data_path/conf"
mkdir -p "$data_path/www"
chmod -R 755 "$data_path"

# (3) Start nginx
echo "### Starting nginx..."
docker-compose up -d nginx

# (4) Verify nginx is running
echo "### Verifying nginx status..."
sleep 5
if ! curl -s -o /dev/null http://localhost/.well-known/acme-challenge/; then
    echo "ERROR: Nginx is not responding on port 80"
    docker-compose logs nginx
    exit 1
fi

# (5) Get certificates (with staging first)
echo "### Testing with Let's Encrypt staging..."
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot \
    --email $email \
    --agree-tos \
    --no-eff-email \
    --staging \
    -v \
    $(for d in "${domains[@]}"; do echo "-d $d"; done)

# (6) If staging successful, get real certificates
echo "### Requesting real certificates..."
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot \
    --email $email \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -v \
    $(for d in "${domains[@]}"; do echo "-d $d"; done)

# (7) Verify certificates
echo "### Verifying certificates..."
if [ ! -d "$data_path/conf/live/${domains[0]}" ]; then
    echo "ERROR: Certificates not generated!"
    echo "### Debug information:"
    ls -la "$data_path/conf/"
    docker-compose logs certbot
    exit 1
fi

# (8) Enable SSL in nginx
echo "### Enabling SSL in nginx configuration..."
sed -i 's/#.*listen 443 ssl/    listen 443 ssl/' ./config/nginx.conf

# (9) Restart everything
echo "### Restarting all services..."
docker-compose down
docker-compose up -d

echo "### Done! Testing final setup..."
sleep 5
curl -Ik https://${domains[0]}

echo "### Displaying final logs..."
docker-compose logs nginx
docker-compose logs certbot
