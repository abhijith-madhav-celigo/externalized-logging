# POC for external logging

The main purpose of the POC is to check on the routing and fault-tolerance features of the opentelemetry collector. 

Refer to this [Spike](https://docs.google.com/document/d/1xND_8py0--4EfZcyAhuQgTTps3hT18IAOrem7HlKM74/edit?usp=sharing) for more details

In the scalability section of the Spike, there is mention of routing to multiple instances of collectors and the need for some external solutions for the same.

But since we are going to be starting small(maybe a few 10's of customers), the focus of this POC is just the functioning and routing within a single collector instance. It is assumed that pipelines for new customers will be added manually via Terraform.

## Quick summary of the findings
- The [routing](#routing) works as expected
  - Routing can be done based on customer id to different customer LMS's
  - Routing can be done to two different instances/accounts of the same LMS for two different customers
  - Logs from the same customer can be pushed to multiple LMS. This was a [new requirement](https://celigo.atlassian.net/browse/IO-102359?focusedCommentId=547947) from product. 
- [Customizations](#log-message-format) might be needed to the format of the error messages and the way they are produced per backend vendor. This is so that they can be easily analysed in customer LMS's.
- Support for fault-tolerance is [mixed](#fault-tolerance). Among the two LMS's tries(Elastic and datadog) one of them(datadog) did not have support
- [Pipelines]() for different customers across multiple vendor LMS are configured in the same OTEL Collector for this POC. In production we will be better served using separate collectors from vendor supported distributions per LMS platform. To clarify
  - An OTEL collector instance from the elastic distribution can host pipelines for customers with Elastic backend
  - An OTEL collector instance from the splunk distrivution can host pipelines for customers with a Splucnk backend
  - And so on

This is because vendor supported distributions are better support and receive updates at a greater velocity than an OTEL maintained distribution

## Details
All the configuration talked below can be seen as a whole in [config.yaml](config.yaml)

# Routing
The OTEL collecor(otelcol) has been configured to route logs based on customer id.
Currently 3 customers have been configured
1. Customer 1 : Elastic backend
2. Customer 2 : Elastic backend
3. Customer 3 : Datadog backend

Errors are pushed into the kafka topic using a [node script](produce_logs_kafka.js).

The logs is consumed from by the `kafkareceiver` configured in the otelcol. The customer id is set in the kafka header of the message. 

The otelcol configuration takes care of extracting this and making this available for the `routing` processor.

```
receivers
  kafka:
    ...
    ...
    ...
    header_extraction:
      extract_headers: true
      headers: ["customer-id"]
```

The `routing` processor then uses this for routing logs to different backends

```
processors:
  ...
  routing:
    from_attribute: kafka.header.customer-id
    attribute_source: resource
    table:
    - value: customer-1
      exporters: otlp/elastic/customer-1
    - value: customer-2
      exporters: otlp/elastic/customer-2
    - value: customer-3
      exporters: datadog/customer-3
    - value: customer-4
      exporters: otlphttp/splunk/customer-4
```
### Synching of logs of a customer to multiple LMS's
This was not tried out explicitly. But it is clear from the routing configuration that this can be done. 

## Log message format
Wrapping our error message with the OTLP format for log message is supposed to help add important metadata(service name, log level, severity) which can then be interpreted by OTEL compliant LMS.

Refer to [this](error_otlp_json.json) for an illustration.

The POC pushes integration error messages in this format via the `kafkareceiver`. 

Datadog interprets this well.

![datadog_log.png](datadog_log.png)

Elastic unfortunately interprets this as a plain json.

![elastic_log.png](elastic_log.png)

Things work well if the same message is pushed via an `otlp receiver` instead.
![elastic_log_oltp_receiver.png](elastic_log_otlp_receiver.png)

**Takeaway : Customizations might be needed to the way error messages are produced per backend vendor**

## Handling Data loss

### Retries
If the customer LMS are unreachable `exporters` can be configured with retries so that data loss can be quantified. This is enabled by default and hence can't be seen in [config.yaml](config.yaml)

```
retry_on_failure:
  enabled : true
initial_interval: 5 555
max_interval: 30
max_elapsed_time: 300
```

**Retries were tested by killing the wifi and then bringing it on, simulating an LMS not being available.**

### Fault tolerance
Once the error messages from kafka are read by the otelcol, they are processed in-memory before being pushed of the LMS's. 
In case the collector crashes at this point in time, the error messages will be lost. 

To prevent this a `filestorage` extension can be configured to each exporter. This acts as a persistent queue. Messages read from kafka are storage on disk. If a collector crashes there is no message loss

```
extensions:
  file_storage/error_logs:
    directory: ${FILE_STORAGE_LOCATION}
    create_directory: true

exporters:
otlp/elastic/customer-1:
  ...
  sending_queue:
    storage: file_storage/error_logs

otlp/elastic/customer-2:
  ...
  sending_queue:
    storage: file_storage/error_logs

datadog/customer-1:
  ...
  sending_queue:
    storage: file_storage/error_logs
```



Testing for fault-tolerance was as follows
1. Kill the wifi to simulate the scenario of logs being read from kafka into the collector.
2. Now kill the collector
3. Switch on the wifi and bring back the collector

**Logs for Elastic were not lost. However logs for Datadog were lost. The datadog exporter does not yet support the persistance mechanism and silently ignores the configuration**

## Setup
1. Bring up [confluent kafka containers](https://github.com/conduktor/kafka-stack-docker-compose/) and create a topic to input logs
```
% docker compose -f kafka-stack-docker-compose/full-stack.yml up -d

% curl -X POST http://localhost:8082/v3/clusters/{cluster_id}/topics \
  -H "Content-Type: application/json" \
  -d '{
    "topic_name": "otlp_logs"
  }'
```

2. Construct [config.yaml](config.yaml)

3. Install and run the contrib distribution of the OTEL collector
```

% curl --proto '=https' --tlsv1.2 -f https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.114.0/otelcol-contrib_0.114.0_darwin_amd64.tar.gz

% tar -xvf otelcol-contrib_0.114.0_darwin_amd64.tar.gz

% ./otelcol-contrib --config ./config.yaml
```

4. Logs can be produced to the kafka topic
```
 % node produce_logs_kafka.js customer-2
 ```
 5. Logs can also be pushed via the OLTP listener configured for debug purposes

 ```
 % CUSTOMER=customer-2 produce_logs_otlp.sh
 ```
 6. Customer-ids configured so far are customer-1, customer-2, customer-3. Any other customers used will result in logs being outputed on the collector terminal




## References 
1. Installation and setup of otelcol : https://opentelemetry.io/docs/collector/installation/#macos
2. Elastic APM: 
   1. Connection configuration : https://www.elastic.co/guide/en/observability/current/apm-open-telemetry-direct.html
   2. View logs
      - https://6a51c5545a4d4e30ad06b1964589eb68.us-central1.gcp.cloud.es.io/app/apm
      - https://e785dbf08382400793e5c8b304600e13.us-central1.gcp.cloud.es.io/app/apm
3. Datadog
   1. Configuration : https://docs.datadoghq.com/opentelemetry/collector_exporter/configuration/
   2. Logs : https://us5.datadoghq.com/logs
4. Splunk : https://docs.splunk.com/observability/en/gdi/opentelemetry/components/otlphttp-exporter.html#otlphttp-exporter


