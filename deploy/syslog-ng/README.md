# syslog-ng Service

This captures logs from Docker into the file system.

It includes logrotate and operates crond and syslog-ng under supervisor. By doing this logrotate is able to restart the syslog-ng service using `supervisorctl` without taking the container set down.

The image can be used as a standalone container or as part of an existing container set. When using it standalone I like to restrict the IP is listens on to 127.0.0.1 to ensure no outside systems can make use of it, but it can still be used by containers withing the same system.

## Sample docker-compose.yml

```yaml
version: '3.2'

services:
  syslog:
    build: build
    volumes:
      - "${PWD}/syslog/odoo.conf:/etc/syslog-ng/conf.d/odoo.conf"
      - "${PWD}/syslog/logrotate.d/odoo:/etc/logrotate.d/odoo"
      - "${CONTAINER_VOLUME}/log:/var/log"    
    ports: 
      - "127.0.0.1:514:514/udp"
      - "127.0.0.1:514:514/tcp"
```

### Usage

Add the dependance to the container service that output the logs. This is required for `tcp://` because without being able to get a connection the service will fail.

Then add the `logging:` stanza pointing at the syslog server with an optional `tag:` to specify the program that is sending the log messages.

```yaml
    depends_on:
      - syslog      
    logging:
      driver: 'syslog'
      options:
        syslog-address: 'tcp://127.0.0.1:514'
        tag: 'keycloak'
```

### Logging

You can mount in your own syslog config file such as the `odoo.conf` in the example. The example below assumes we;re using programs for idd, odoo-cron, postgres and keycloak. Go ahead and change these to suit whatever usage you require.

#### odoo.conf

Notice the sources for network and udp to cover post 514 for udp and tcp. Also note the regex for `^odoo$` to ensure odoo and odoo-cron are handle differently.

```text
source s_network {
  network();
};

source s_udp {
  udp();
};

filter f_odoo {
  program(^odoo$);
};

destination d_odoo {
  file(
    "/var/log/odoo.log"
    template(t_file)
  );
};

log {
  source(s_network);
  source(s_udp);
  filter(f_odoo);
  destination(d_odoo);
};

filter f_odoo_cron {
  program(^odoo-cron$);
};

destination d_odoo_cron {
  file("/var/log/odoo-cron.log");
};

log {
  source(s_network);
  source(s_udp);
  filter(f_odoo_cron);
  destination(d_odoo_cron);
};

filter f_postgres {
  program(postgres);
};

destination d_postgres {
  file("/var/log/postgres.log");
};

log {
  source(s_network);
  source(s_udp);
  filter(f_postgres);
  destination(d_postgres);
};

filter f_keycloak {
  program(keycloak);
};

destination d_keycloak {
  file("/var/log/keycloak.log");
};

log {
  source(s_network);
  source(s_udp);
  filter(f_keycloak);
  destination(d_keycloak);
};
```

This separates out the logs based on the program name passed by docker.

### Log Rotation

Log rotation is dealt with by `cron` and uses `/etc/periodic/daily/logrotate`

Also mount in the rotation required for your logs, eg.

#### logrotate.d/odoo

```text
/var/log/keycloak.log
/var/log/odoo.log
/var/log/odoo-cron.log
/var/log/postgres.log
{
  rotate 31
  daily
  missingok
  notifempty
  delaycompress
  compress
}
```
