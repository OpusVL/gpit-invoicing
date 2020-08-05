#!/bin/sh

# Change the ownership of the odoo folder to match the odoo container user.

# Parse the .env variables by finding them in the same path as this script.
eval $(egrep -v '^#' $(dirname `readlink -f $0`)/.env)

sudo chown -Rv 101:101 ${CONTAINER_VOLUME}/odoo ./odoo

