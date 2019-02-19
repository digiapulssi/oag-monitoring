#!/bin/bash
# Version: 1.0
set -e

# Usage: ./oag-log-path-discovery.sh <path to discovery list configuration file>
# The configuration file has the following format:
# PATH|BACKEND|THRESHOLD_COUNT|THRESHOLD_MINUTES|ID

CONFIG_FILE="$1"
if [ -z "$CONFIG_FILE" ]; then
  echo "Argument missing"
  exit 1
fi

# The discovery returns a discovery list in zabbix LLD format with the following macros:
#  {#PATH}
# Take distinct paths
echo -n '{"data":['
grep -Eo '^([^|]+)|' "$CONFIG_FILE" | awk '!a[$0]++' | sed 's/\(.*\)/{"{#PATH}":"\1"}/g' | sed '$!s/$/,/' | tr '\n' ' '
echo -n ']}'
