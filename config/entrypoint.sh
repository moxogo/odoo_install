#!/bin/bash
# Entry point script for Odoo Docker container

# Replace environment variables in odoo.conf
envsubst < /etc/odoo/odoo.conf > /etc/odoo/odoo.conf.tmp
mv /etc/odoo/odoo.conf.tmp /etc/odoo/odoo.conf

# Start Odoo with a default command if none is provided
cd /odoo-server
if [ -z "$1" ]; then
    exec python3 -m odoo --config=/etc/odoo/odoo.conf
else
    exec python3 -m odoo "$@"
fi