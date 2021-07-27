#!/bin/bash

#
# FUNCTIONS
#

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

get_dirvish_option() {
  option=$1
  cat /etc/dirvish/master.conf |
      sed -n '
	s/^#.*//;	# Strip comments
	/^\s/{ H; b }	# Indented line: append to hold, and start next cycle
	/^\w/ba		# A word means option assignment. Process it
	b		# If we get this far, start next cycle.
	:a		# Label a: we have just seen a word. So now
			# the holding space contains the previous
			# "option: value" line, as well as any space-indented
			# lines that came after that.
			# Now we need to look at holding space and see
			# if it has the option we want.
	x		# Swap hold and pattern
	/^'"${option}"'/{
		s/^\(-\|\w\)\+:\s*//	# Remove the option and colon
		s/\n\+/ /g		# Translate newlines to spaces
		p			# Print the option value
		q			# And quit
	}
	$ba		# If the option we want is at end of file,
			# then we just stashed it in holding space. So
			# swap again, and redo the processing.
	'
}

#
# SETUP
#

# sed is to remove time information - it should always only start with the date - with time, it won't fetch all results
DIR_DATE_FMT=$(get_dirvish_option image-default | sed 's/%[HMIklNpPrRSTXz]//g')
: ${DIR_DATE_FMT:=%Y%m%d}

if [ ! -z "$1" ]; then
  DATE="$1"
else
  DATE=$(date +${DIR_DATE_FMT})
fi
HUMAN_READABLE_DATE=$(date -ud "$DATE" +'%Y-%m-%d')

#
# COLLECT
#

BANKS=`get_dirvish_option bank`
RUNALLS=`get_dirvish_option Runall`

BACKUP_PATHS=""

MISSING_BACKUP_NUMBER=0
MISSING_BACKUPS=""

for BANK in $BANKS; do
  for RUNALL in $RUNALLS; do
    CUR_DIR="$BANK/$RUNALL"
    CUR_BACKUP_DIR=$(ls -td $CUR_DIR/$DATE* 2>/dev/null | head -n1)
    if [ -d "$CUR_DIR" ]; then
      if [ -d "$CUR_BACKUP_DIR" ]; then
        BACKUP_PATHS="$BACKUP_PATHS $CUR_BACKUP_DIR"
      else
        MISSING_BACKUP_NUMBER=$(expr $MISSING_BACKUP_NUMBER + 1)
        MISSING_BACKUPS="$MISSING_BACKUPS $RUNALL"
      fi
    fi
  done
done

FS_USAGE_PERCENT=$(df -h /backups | grep '/backups$' | awk '{print $5}' | sed 's/%//g')
NUMBER_OF_BACKUPS=$(echo "$BACKUP_PATHS" | tr ' ' '\n' | grep . | wc -l)
NON_SUCCESS_STATUS=$(echo "$BACKUP_PATHS" | tr ' ' '\n' | grep . | sed 's/$/\/summary/g' | sed 's/^/cat /g' | bash | grep 'Status:' | sed 's/^[^:]*: //g' | uniq | grep -v success | tr '\n' ' ')

#
# REPORT
#

echo "dirvish report - $HUMAN_READABLE_DATE"

if [ ! -z "$MISSING_BACKUPS" ]; then
  ERROR_MESSAGE_MBU="ERROR: $MISSING_BACKUP_NUMBER missing backups: $MISSING_BACKUPS"
  echo ""
  echo "$ERROR_MESSAGE_MBU"
fi

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

for BACKUP_PATH in $BACKUP_PATHS; do
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
