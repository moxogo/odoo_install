#!/bin/bash
# Entry point script for Odoo Docker container

# Display the admin password for first-time setup
if [ -n "${ODOO_ADMIN_PASSWD}" ]; then
    echo -e "\n\033[1;32m=== Odoo Admin Password ===\033[0m"
    echo -e "\033[1;33mPassword: ${ODOO_ADMIN_PASSWD}\033[0m"
    echo -e "Use this password for initial database creation and admin login\n"
fi

# Replace environment variables in odoo.conf
envsubst < /etc/odoo/odoo.conf > /etc/odoo/odoo.conf.tmp
mv /etc/odoo/odoo.conf.tmp /etc/odoo/odoo.conf

# Start Odoo
exec odoo "$@"

exec "$@"
