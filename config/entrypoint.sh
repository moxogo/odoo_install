#!/bin/bash
# Entry point script for Odoo Docker container

# Replace environment variables in odoo.conf
envsubst < /etc/odoo/odoo.conf > /etc/odoo/odoo.conf.tmp
mv /etc/odoo/odoo.conf.tmp /etc/odoo/odoo.conf

# Navigate to the directory containing the Odoo package
cd /usr/lib/python3/dist-packages

# Start Odoo as a module
exec python3 -m odoo.cli.command "$@"