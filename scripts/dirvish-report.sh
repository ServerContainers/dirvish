#!/bin/bash

if [ ! -z "$1" ]; then
  DATE="$1"
else
  DATE=$(date +%Y%m%d)
fi
HUMAN_READABLE_DATE=$(date -ud "$DATE" +'%Y-%m-%d')

calculate_time_difference() {
  date_1="$1"
  date_2="$2"

  echo $(( ( $(date -ud "$date_2" +'%s') - $(date -ud "$date_1" +'%s') ) ))
}

human_readable_seconds() {
  seconds="$1"
  case 1 in
      $(($seconds<= 60))) echo "$seconds seconds";;
      $(($seconds<= 3600)))echo "$(( ($seconds)/60 )) minutes";;
      $(($seconds<= 86400)))echo "$(( ($seconds)/60/60 )) hours";;
                         *)echo "$(( (($seconds)/60/60 )/60/60/24 )) days";;
  esac
}

human_readable_bytes() {
  bytes="$1"
  numfmt --to=iec-i --suffix=B --padding=7 "$bytes"
}

BANKS=$(cat config/master.conf | sed 's/#.*//g' | sed -n '/bank:/,/^\w/p' | sed -e '/^\w/d' -e '/^$/d')
RUNALL=$(cat config/master.conf | sed 's/#.*//g' | sed -n '/Runall:/,/^\w/p' | sed -e '/^\w/d' -e '/^$/d')

FS_USAGE_PERCENT=$(df -h /backups | grep '/backups$' | awk '{print $5}' | sed 's/%//g')
NUMBER_OF_BACKUPS=$(find /backups -mindepth 3 -maxdepth 3 -type d ! -name "dirvish" -iname $DATE\* | wc -l)
NON_SUCCESS_STATUS=$(find /backups -mindepth 3 -maxdepth 3 -type d ! -name "dirvish" -iname $DATE\* | sed 's/$/\/summary/g' | sed 's/^/cat /g' | bash | grep 'Status:' | sed 's/^[^:]*: //g' | uniq | grep -v success | tr '\n' ' ')


echo "dirvish report - $HUMAN_READABLE_DATE"

if [ ! -z "$NON_SUCCESS_STATUS" ]; then
  WARNING_MESSAGE_NSS="WARN: non success status: $NON_SUCCESS_STATUS"
  echo ""
  echo "$WARNING_MESSAGE_NSS"
fi

if [ "$FS_USAGE_PERCENT" -gt 95 ]; then
  WARNING_MESSAGE_FS_PCT="WARN: FS Usage at $FS_USAGE_PERCENT %"
  echo ""
  echo "$WARNING_MESSAGE_FS_PCT"
fi
echo ""

echo "Number of Backups: $NUMBER_OF_BACKUPS"

echo ""

printf "%-30s\t%-20s\t%-20s\t%-20s\t%-20s\t%s\n" "[BACKUP NAME]" "[BACKUP STATUS]" "[DATA RECEIVED]" "[BACKUP RUNTIME]" "[BACKUP BEGIN]" "[BACKUP END]"

find /backups -mindepth 3 -maxdepth 3 -type d ! -name "dirvish" -iname $DATE\* | while read BACKUP_PATH
do
  BACKUP_NAME=$(dirname "$BACKUP_PATH" | sed 's/.*\///g')
  BACKUP_STATUS=$(cat "$BACKUP_PATH/summary" | grep 'Status:' | sed 's/^[^:]*: //g')

  BACKUP_BEGIN=$(cat "$BACKUP_PATH/summary" | grep 'Backup-begin:' | sed 's/^[^:]*: //g')
  BACKUP_END=$(cat "$BACKUP_PATH/summary" | grep 'Backup-complete:' | sed 's/^[^:]*: //g')

  BACKUP_RUNTIME_SECONDS=$(calculate_time_difference "$BACKUP_BEGIN" "$BACKUP_END")
  BACKUP_RUNTIME=$(human_readable_seconds "$BACKUP_RUNTIME_SECONDS")

  BACKUP_RECEIVED_BYTES=$(cat "$BACKUP_PATH/log" | grep 'Total bytes received:' | sed 's/,//g' | sed 's/^[^:]*: //g')
  BACKUP_RECEIVED=$(human_readable_bytes "$BACKUP_RECEIVED_BYTES")

  printf "%-30s\t%-20s\t%-20s\t%-20s\t%-20s\t%s\n" "$BACKUP_NAME" "$BACKUP_STATUS" "$BACKUP_RECEIVED" "$BACKUP_RUNTIME" "$BACKUP_BEGIN" "$BACKUP_END"
done


echo ""

df -h /backups | grep '/backups$' | awk '{print "Filesystem status: "$5" of "$2" used. "$4" left and "$3" already in use."}'
