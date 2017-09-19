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
#    will print list of target servers (aka remote hosts) in Zabbix low level discovery format where {#SERVER} is the server name
#  - server: Server metric,
#    argument1 is target server name,
#    argument2 is one of numReportedUps, volumeBytesOut, respTimeMax, respTimeMin, volumeBytesIn, numTransactions,
#                        respTimeAvg, numReportedDowns, uptime
#  - method_discovery (with no command arguments)
#    will print list of methods in Zabbix low level discovery format where {#METHOD} is the method name
#  - method: Method metric,
#    argument1 is method name,
#    argument2 is one of exceptions, failures, numMessages, processingTimeMin, successes, processingTimeMax,
#                       uptime, processingTimeAvg
#  - service_discovery (with no command arguments)
#    will print list of methods in Zabbix low level discovery format where {#SERVICE} is the service name
#  - service: Service metric,
#    argument1 is service name,
#    argument2 is one of exceptions, failures, numMessages, processingTimeMin, successes, processingTimeMax, uptime, processingTimeAvg
#  - client_discovery (with no command arguments)
#    will print list of clients in Zabbix low level discovery format where {#CLIENT} is the client name
#  - client: Client metric,
#    argument1 is client name,
#    argument2 is one of exceptions, failures, numMessages, successes, uptime

# JMX request is performed only one per minute
# Subsequent script calls use cached result file

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$#" -lt 4 ]; then
  echo "Missing command-line arguments"
  exit 1
fi
SERVER_AND_PORT="$1"
USERNAME="$2"
PASSWORD="$3"
COMMAND="$4"
ARGUMENT="$5"
ARGUMENT2="$6"

if [ ! -f "/tmp/oag-jmx-monitoring.cache.txt" -o "`find /tmp/oag-jmx-monitoring.cache.txt -mmin +1 2>/dev/null`" ]; then
  # Cache is older than one minute

  # Use docker if it's installed and the current user have rights to access the docker engine
  if command -v docker >/dev/null 2>&1 && [ -w /var/run/docker.sock ]; then

    echo get -b com.vordel.rtm:type=Metrics AllMetricGroupTotals \
         | docker run --rm -i -v "${DIR}/jmxterm-1.0.0-uber.jar:/jmxterm.jar:ro" java:7 \
           java -jar /jmxterm.jar \
           -l "service:jmx:rmi:///jndi/rmi://${SERVER_AND_PORT}/jmxrmi" -u "${USERNAME}" -p "${PASSWORD}" -n -v silent > /tmp/oag-jmx-monitoring.cache.txt

  else
    if [ ! command -v java >/dev/null 2>&1 ]; then
      echo "Java is not installed; either Java or Docker must be installed"
      exit 1
    fi

    echo get -b com.vordel.rtm:type=Metrics AllMetricGroupTotals \
         | java -jar "${DIR}/jmxterm-1.0.0-uber.jar" \
           -l "service:jmx:rmi:///jndi/rmi://${SERVER_AND_PORT}/jmxrmi" -u "${USERNAME}" -p "${PASSWORD}" -n -v silent > /tmp/oag-jmx-monitoring.cache.txt
  fi
fi




case $COMMAND in

  ## System block is like the following:
  # }, { 
  #  groupName = System overview;
  #  cpuUsed = 7;
  #  systemMemoryUsed = 7886232;
  #  cpuUsedMax = 47;
  #  memoryUsedMin = 474712;
  #  cpuUsedAvg = 5;
  #  diskUsedPercent = 37;
  #  exceptions = 42981;
  #  numMessagesProcessed = 14203989;
  #  messageMonitoringEnabled = false;
  #  systemCpuAvg = 6;
  #  metricsLoggingEnabled = true;
  #  processSignature = oagserver:instance-1;
  #  groupType = SystemOverview;
  #  failures = 6899;
  #  successes = 14154109;
  #  serverTitle = instance-1;
  #  uptime = 521274;
  #  numSLABreaches = 0;
  #  serverHost = oagserver;
  #  cpuUsedMin = 1;
  #  memoryUsedMax = 1082992;
  #  groupId = 6;
  #  numAlerts = 0;
  #  monitoringEnabled = true;
  #  systemCpuMin = 1;
  #  serverGroup = group-2;
  #  systemCpuMax = 99;
  #  systemMemoryTotal = 8057808;
  #  memoryUsedAvg = 1071296;
  # }, { 


  system)
    LINE=$(sed -n -e '/groupName = System overview;/,/}, { / p' /tmp/oag-jmx-monitoring.cache.txt | grep "$ARGUMENT =")
    VALUE=$(echo "$LINE" | sed -e 's/.*= \(.*\);/\1/')
    echo "$VALUE"
  ;;

  ## Target server block is like the following:
  #  }, { 
  #  respTimeRange1 = 49;
  #  respTimeRange3 = 17;
  #  groupName = server1:80;
  #  respTimeRange2 = 0;
  #  respTimeRange5 = 30;
  #  respTimeRange4 = 11;
  #  respTimeRange7 = 2;
  #  numReportedUps = 0;
  #  respTimeRange6 = 5;
  #  respTimeRange9 = 0;
  #  respTimeRange8 = 0;
  #  volumeBytesOut = 13528720;
  #  respTimeMax = 16407;
  #  respTimeMin = 939;
  #  respTimeRange10 = 35;
  #  volumeBytesIn = 22654400;
  #  numTransactions = 149;
  #  groupType = TargetServer;
  #  respTimeAvg = 313;
  #  numReportedDowns = 0;
  #  uptime = 451817;
  #  respStatRange5 = 0;
  #  respStatRange2 = 149;
  #  respStatRange1 = 0;
  #  respStatRange4 = 0;
  #  respStatRange3 = 0;
  #  groupId = 63;
  # }, { 

  server_discovery)
    echo -n '{"data":['
    # Get each groupName 15 lines before groupType = TargetServer
    # And format lines to json
    grep -B 15 'groupType = TargetServer;' /tmp/oag-jmx-monitoring.cache.txt \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/' \
      | sed 's/\(.*\)/{"{#SERVER}":"\1"}/g' | sed '$!s/$/,/' | tr '\n' ' '
    echo -n ']}'
  ;;

  server)
    LINE=$(grep -B 2 -A 24 'groupName = '"${ARGUMENT}"';' /tmp/oag-jmx-monitoring.cache.txt | grep "$ARGUMENT2 =")
    VALUE=$(echo "$LINE" | sed -e 's/.*= \(.*\);/\1/')
    echo "$VALUE"
  ;;

  ## Method block is like the following:
  #  }, { 
  #  groupType = Method;
  #  exceptions = 0;
  #  failures = 0;
  #  groupId = 53;
  #  groupName = MyMethod;
  #  numMessages = 2877;
  #  processingTimeMin = 150;
  #  successes = 2877;
  #  processingTimeMax = 10549;
  #  uptime = 519758;
  #  groupParentId = 51;
  #  processingTimeAvg = 465;
  # }, { 

  method_discovery)
    echo -n '{"data":['
    # Get each groupName four lines after groupType = Method
    # And format lines to json
    grep -A 4 'groupType = Method;' /tmp/oag-jmx-monitoring.cache.txt \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/' \
      | sed 's/\(.*\)/{"{#METHOD}":"\1"}/g' | sed '$!s/$/,/' | tr '\n' ' '
    echo -n ']}'
  ;;

  method)
    LINE=$(grep -B 4 -A 7 'groupName = '"${ARGUMENT}"';' /tmp/oag-jmx-monitoring.cache.txt | grep "$ARGUMENT2 =")
    VALUE=$(echo "$LINE" | sed -e 's/.*= \(.*\);/\1/')
    echo "$VALUE"
  ;;

  ## Service block is like the following:
  #  }, { 
  #  groupType = Service;
  #  exceptions = 0;
  #  failures = 0;
  #  groupId = 31;
  #  groupName = MyWebService;
  #  numMessages = 874;
  #  processingTimeMin = 34;
  #  successes = 874;
  #  processingTimeMax = 266;
  #  uptime = 521052;
  #  processingTimeAvg = 42;
  # }, { 

  service_discovery)
    echo -n '{"data":['
    # Get each groupName four lines after groupType = Service
    # And format lines to json
    grep -A 4 'groupType = Service;' /tmp/oag-jmx-monitoring.cache.txt \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/' \
      | sed 's/\(.*\)/{"{#SERVICE}":"\1"}/g' | sed '$!s/$/,/' | tr '\n' ' '
    echo -n ']}'
  ;;

  service)
    LINE=$(grep -B 4 -A 6 'groupName = '"${ARGUMENT}"';' /tmp/oag-jmx-monitoring.cache.txt | grep "$ARGUMENT2 =")
    VALUE=$(echo "$LINE" | sed -e 's/.*= \(.*\);/\1/')
    echo "$VALUE"
  ;;

  ## Client block is like the following:
  #  }, { 
  #  groupType = Client;
  #  exceptions = 0;
  #  failures = 0;
  #  groupId = 44;
  #  groupName = My Client;
  #  numMessages = 1122;
  #  successes = 1122;
  #  uptime = 520975;
  # }, { 

  client_discovery)
    echo -n '{"data":['
    # Get each groupName four lines after groupType = Client
    # And format lines to json
    grep -A 4 'groupType = Client;' /tmp/oag-jmx-monitoring.cache.txt \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/' \
      | sed 's/\(.*\)/{"{#CLIENT}":"\1"}/g' | sed '$!s/$/,/' | tr '\n' ' '
    echo -n ']}'
  ;;

  client)
    LINE=$(grep -B 4 -A 3 'groupName = '"${ARGUMENT}"';' /tmp/oag-jmx-monitoring.cache.txt | grep "$ARGUMENT2 =")
    VALUE=$(echo "$LINE" | sed -e 's/.*= \(.*\);/\1/')
    echo "$VALUE"
  ;;

  *)
  echo "Undefined command $COMMAND"
  exit 1
  ;;

esac

