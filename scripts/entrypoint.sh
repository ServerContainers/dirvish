#!/bin/sh
echo ">> copy config"
cp /config/* /etc/dirvish

if [ -z "$TZ" ]; then
  TZ="Europe/Berlin"
fi
echo ">> setting timezone to $TZ"
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo $TZ > /etc/timezon

if [ ! -z "$STANDALONE" ]; then
  echo ">> standalone mode only"
  service postfix start
  /etc/dirvish/dirvish-cronjob
  /usr/local/bin/dirvish-report.sh
  /usr/local/bin/dirvish-mailer.sh
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
$CRONTIME    root    /bin/bash -c "/etc/dirvish/dirvish-cronjob; . /etc/profile; export MAIL_RECIPIENTS="$MAIL_RECIPIENTS"; /usr/local/bin/dirvish-mailer.sh"
EOF

echo ">> start services"
exec /usr/bin/runsvdir -P /etc/service
