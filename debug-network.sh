#!/bin/bash

echo "=== Checking container status ==="
docker-compose ps

echo -e "\n=== Checking nginx logs ==="
docker-compose logs nginx

echo -e "\n=== Checking nginx configuration ==="
docker-compose exec nginx nginx -t

echo -e "\n=== Checking port bindings ==="
netstat -tulpn | grep -E ':80|:443'

echo -e "\n=== Testing nginx container network ==="
docker-compose exec nginx curl -v http://localhost/.well-known/acme-challenge/

echo -e "\n=== Checking nginx process inside container ==="
docker-compose exec nginx ps aux | grep nginx

echo -e "\n=== Checking container network settings ==="
docker-compose exec nginx ip addr show
