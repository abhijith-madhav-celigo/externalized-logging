#! /bin/zsh
#export HOST=localhost
export HOST=0.0.0.0
export SPLUNK_TOKEN_CUSTOMER4="KIIPEtBPcGdyGCtLUl48qQ"
export DATADOG_TOKEN_CUSTOMER3="b9d315bb484e34e9015de652f8ab3346"
export FILE_STORAGE_LOCATION='/tmp/filestorage_error_logs'
export LOG_TOPIC='otlp_logs'
export ELASTIC_TOKEN_CUSTOMER1='TTs9Fq7SW8aFoUXEdg'
export ELASTIC_TOKEN_CUSTOMER2='1mkph6KZ9ths0a4CuR'
export ELASTIC_API_KEY_CUSTOMER2='Tm1YN3NaTUJLbmpGUWRRVy05TXY6OXBXSUtqRlVTUnFNYUxaZ3NkOUpZQQ=='
./otelcol-contrib --config ./config.yaml
