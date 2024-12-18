#!/bin/bash

# Wait for PostgreSQL to start
until pg_isready; do
    echo "Waiting for PostgreSQL to start..."
    sleep 1
done

# Create pg_hba.conf with proper permissions
cat > "$PGDATA/pg_hba.conf" << EOL
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     trust

# IPv4 local connections:
host    all             all             127.0.0.1/32           trust
host    all             all             172.16.0.0/12          md5
host    all             all             192.168.0.0/16         md5
host    all             all             10.0.0.0/8             md5

# Allow Docker internal network
host    all             all             172.0.0.0/8            md5

# IPv6 local connections:
host    all             all             ::1/128                trust
EOL

# Set proper permissions
chmod 600 "$PGDATA/pg_hba.conf"

# Reload PostgreSQL configuration
pg_ctl reload
