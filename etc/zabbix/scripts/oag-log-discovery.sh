#!/bin/bash
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
#  {#THRESHOLD_MINUTES}
#  {#ID}

echo -n '{"data":['
sed -n -e 's/^\(.*\)|\(.*\)|\(.*\)|\(.*\)|\(.*\)$/{"{#PATH}":"\1","{#BACKEND}":"\2","{#THRESHOLD_COUNT}":"\3","{#THRESHOLD_MINUTES}":"\4","{#ID}":"\5"}/p' "$CONFIG_FILE" \
  | sed '$!s/$/,/' \
  | tr '\n' ' '
echo -n ']}'
