#!/bin/bash
# Version: 1.0
set -e

# Usage: ./oag-log-discovery.sh <path to discovery list configuration file>
# The configuration file has the following format:
# PATH|BACKEND|THRESHOLD_COUNT|THRESHOLD_MINUTES|ID

CONFIG_FILE="$1"
if [ -z "$CONFIG_FILE" ]; then
  echo "Argument missing"
  exit 1
fi

# The discovery returns a discovery list in zabbix LLD format with the following macros:
#  {#PATH}
#  {#BACKEND}
#  {#THRESHOLD_COUNT}
#  {#THRESHOLD_SECONDS}
#  {#ID}
#  {#CUSTOMER}

echo -n '{"data":['
LINES=$(cat "$CONFIG_FILE")
while read LINE; do
  if [[ "$LINE" =~ ^(.*)\|(.*)\|(.*)\|(.*)\|(.*)\|(.*)$ ]]; then
    PATH="${BASH_REMATCH[1]}"
    BACKEND="${BASH_REMATCH[2]}"
    THRESHOLD_COUNT="${BASH_REMATCH[3]}"
    THRESHOLD_MINUTES="${BASH_REMATCH[4]}"
    ID="${BASH_REMATCH[5]}"
    CUSTOMER="${BASH_REMATCH[6]}"

    THRESHOLD_SECONDS="$((THRESHOLD_MINUTES*60))"

    if [ -z "$NOFIRST" ]; then
      NOFIRST="1"
    else
      echo -n ","
    fi
    echo -n '{"{#PATH}":"'${PATH}'","{#BACKEND}":"'${BACKEND}'","{#THRESHOLD_COUNT}":"'${THRESHOLD_COUNT}'","{#THRESHOLD_MINUTES}":"'${THRESHOLD_MINUTES}'","{#THRESHOLD_SECONDS}":"'${THRESHOLD_SECONDS}'","{#ID}":"'${ID}'","{#CUSTOMER}":"'${CUSTOMER}'"}'
  else
    # Error parsing configuration line; skip it
    echo -n ''
  fi
done <<< "$LINES"
echo -n ']}'
