#!/bin/sh
set -e

# Function to check SSL certificates
check_ssl() {
    if [ -f "/etc/letsencrypt/live/hub.mxgsoft.com/fullchain.pem" ]; then
        echo "SSL certificates found"
        return 0
    else
        echo "No SSL certificates found"
        return 1
    fi
}

# Backup original config if not already backed up
if [ ! -f /etc/nginx/conf.d/default.conf.original ]; then
    cp /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.original
fi

# Initial setup - always start with HTTP config
cp /etc/nginx/conf.d/default.conf.original /etc/nginx/conf.d/default.conf

# Start nginx in background for certificate renewal
nginx -g 'daemon off;' &
NGINX_PID=$!

# Wait for changes
while true; do
    # Check for SSL certificates
    if check_ssl; then
        # Enable SSL in config
        sed -i 's/#.*listen 443 ssl/    listen 443 ssl/' /etc/nginx/conf.d/default.conf
        nginx -s reload
    fi
    sleep 6h & wait $!
done

# Keep nginx running
wait $NGINX_PID
