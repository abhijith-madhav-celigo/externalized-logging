#! /bin/zsh

CUSTOMER=${CUSTOMER:-customer-99999}
~/go/bin/telemetrygen logs \
	--otlp-insecure \
	--severity-text ERROR \
	--body "{\n    \"occurredAt\": \"2024-10-28T10:21:01.749Z\",\n    \"source\": \"connection\",\n    \"code\": \"FTP_AUTH_FAILED\",\n    \"message\": \"[Could not connect to SFTP server at \\\"sftp://geethika.mallampalli@celigo.com:***@celigo.files.com/\\\".] [Could not connect to SFTP server at \\\"celigo.files.com\\\".] [Auth fail]\",\n    \"traceKey\": \"\",\n    \"exportDataURI\": \"\",\n    \"importDataURI\": \"\",\n    \"oIndex\": 0,\n    \"retryDataKey\": \"\",\n    \"errorId\": 24882314808,\n    \"legacyId\": \"\",\n    \"_flowJobId\": \"671f658917529217648f40af\",\n    \"classification\": \"\",\n    \"classifiedBy\": \"\",\n    \"retryAt\": \"\",\n    \"reqAndResKey\": \"\",\n    \"purgeAt\": 1732702861749,\n    \"tags\": \"\",\n    \"assignedTo\": \"\",\n    \"assignedBy\": \"\"\n}" \
	--otlp-attributes kafka.header.customer-id=\"$CUSTOMER\" \
	--otlp-attributes host.name=\"localhost\" \
	--otlp-attributes service.name=\"integrator.io\"


echo "Logging from $CUSTOMER"
