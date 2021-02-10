#!/bin/bash

# Change the ownership of the odoo folder to match the odoo container user.

# Parse the .env variables by finding them in the same path as this script.

source .env

sudo chown -Rv 101:101 /srv/container-volumes/odoo ./odoo
