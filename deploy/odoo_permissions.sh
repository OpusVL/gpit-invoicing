#!/bin/sh

# Change the ownership of the odoo folder to match the odoo container user.

# Parse the .env variables by finding them in the same path as this script.
eval $(egrep -v '^#' $(dirname `readlink -f $0`)/.env)

sudo chown -Rv `docker-compose exec odoo sh -c "grep odoo /etc/passwd | cut -f3,4 -d:"| sed "s/\r//"` ${CONTAINER_VOLUME}/odoo ./odoo

