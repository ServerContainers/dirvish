#!/bin/bash

if echo "$MAIL_RECIPIENTS" | grep -v '@' 2>/dev/null >/dev/null; then
  echo "no recipients specified, exiting... (MAIL_RECIPIENTS)"
  exit 0
fi

REPORT=$(/container/scripts/dirvish-report.sh)

DATE=$(echo "$REPORT" | head -n1 | sed 's/.* - //g')
NUMBER=$(echo "$REPORT" | grep 'Number of Backups:' | sed 's/^[^:]*: //g')

if echo "$REPORT" | grep 'WARN' 2>/dev/null >/dev/null; then
  SUBJECT="dirvish-report: WARNING $NUMBER - $DATE"
else
  SUBJECT="dirvish-report: $NUMBER - $DATE"
fi

# erro specific subjects
if echo "$REPORT" | grep 'ERROR' 2>/dev/null | grep 'missing backups' 2>/dev/null >/dev/null; then
  MISSING_NUMBER=$(echo "$REPORT" | grep 'ERROR' | grep 'missing backups' | sed -e 's/ERROR: //g' -e 's/ missing.*//g' )
  SUBJECT="dirvish-report: ERROR ($MISSING_NUMBER missing) $NUMBER - $DATE"
fi

for M_R in $MAIL_RECIPIENTS; do
  echo "sending report to $M_R"
  echo "$REPORT" | mail -s "$SUBJECT" -r "$RETURN_ADDRESS"  "$M_R"
done
