#!/bin/bash
set -e

# Usage1: ./oag-jmx.sh [SERVER:PORT] [USERNAME] [PASSWORD] system <command arguments>
# Usage2: ./oag-jmx.sh [SERVER1:PORT] [SERVER2:PORT] [USERNAME] [PASSWORD] [discovery command]
# Usage3: ./oag-jmx.sh [SERVER1:PORT] [SERVER2:PORT] [USERNAME] [PASSWORD] [metrics command] [argument1] [argument2]

# In 2. and 3. usages script uses both servers to merge the discovered remote hosts and sum up or calculate an average of the metrics
#
# Command can be one of the following:
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

# Refresh JMX cache if needed
# Arguments: SERVER:PORT CACHEFILE
function refresh_cache()
{
  SERVER_AND_PORT="$1"
  CACHE_FILE="$2"
  if [ ! -f "$CACHE_FILE" ] || [[ $(find "$CACHE_FILE" -mmin +2 -print 2>/dev/null) ]]; then
    # Cache is older than two minutes

    # Check if we had a connection error less than two minutes ago
    if [ -f "$CACHE_FILE.error" ] && [[ ! $(find "$CACHE_FILE.error" -mmin +2 -print 2>/dev/null) ]]; then
      # We have recently had a connection error to the server; don't try connection every time the script is called to get some metrics
      return 1
    fi

    # Use docker if it's installed and the current user have rights to access the docker engine
    if command -v docker >/dev/null 2>&1 && [ -w /var/run/docker.sock ]; then

      if ! echo get -b com.vordel.rtm:type=Metrics AllMetricGroupTotals \
           | docker run --rm --name "oag-jmx-monitoring-$CACHE_FILE" -i -v "${DIR}/jmxterm-1.0.0-uber.jar:/jmxterm.jar:ro" java:7 \
             java -jar /jmxterm.jar \
             -l "service:jmx:rmi:///jndi/rmi://${SERVER_AND_PORT}/jmxrmi" -u "${USERNAME}" -p "${PASSWORD}" -n -v silent > "$CACHE_FILE"; then
        # Failed, clean up cache so that subsequent calls do not just return empty data
        rm -f "$CACHE_FILE"
        touch "$CACHE_FILE.error"
        return 1
      fi

    else
      if ! command -v java >/dev/null 2>&1; then
        echo "Java is not installed; either Java or Docker must be installed"
        exit 1
      fi

      if ! echo get -b com.vordel.rtm:type=Metrics AllMetricGroupTotals \
           | java -jar "${DIR}/jmxterm-1.0.0-uber.jar" \
             -l "service:jmx:rmi:///jndi/rmi://${SERVER_AND_PORT}/jmxrmi" -u "${USERNAME}" -p "${PASSWORD}" -n -v silent > "$CACHE_FILE"; then
        # Failed, clean up cache so that subsequent calls do not just return empty data
        rm -f "$CACHE_FILE"
        touch "$CACHE_FILE.error"
        return 1
      fi
    fi
  fi
}

if [ "$4" == "system" ]; then
  # Usage 1
  SERVER_AND_PORT="$1"
  USERNAME="$2"
  PASSWORD="$3"
  COMMAND="$4"
  ARGUMENT="$5"
  CACHE_FILE='/tmp/oag-jmx-monitoring.cache.'$(echo "$SERVER_AND_PORT" | sed -e 's/[^a-zA-Z0-9\-]/_/g')

  if ! refresh_cache "$SERVER_AND_PORT" "$CACHE_FILE"; then
    echo "Failed to connect to $SERVER_AND_PORT"
    exit 1
  fi

elif [ "$#" -eq 5 -o "$#" -eq 7 ]; then
  # Usages 2 and 3
  SERVER1_AND_PORT="$1"
  SERVER2_AND_PORT="$2"
  USERNAME="$3"
  PASSWORD="$4"
  COMMAND="$5"
  ARGUMENT="$6"
  ARGUMENT2="$7"
  CACHE1_FILE='/tmp/oag-jmx-monitoring.cache.'$(echo "$SERVER1_AND_PORT" | sed -e 's/[^a-zA-Z0-9\-]/_/g')
  CACHE2_FILE='/tmp/oag-jmx-monitoring.cache.'$(echo "$SERVER2_AND_PORT" | sed -e 's/[^a-zA-Z0-9\-]/_/g')

  if ! refresh_cache "$SERVER1_AND_PORT" "$CACHE1_FILE" && ! refresh_cache "$SERVER2_AND_PORT" "$CACHE2_FILE"; then
    # Both servers fail (if one server is down we can still proceed)
    echo "Failed to connect to both servers $SERVER1_AND_PORT and $SERVER2_AND_PORT"
    exit 1
  fi

else
  echo "Invalid command-line arguments"
  exit 1
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
    LINE=$(sed -n -e '/groupName = System overview;/,/}, { / p' "$CACHE_FILE" | grep "$ARGUMENT =")
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
    SERVERS1=$(grep -B 15 'groupType = TargetServer;' "$CACHE1_FILE" 2>/dev/null \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/')
    SERVERS2=$(grep -B 15 'groupType = TargetServer;' "$CACHE2_FILE" 2>/dev/null \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/')

    # Merge the lists and get unique rows
    SERVERS=$(echo -e "${SERVERS1}\n${SERVERS2}" | sort | uniq)

    # Format lines to json
    echo "$SERVERS" | sed 's/\(.*\)/{"{#SERVER}":"\1"}/g' | sed '$!s/$/,/' | tr '\n' ' '
    echo -n ']}'
  ;;

  server)
    VALUE1=$(grep -B 2 -A 24 'groupName = '"${ARGUMENT}"';' "$CACHE1_FILE" 2>/dev/null | grep "$ARGUMENT2 =" | sed -e 's/.*= \(.*\);/\1/')
    VALUE2=$(grep -B 2 -A 24 'groupName = '"${ARGUMENT}"';' "$CACHE2_FILE" 2>/dev/null | grep "$ARGUMENT2 =" | sed -e 's/.*= \(.*\);/\1/')
    if [[ $ARGUMENT2 == respTimeRange* ]] || [[ $ARGUMENT2 == num* ]] || [[ $ARGUMENT2 == volume* ]] || [[ $ARGUMENT2 == uptime* ]] || [[ $ARGUMENT2 == respStat* ]]; then
      # Sum the values up
      VALUE=$((VALUE1+VALUE2))
    elif [ "$ARGUMENT2" == "respTimeMin" ]; then
      # Take the minimum of two values
      VALUE=$((VALUE1<VALUE2?VALUE1:VALUE2))
    elif [ "$ARGUMENT2" == "respTimeMax" ]; then
      # Take the maxmum of two values
      VALUE=$((VALUE1>VALUE2?VALUE1:VALUE2))
    elif [ "$ARGUMENT2" == "respTimeAvg" ]; then
      # Take the average of two values, in relation to the transaction count
      COUNT1=$(grep -B 2 -A 24 'groupName = '"${ARGUMENT}"';' "$CACHE1_FILE" 2>/dev/null | grep "numTransactions =" | sed -e 's/.*= \(.*\);/\1/')
      COUNT2=$(grep -B 2 -A 24 'groupName = '"${ARGUMENT}"';' "$CACHE2_FILE" 2>/dev/null | grep "numTransactions =" | sed -e 's/.*= \(.*\);/\1/')
      VALUE=$(((VALUE1*COUNT1+VALUE2*COUNT2)/(COUNT1+COUNT2)))
    else
      echo "Unsupported command argument $ARGUMENT2"
      exit 1
    fi

    if [ -z "$VALUE" ] && [ "$ARGUMENT2" == "numTransactions" ]; then
      # Server does not exist any more in JMX tree
      # Return number of transaction as 0 because 1) that's valid, no transactions 2) otherwise we cannot detect zero transactions in Zabbix
      echo "0"

    else
      echo "$VALUE"
    fi
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

    METHODS1=$(grep -A 4 'groupType = Method;' "$CACHE1_FILE" 2>/dev/null \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/')
    METHODS2=$(grep -A 4 'groupType = Method;' "$CACHE2_FILE" 2>/dev/null \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/')

    # Merge the lists and get unique rows
    METHODS=$(echo -e "${METHODS1}\n${METHODS2}" | sort | uniq)

    # Format lines to json
    echo "$METHODS" | sed 's/\(.*\)/{"{#METHOD}":"\1"}/g' | sed '$!s/$/,/' | tr '\n' ' '
    echo -n ']}'
  ;;

  method)
    VALUE1=$(grep -B 4 -A 7 'groupName = '"${ARGUMENT}"';' "$CACHE1_FILE" 2>/dev/null | grep "$ARGUMENT2 =" | sed -e 's/.*= \(.*\);/\1/')
    VALUE2=$(grep -B 4 -A 7 'groupName = '"${ARGUMENT}"';' "$CACHE2_FILE" 2>/dev/null | grep "$ARGUMENT2 =" | sed -e 's/.*= \(.*\);/\1/')
    if [ "$ARGUMENT2" == "exceptions" ] || [ "$ARGUMENT2" == "failures" ] || [ "$ARGUMENT2" == "numMessages" ] || [ "$ARGUMENT2" == "successes" ] || [ "$ARGUMENT2" == "uptime" ]; then
      # Sum the values up
      VALUE=$((VALUE1+VALUE2))
    elif [ "$ARGUMENT2" == "processingTimeMin" ]; then
      # Take the minimum of two values
      VALUE=$((VALUE1<VALUE2?VALUE1:VALUE2))
    elif [ "$ARGUMENT2" == "processingTimeMax" ]; then
      # Take the maxmum of two values
      VALUE=$((VALUE1>VALUE2?VALUE1:VALUE2))
    elif [ "$ARGUMENT2" == "processingTimeAvg" ]; then
      # Take the average of two values, in relation to the message count
      COUNT1=$(grep -B 4 -A 7 'groupName = '"${ARGUMENT}"';' "$CACHE1_FILE" 2>/dev/null | grep "numMessages =" | sed -e 's/.*= \(.*\);/\1/')
      COUNT2=$(grep -B 4 -A 7 'groupName = '"${ARGUMENT}"';' "$CACHE2_FILE" 2>/dev/null | grep "numMessages =" | sed -e 's/.*= \(.*\);/\1/')
      VALUE=$(((VALUE1*COUNT1+VALUE2*COUNT2)/(COUNT1+COUNT2)))
    else
      echo "Unsupported command argument $ARGUMENT2"
      exit 1
    fi

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

    SERVICES1=$(grep -A 4 'groupType = Service;' "$CACHE1_FILE" 2>/dev/null \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/')
    SERVICES2=$(grep -A 4 'groupType = Service;' "$CACHE2_FILE" 2>/dev/null \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/')

    # Merge the lists and get unique rows
    SERVICES=$(echo -e "${SERVICES1}\n${SERVICES2}" | sort | uniq)

    # Format lines to json
    echo "$SERVICES" | sed 's/\(.*\)/{"{#SERVICE}":"\1"}/g' | sed '$!s/$/,/' | tr '\n' ' '
    echo -n ']}'
  ;;

  service)
    VALUE1=$(grep -B 4 -A 6 'groupName = '"${ARGUMENT}"';' "$CACHE1_FILE" 2>/dev/null | grep "$ARGUMENT2 =" | sed -e 's/.*= \(.*\);/\1/')
    VALUE2=$(grep -B 4 -A 6 'groupName = '"${ARGUMENT}"';' "$CACHE2_FILE" 2>/dev/null | grep "$ARGUMENT2 =" | sed -e 's/.*= \(.*\);/\1/')
    if [ "$ARGUMENT2" == "exceptions" ] || [ "$ARGUMENT2" == "failures" ] || [ "$ARGUMENT2" == "numMessages" ] || [ "$ARGUMENT2" == "successes" ] || [ "$ARGUMENT2" == "uptime" ]; then
      # Sum the values up
      VALUE=$((VALUE1+VALUE2))
    elif [ "$ARGUMENT2" == "processingTimeMin" ]; then
      # Take the minimum of two values
      VALUE=$((VALUE1<VALUE2?VALUE1:VALUE2))
    elif [ "$ARGUMENT2" == "processingTimeMax" ]; then
      # Take the maxmum of two values
      VALUE=$((VALUE1>VALUE2?VALUE1:VALUE2))
    elif [ "$ARGUMENT2" == "processingTimeAvg" ]; then
      # Take the average of two values, in relation to the message count
      COUNT1=$(grep -B 4 -A 6 'groupName = '"${ARGUMENT}"';' "$CACHE1_FILE" 2>/dev/null | grep "numMessages =" | sed -e 's/.*= \(.*\);/\1/')
      COUNT2=$(grep -B 4 -A 6 'groupName = '"${ARGUMENT}"';' "$CACHE2_FILE" 2>/dev/null | grep "numMessages =" | sed -e 's/.*= \(.*\);/\1/')
      VALUE=$(((VALUE1*COUNT1+VALUE2*COUNT2)/(COUNT1+COUNT2)))
    else
      echo "Unsupported command argument $ARGUMENT2"
      exit 1
    fi

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

    CLIENTS1=$(grep -A 4 'groupType = Client;' "$CACHE1_FILE" 2>/dev/null \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/')
    CLIENTS2=$(grep -A 4 'groupType = Client;' "$CACHE2_FILE" 2>/dev/null \
      | grep 'groupName =' \
      | sed -e 's/.*= \(.*\);/\1/')

    # Merge the lists and get unique rows
    CLIENTS=$(echo -e "${CLIENTS1}\n${CLIENTS2}" | sort | uniq)

    # Format lines to json
    echo "$CLIENTS" | sed 's/\(.*\)/{"{#CLIENT}":"\1"}/g' | sed '$!s/$/,/' | tr '\n' ' '
    echo -n ']}'
  ;;

  client)
    VALUE1=$(grep -B 4 -A 3 'groupName = '"${ARGUMENT}"';' "$CACHE1_FILE" 2>/dev/null | grep "$ARGUMENT2 =" | sed -e 's/.*= \(.*\);/\1/')
    VALUE2=$(grep -B 4 -A 3 'groupName = '"${ARGUMENT}"';' "$CACHE2_FILE" 2>/dev/null | grep "$ARGUMENT2 =" | sed -e 's/.*= \(.*\);/\1/')
    if [ "$ARGUMENT2" == "exceptions" ] || [ "$ARGUMENT2" == "failures" ] || [ "$ARGUMENT2" == "numMessages" ] || [ "$ARGUMENT2" == "successes" ] || [ "$ARGUMENT2" == "uptime" ]; then
      # Sum the values up
      VALUE=$((VALUE1+VALUE2))
    else
      echo "Unsupported command argument $ARGUMENT2"
      exit 1
    fi

    echo "$VALUE"
  ;;

  *)
  echo "Undefined command $COMMAND"
  exit 1
  ;;

esac

