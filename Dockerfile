FROM debian:bullseye

ENV PATH="/container/scripts:${PATH}"

RUN export DEBIAN_FRONTEND=noninteractive \
 && apt-get -q -y update \
 && apt-get -q -y install runit \
                          cron \
                          dirvish \
                          postfix \
                          mailutils \
 && apt-get -q -y clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
 
COPY . /container/

VOLUME ["/config", "/backups"]
ENTRYPOINT ["/container/scripts/entrypoint.sh"]
CMD [ "/usr/bin/runsvdir","-P", "/container/config/runit" ]