#!/bin/bash

# Load environment variables
set -a
source .env
set +a

if [ -z "$NGINX_DOMAIN" ] || [ -z "$CERTBOT_EMAIL" ]; then
    echo "Error: NGINX_DOMAIN or CERTBOT_EMAIL not set in .env file"
    exit 1
fi

rsa_key_size=4096
data_path="./certbot"

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
    echo "### Downloading recommended TLS parameters ..."
    mkdir -p "$data_path/conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
    echo
fi

echo "### Creating dummy certificate for $NGINX_DOMAIN ..."
path="/etc/letsencrypt/live/$NGINX_DOMAIN"
mkdir -p "$data_path/conf/live/$NGINX_DOMAIN"
docker-compose run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
        -keyout '$path/privkey.pem' \
        -out '$path/fullchain.pem' \
        -subj '/CN=localhost'" certbot
echo

echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $NGINX_DOMAIN ..."
docker-compose run --rm --entrypoint "\
    rm -Rf /etc/letsencrypt/live/$NGINX_DOMAIN && \
    rm -Rf /etc/letsencrypt/archive/$NGINX_DOMAIN && \
    rm -Rf /etc/letsencrypt/renewal/$NGINX_DOMAIN.conf" certbot
echo

echo "### Requesting Let's Encrypt certificate for $NGINX_DOMAIN ..."
domain_args="-d $NGINX_DOMAIN"
email_arg="--email $CERTBOT_EMAIL"
staging_arg=""

# Enable staging mode if needed
if [ $STAGING != "0" ]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
        $staging_arg \
        $email_arg \
        $domain_args \
        --rsa-key-size $rsa_key_size \
        --agree-tos \
        --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload
