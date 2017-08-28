FROM debian:jessie

RUN export DEBIAN_FRONTEND=noninteractive \
 && apt-get -q -y update \
 && apt-get -q -y install runit \
                          locales \
                          dirvish \
                          rsyslog \
                          postfix \
 && apt-get -q -y clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
 \
 && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && dpkg-reconfigure --frontend=noninteractive locales \
 && update-locale LANG=en_US.UTF-8 \
 \
 && head -n $(grep -n RULES /etc/rsyslog.conf | cut -d':' -f1) /etc/rsyslog.conf > /etc/rsyslog.conf.new \
 && mv /etc/rsyslog.conf.new /etc/rsyslog.conf \
 && echo '*.*        /dev/stdout' >> /etc/rsyslog.conf \
 && sed -i '/imklog/d' /etc/rsyslog.conf \
 \
 && mkdir -p /etc/sv/rsyslog /etc/sv/postfix /etc/sv/cron \
 && echo '#!/bin/sh\nexec /usr/sbin/rsyslogd -n' > /etc/sv/rsyslog/run \
 && echo '#!/bin/sh\nrm /var/run/rsyslogd.pid' > /etc/sv/rsyslog/finish \
 && echo '#!/bin/sh\nservice postfix start; sleep 5; while ps aux | grep [p]ostfix | grep [m]aster > /dev/null 2> /dev/null; do sleep 5; done' > /etc/sv/postfix/run \
 && echo '#!/bin/sh\nservice postfix stop' > /etc/sv/postfix/finish \
 \
 && echo '#!/bin/sh\nexec /usr/sbin/cron -f' > /etc/sv/cron/run \
 \
 && chmod a+x /etc/sv/*/run /etc/sv/*/finish \
 \
 && ln -s /etc/sv/cron /etc/service/cron \
 && ln -s /etc/sv/postfix /etc/service/postfix \
 && ln -s /etc/sv/rsyslog /etc/service/rsyslog

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

COPY scripts /usr/local/bin

VOLUME ["/config", "/backups"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
