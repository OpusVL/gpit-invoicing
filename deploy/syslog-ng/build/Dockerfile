FROM alpine:3.11

LABEL maintainer="Paul Bargewell <paul.bargewell@opusvl.com>"

RUN apk update && \
  apk add \
    logrotate \
    supervisor \
    syslog-ng

COPY ./supervisord.conf /etc/supervisord.conf

COPY ./syslog-ng.ini /etc/supervisor.d/syslog-ng.ini

COPY ./logrotate.d/syslog-ng /etc/logrotate.d/syslog-ng

EXPOSE 514/udp
EXPOSE 514/tcp 
EXPOSE 601/tcp
EXPOSE 6514/tcp

VOLUME [ "/var/log" ]

CMD [ "/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf" ]