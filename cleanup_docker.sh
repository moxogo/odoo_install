#!/bin/bash

# Stop all running containers
docker stop $(docker ps -aq)

# Remove all containers
docker rm $(docker ps -aq)

# Remove all Docker networks
docker network prune -f

# Kill any remaining docker-proxy processes (if needed)
sudo pkill docker-proxy

# Check if ports are now free
netstat -tulpn | grep -E '80|443|5432|8069|8072'

# If you still see docker-proxy processes, restart the Docker daemon
sudo systemctl restart docker

# Verify all ports are free before starting services again
netstat -tulpn | grep -E '80|443|5432|8069|8072'

# Start your services again
docker-compose up -d