# oag-monitoring
Monitor Oracle API Gateway metrics via JMX

Tested with OAG 11g Release 2.

## Installation for Zabbix

The repository includes ready-to-install files for Zabbix Agent. The files are installed in the server having Zabbix Agent.

* Copy the files under [etc/zabbix/scripts](etc/zabbix/scripts) to `/etc/zabbix/scripts`
* Copy the files under [etc/zabbix/zabbix_agentd.d](etc/zabbix/zabbix_agentd.d) to `/etc/zabbix/zabbix_agentd.d`

## Zabbix Items Supported

Item Syntax | Description | Example Item Key | Example Item Value
----------- | ----------- | ---------------- | ------------------
oag.system[SERVER:PORT, USERNAME, PASSWORD, METRICS] | Get system metrics. METRICS must be one of cpuUsed, systemMemoryUsed, cpuUsedMax, memoryUsedMin, cpuUsedAvg, diskUsedPercent, exceptions, numMessagesProcessed, messageMonitoringEnabled, systemCpuAvg, metricsLoggingEnabled, processSignature, failures, successes, serverTitle, uptime, numSLABreaches, serverHost, cpuUsedMin, memoryUsedMax, numAlerts, monitoringEnabled, systemCpuMin, serverGroup, systemCpuMax, systemMemoryTotal, memoryUsedAvg | oag.system[172.17.0.100:7199, user, password, numMessagesProcessed] | 12441241
oag.server.discovery[SERVER:PORT, USERNAME, PASSWORD] | Target server aka remote host low-level discovery | oag.server.discovery[172.17.0.100:7199, user, password] | {"data":[{"{#SERVER}":"server1:80"}, {"{#SERVER}":"server2:88"} ]}
oag.server[SERVER:PORT, USERNAME, PASSWORD, SERVER, METRIC] | Get server metrics. METRICS must be one of numReportedUps, volumeBytesOut, respTimeMax, respTimeMin, volumeBytesIn, numTransactions,  respTimeAvg, numReportedDowns, uptime | oag.server[172.17.0.100:7199, user, password, server1:80, numTransactions] | 149905
oag.method.discovery[SERVER:PORT, USERNAME, PASSWORD] | Method low-level discovery | oag.method.discovery[172.17.0.100:7199, user, password] | {"data":[{"{#METHOD}":"mymethod"} ]}
oag.method[SERVER:PORT, USERNAME, PASSWORD, METHOD, METRIC] | Get method metrics. METRICS must be one of exceptions, failures, numMessages, processingTimeMin, successes, processingTimeMax, uptime, processingTimeAvg | oag.method[172.17.0.100:7199, user, password, mymethod, numMessages] | 39
oag.service.discovery[SERVER:PORT, USERNAME, PASSWORD] | Service low-level discovery | oag.service.discovery[172.17.0.100:7199, user, password] | {"data":[{"{#SERVICE}":"myservice"} ]}
oag.service[SERVER:PORT, USERNAME, PASSWORD, METHOD, METRIC] | Get service metrics. METRICS must be one of exceptions, failures, numMessages, processingTimeMin, successes, processingTimeMax, uptime, processingTimeAvg | oag.service[172.17.0.100:7199, user, password, myservice, processingTimeAvg] | 488
oag.client.discovery[SERVER:PORT, USERNAME, PASSWORD] | Client low-level discovery | oag.client.discovery[172.17.0.100:7199, user, password] | {"data":[{"{#CLIENT}":"myclient"} ]}
oag.client[SERVER:PORT, USERNAME, PASSWORD, METHOD, METRIC] | Get client metrics. METRICS must be one of exceptions, failures, numMessages, successes, uptime | oag.client[172.17.0.100:7199, user, password, client, uptime] | 520975

