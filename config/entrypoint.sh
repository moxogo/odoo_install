#!/bin/bash
# Entry point script for Odoo Docker container

# Replace environment variables in odoo.conf
envsubst < /etc/odoo/odoo.conf > /etc/odoo/odoo.conf.tmp
mv /etc/odoo/odoo.conf.tmp /etc/odoo/odoo.conf

# Start Odoo
cd /usr/lib/python3/dist-packages
exec python3 /usr/lib/python3/dist-packages/odoo/odoo-bin -c /etc/odoo/odoo.conf