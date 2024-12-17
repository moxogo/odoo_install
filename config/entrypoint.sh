#!/bin/bash

# Replace environment variables in odoo.conf
envsubst < /etc/odoo/odoo.conf > /etc/odoo/odoo.conf.tmp
mv /etc/odoo/odoo.conf.tmp /etc/odoo/odoo.conf

# Start Odoo
exec odoo "$@"
