#!/bin/sh
echo ">> copy config"
cp -r /config/* /etc/dirvish
sed -i 's/\r//g' /etc/dirvish/master.conf

echo ">> fix postfix"
postconf -e "maillog_file = /dev/stdout"
cp /etc/services /var/spool/postfix/etc/services
cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf

if [ -z "$TZ" ]; then
  TZ="Europe/Berlin"
fi
echo ">> setting timezone to $TZ"
ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
echo "$TZ" > /etc/timezone


if [ -z "$RETURN_ADDRESS" ]; then
  RETURN_ADDRESS="noreply@dirvish.backup.sys"
fi
echo ">> setting return address to $RETURN_ADDRESS"


if [ ! -z "$STANDALONE" ]; then
  echo ">> standalone mode only"
  /container/config/runit/postfix/run &
  /etc/dirvish/dirvish-cronjob
  /container/scripts/dirvish-report.sh
  /container/scripts/dirvish-mailer.sh
  echo ">> wait 5m for mails to sent out"
  sleep 5m
  echo ">> everything done - bye bye"
  exit 0
fi

if [ -z "$CRONTIME" ]; then
  CRONTIME="30 4 * * *"
fi
echo ">> setting crontime to $CRONTIME"
cat <<EOF > /etc/cron.d/dirvish
$CRONTIME    root    /bin/bash -c "/etc/dirvish/dirvish-cronjob; . /etc/profile; export MAIL_RECIPIENTS='$MAIL_RECIPIENTS'; export RETURN_ADDRESS='$RETURN_ADDRESS'; /container/scripts/dirvish-mailer.sh"
EOF

echo ">> start services"
exec /usr/bin/runsvdir -P /container/config/runit
