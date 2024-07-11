#!/bin/bash

# Required environment variables
required_vars=(
  "DB_TYPE"
  "MYSQL_USER"
  "MYSQL_PASSWORD"
  "MYSQL_HOST"
  "MYSQL_PORT"
  "MYSQL_DATABASE"
)

# Check if any required environment variables are missing
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Required environment variable $var is not set. Exiting..."
    exit 1
  fi
done

# Backup the original configuration file
mv /go/src/focalboard/docker/conf.json /go/src/focalboard/docker/conf.json.backup

# Create the new configuration file with the required environment variables
printf '%s\n' "{
    \"serverRoot\": \"http://localhost:8000\",
    \"port\": 8000,
    \"dbtype\": \"$DB_TYPE\",
    \"dbconfig\": \"$MYSQL_USER:$MYSQL_PASSWORD@tcp($MYSQL_HOST:$MYSQL_PORT)/$MYSQL_DATABASE\",
    \"useSSL\": false,
    \"webpath\": \"./pack\",
    \"filespath\": \"./data/files\",
    \"telemetry\": true,
    \"prometheusaddress\": \":9092\",
    \"session_expire_time\": 2592000,
    \"session_refresh_time\": 18000,
    \"localOnly\": false,
    \"enableLocalMode\": true,
    \"localModeSocketLocation\": \"/var/tmp/focalboard_local.socket\",
    \"enablePublicSharedBoards\": true
}" > /opt/focalboard/config.json

chown -R nobody:nogroup /opt/focalboard

# Execute the provided command
exec "$@"
