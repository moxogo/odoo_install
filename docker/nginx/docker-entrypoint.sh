#!/bin/sh
set -e

# Check if SSL certificates exist
if [ -f "/etc/letsencrypt/live/hub.mxgsoft.com/fullchain.pem" ]; then
    echo "SSL certificates found, enabling HTTPS configuration"
    mv /etc/nginx/conf.d/default.conf.nossl /etc/nginx/conf.d/default.conf
else
    echo "No SSL certificates found, using HTTP only configuration"
    cp /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.nossl
fi

# Execute nginx
exec nginx -g 'daemon off;'
