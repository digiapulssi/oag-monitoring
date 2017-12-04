#!/bin/bash
set -e

# Usage: ./oag-log-unidentified-discovery.sh <path to discovery list configuration file>
# The configuration file has the following format:
# PATH|BACKEND|THRESHOLD_COUNT|THRESHOLD_MINUTES|ID

CONFIG_FILE="$1"
if [ -z "$CONFIG_FILE" ]; then
  echo "Argument missing"
  exit 1
fi

# The discovery returns a discovery list in zabbix LLD format with the following macros:
#  {#REGEXP}
# The discovery returns always just one discovered item
# The regexp is generated so that it matches all log lines corresponding to |PATH|BACKEND| combinations that are NOT configured in configuration file
# ie. missing configurations
# See https://stackoverflow.com/questions/7801581/regex-for-string-not-containing-multiple-specific-words
# REGEXP can be tested with grep -P.

# Note that this requires Zabbix agent version 3.4 or later because it switches from POSIX extended syntax (which does not support
# negative look-aheads) to PCRE (Perl Compatible Regular Expressions). See https://support.zabbix.com/browse/ZBX-3924.

echo -n '{"data":[{"{#REGEXP}":"^(?!.*('
sed -n -e 's/^\(.*\)|\(.*\)|\(.*\)|\(.*\)|\(.*\)$/|\1|\2|/p' "$CONFIG_FILE" \
  | sed 's/[]\.\\|$(){}?+*^]/\\&/g' \
  | sed '$!s/$/|/' \
  | tr -d '\n'
echo -n ')).*$"}]}'
