#!/bin/bash
set -e

# Usage: ./oag-jmx.sh [SERVER:PORT] [USERNAME] [PASSWORD] [command] <command arguments>
# where command can be one of the following:
#  - system: System overview metric,
#    argument is one of cpuUsed, systemMemoryUsed, cpuUsedMax, memoryUsedMin, cpuUsedAvg, diskUsedPercent, exceptions, numMessagesProcessed,
#                       messageMonitoringEnabled, systemCpuAvg, metricsLoggingEnabled, processSignature, failures, successes, serverTitle,
#                       uptime, numSLABreaches, serverHost, cpuUsedMin, memoryUsedMax, numAlerts, monitoringEnabled, systemCpuMin,
#                       serverGroup, systemCpuMax, systemMemoryTotal, memoryUsedAvg
#  - server_discovery (with no command arguments)
#    will print list of target servers in Zabbix low level discovery format where {#SERVER} is the server name
#


# JMX request is performed only one per minute
# Subsequent script calls use cached result file

if [ "$#" -lt 4 ]; then
  echo "Missing command-line arguments"
  exit 1
fi
SERVER_AND_PORT="$1"
USERNAME="$2"
PASSWORD="$3"
COMMAND="$4"
ARGUMENT="$5"

if test "`find /tmp/oag-jmx-monitoring.cache.txt -mmin +1`"; then
  # Cache is older than one minute

  # Use docker if it's installed and the current user have rights to access the docker engine
  if [ command -v docker >/dev/null 2>&1 ] && [ -w /var/run/docker.sock ]; then

    echo get -b com.vordel.rtm:type=Metrics AllMetricGroupTotals \
         | docker run --rm -i -v /etc/zabbix/scripts/jmxterm-1.0.0-uber.jar:/jmxterm.jar:ro java:7 \
           java -jar /jmxterm.jar \
           -l "service:jmx:rmi:///jndi/rmi://${SERVER_AND_PORT}/jmxrmi" -u "${USERNAME}" -p "${PASSWORD}" -n -v silent > /tmp/oag-jmx-monitoring.cache.txt

  else
    if [ ! command -v java >/dev/null 2>&1 ]; then
      echo "Java is not installed; either Java or Docker must be installed"
      exit 1
    fi

    echo get -b com.vordel.rtm:type=Metrics AllMetricGroupTotals \
         | java -jar /etc/zabbix/scripts/jmxterm-1.0.0-uber.jar \
           -l "service:jmx:rmi:///jndi/rmi://${SERVER_AND_PORT}/jmxrmi" -u "${USERNAME}" -p "${PASSWORD}" -n -v silent > /tmp/oag-jmx-monitoring.cache.txt
  fi
fi




case $COMMAND in
  system)
    LINE=$(sed -n -e '/groupName = System overview;/,/}, { / p' /tmp/oag-jmx-monitoring.cache.txt | grep "$ARGUMENT")
    VALUE=$(echo "$LINE" | sed -e 's/.*= \(.*\);/\1/')
    echo "$VALUE"
  ;;

  server_discovery)
    echo -n '{"data":['
    # Get each groupName preceding groupType = TargetServer
    # And format lines to json
    sed -n -e '/groupName = / {
      x
      d
      }
      /groupType = TargetServer;/ {
      x
      p
      x
      }' /tmp/oag-jmx-monitoring.cache.txt | sed -e 's/.*= \(.*\);/\1/' | sed 's/\(.*\)/{"{#SERVER}":"\1"}/g' | sed '$!s/$/,/' | tr '\n' ' '
    echo -n ']}'
  ;;

esac

