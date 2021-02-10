<img src="./.assets/nhs-digital-logo.svg" height="150px">

# gpit-invoicing

GP IT Futures invoicing system

## Dependencies

PostgreSQL - Amazon RDS Database

Odoo Container Set - Odoo and syslog-ng services

OpusVL Documentation: [Link](https://wiki.opusvl.io/wiki/GPIT_-_Amazon_AWS#Terraform_.2F_aws-vault)

## Basic Features

Docker container set using docker-compose to provide an instance of Odoo from the OpusVL repository.

This is the sanitised output from `docker-compose config` to demonstrate the containers expected runtime build.

### docker-compose.yml

```yaml
services:
  odoo:
    command: --max-cron-threads 0 --workers 8 --log-handler=:INFO
    environment:
      PASSWORD: SecretKey
      USER: odoo
    image: registry.deploy.opusvl.net/gp-it-futures/odoo:uat
    logging:
      driver: syslog
      options:
        syslog-address: udp://127.0.0.1:514
        tag: odoo
    ports:
    - published: 8069
      target: 8069
    - published: 8070
      target: 8072
    restart: unless-stopped
    volumes:
    - /srv/container-volumes/invoicing/odoo/extra-addons:/mnt/extra-addons:rw
    - ./odoo/etc:/etc/odoo:rw
  odoo-cron:
    command: --max-cron-threads 8 --no-xmlrpc --database UAT
    environment:
      PASSWORD: SecretKey
      USER: odoo
    image: registry.deploy.opusvl.net/gp-it-futures/odoo:uat
    logging:
      driver: syslog
      options:
        syslog-address: udp://127.0.0.1:514
        tag: odoo-cron
    ports:
    - target: 8072
    restart: unless-stopped
    volumes:
    - /srv/container-volumes/invoicing/odoo/extra-addons:/mnt/extra-addons:rw
    - ./odoo/etc:/etc/odoo:rw
version: '3.2'
```

Notable changes are the dynamic tag `:uat` for the repository tag. This allows the tag to remain the same and OpusVL will tag the latest version to be pulled to uat with the tag `uat`. This ensures that at any future date a reboot/rebuild of the AWS platform will call upon the most recent version of Odoo from the repository and not regress.

Similarly the `ODOO_CRON_DB` has been fixed to `UAT` for the same regression reasons. This does not prevent GPIT from having older databases for testing, but ensure that the UAT database is deemed the most current and up to date version according to module updates, and is always available even after a reboot/rebuild.

The logging driver ensure that output is taken from the Odoo container set and sent to the `syslog-ng` service. This is also a container set. The purpose for this is to ensure all service logs are captured and stored in the mounted S3 bucket for persistence beyond restarts.

### invoicing-base.tf

This is a snippet of the `invoicing-base.tf` that shows the scripting used for building the Odoo container set.

```bash
cat << TAC > /root/deploy/start
docker login -u="${var.docker_login}" -p="${var.docker_login_password}" ${var.odoo_image}
mkdir -p /srv/container-deployment/syslog-ng
mkdir -p /srv/container-deployment/invoicing/odoo/etc
mkdir -p /srv/container-volumes/odoo
mkdir -p /srv/logs
gpasswd -a ubuntu docker
apt -y install postgresql-client
curl -o /srv/container-deployment/invoicing/odoo/etc/odoo.conf.tpl https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/odoo.conf.tpl
curl -o /srv/container-deployment/invoicing/docker-compose.yml.tpl https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/docker-compose.yml.tpl
curl -o /srv/container-deployment/invoicing/.env https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/.env
curl -o /srv/container-deployment/invoicing/odoo_permissions.sh.tpl https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/odoo_permissions.sh.tpl
curl -o /srv/container-deployment/invoicing/template.sh https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/template.sh
curl -o /etc/ssl/openssl.cnf https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/openssl.cnf
chmod +x /srv/container-deployment/invoicing/*.sh
cd /srv/container-deployment/invoicing/syslog-ng
docker-compose pull
docker-compose up -d
cd /srv/container-deployment/invoicing
echo "ADMIN_PASS=${var.admin_pass}" > .env
echo "CONTAINER_VOLUME=/srv/container-volumes" >> .env
echo "LIMIT_MEMORY_HARD=${var.limit_memory_hard}" >> .env
echo "LIMIT_MEMORY_SOFT=${var.limit_memory_soft}" >> .env
echo "LIMIT_TIME_CPU=${var.limit_time_cpu}" >> .env
echo "LIMIT_TIME_REAL=${var.limit_time_real}" >> .env
echo "ODOO_CRON_DB=${var.odoo_cron_db}" >> .env
echo "ODOO_IMAGE=${var.odoo_image}" >> .env
echo "ODOO_IMAGE_VERSION=${var.odoo_image_version}" >> .env
echo "ODOO_POSTGRES_PASSWORD=${var.odoo_password}" >> .env
echo "ODOO_POSTGRES_USER=odoo" >> .env
echo "POSTGRES_PASSWORD=${var.postgres_password}" >> .env
echo "RDS_PASS=${var.rds_pass}" >> .env
echo "SMTP_PASSWORD=${var.smtp_password}" >> .env
chmod +x template
./template.sh
docker-compose pull
docker-compose up -d && ./odoo_permissions.sh
TAC
chmod +x /root/deploy/start
/bin/bash /root/deploy/start
```

The simple description is that it uses a HEREDOC to `cat` the commands into `/root/deploy/start` then makes the script executable and runs it.

It creates the `.env` file from the variables in the `uat.auto.vars`. File __NOT__ included in repo due to sensitive data.

Using `curl` it pulls down `.tpl` files from the repo and runs the `template` script on them to replace template variables with environment variable values.

Notable additions are the assignment of the `ubuntu` user to the `docker` group. This allows the user to stop and start the container sets and prevents the `${PWD}` environment issue.

Also the `postgresql-client` apps are added to the OS. This allows the update of Odoo to be carried out and then a connection to the DB to delete the cached assets using `DELETE FROM ir_attachment WHERE url LIKE '/web/content/%';`

## Odoo and Module Update Process

```shell
docker-compose pull
docker-compose run --rm odoo -d uat -u ${MODULES_TO_UPGRADE} --stop-after-init
PGPASSWORD=${POSTGRES_PASSWORD} psql -h gpit-invoicing-db.czoyqvsb5e95.eu-west-2.rds.amazonaws.com -U odoo -d UAT
```
```sql
DELETE FROM ir_attachment WHERE url LIKE '/web/content/%';
```