#!/bin/bash
# Entry point script for Odoo Docker container

# Replace environment variables in odoo.conf
envsubst < /etc/odoo/odoo.conf > /etc/odoo/odoo.conf.tmp
mv /etc/odoo/odoo.conf.tmp /etc/odoo/odoo.conf

# Start Odoo
exec python3 /usr/bin/odoo -c /etc/odoo/odoo.conf