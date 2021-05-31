<img src="./.assets/nhs-digital-logo.svg" height="150px">

# gpit-invoicing

GP IT Futures invoicing system

## Dependencies

PostgreSQL - Amazon RDS Database

Odoo Container Set

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
      driver: 'awslogs'
      options:
        awslogs-region: 'eu-west-2'
        awslogs-group: '/srv/logs/odoo.log'

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
      driver: 'awslogs'
      options:
        awslogs-region: 'eu-west-2'
        awslogs-group: '/srv/logs/odoo-cron.log'
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
#!/bin/bash
mkdir /root/deploy
cat << TAC > /root/deploy/start
DOCKER_USER=\$(echo "${var.docker_login}" | base64 -d | base64 -d)
echo "${var.docker_login_password}" | docker login --username="\$DOCKER_USER" --password-stdin ${var.odoo_image}
git clone https://github.com/OpusVL/gpit-aws-odoo.git /srv/container-deployment/invoicing
mkdir -p /srv/container-deployment/invoicing/odoo/etc
mkdir -p /srv/container-volumes/odoo
cd /srv/container-deployment/invoicing
echo "ADMIN_PASS=${var.odoo_admin_pass}" > .env
echo "CONTAINER_VOLUME=/srv/container-volumes" >> .env
echo "DB_HOST=${module.db.this_db_instance_address}" >> .env
echo "DB_PORT=${module.db.this_db_instance_port}" >> .env
echo "LIMIT_TIME_CPU=${var.limit_time_cpu}" >> .env
echo "LIMIT_TIME_REAL=${var.limit_time_real}" >> .env
echo "ODOO_DATABASE=${var.odoo_database}" >> .env
echo "ODOO_CRON_DB=${var.odoo_database}" >> .env
echo "ODOO_IMAGE=${var.odoo_image}" >> .env
echo "ODOO_IMAGE_VERSION=${var.odoo_image_version}" >> .env
echo "ODOO_POSTGRES_PASSWORD=${var.odoo_postgres_password}" >> .env
echo "ODOO_POSTGRES_USER=odoo" >> .env
echo "POSTGRES_PASSWORD=${var.postgres_password}" >> .env
echo "RDS_PASS=${var.rds_password}" >> .env
echo "SMTP_PASSWORD=${var.smtp_password}" >> .env
echo "HOST=${var.host}" >> .env
echo "ICINGA_HOST=${var.icinga_host}" >> .env
echo "ICINGA_PORT=${var.icinga_port}" >> .env
echo "ICINGA_USER=${var.icinga_user}" >> .env
echo "ICINGA_PASSWORD=${var.icinga_password}" >> .env
./init.sh
docker-compose pull
docker-compose up -d
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
./update.sh
```