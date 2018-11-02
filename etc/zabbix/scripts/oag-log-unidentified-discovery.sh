#!/bin/bash
# Version: 1.0
set -e

CONNECTIONS=$(cat $(ls -t /opt/oracle/OAG-11.1.2.4.0/apigateway/events/processed/group-2* | head -1) | jq -r '"\(.path),\(.customMsgAtts["http.destination.host"])"' | sort -u | grep -v "^null," | grep -v ",null$")
DISCOVERY_LIST=$(cat /opt/oracle/OAG-11.1.2.4.0/apigateway/conf/oag-discovery-list.csv | sed -e 's/^\([^|]*\)|\([^|]*\)|.*/\1,\2/g' | sort -u | grep -v PATH)

for CON in $CONNECTIONS;do
	if ! [[ "$DISCOVERY_LIST" =~ "$CON" ]];then
		echo $CON "<br>"
	fi
done
