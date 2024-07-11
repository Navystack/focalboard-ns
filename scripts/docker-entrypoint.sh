#!/bin/bash

set -e

# Check if DB_TYPE is not defined but /opt/focalboard/config.json file exists
if [ -z "$DB_TYPE" ] && [ -f "/opt/focalboard/config.json" ]; then
  # Execute the provided command
  exec "$@"
fi

# Check if DB_TYPE is defined
if [ -z "$DB_TYPE" ]; then
  echo "Error: DB_TYPE is not defined. Please set DB_TYPE environment variable."
  exit 1
fi

# Validate DB_TYPE
case "$DB_TYPE" in
  mysql|pgsql|postgres|sqlite3)
    ;;
  *)
    echo "Error: Unsupported DB_TYPE: $DB_TYPE. Supported types are mysql, pgsql, postgres, sqlite3."
    exit 1
    ;;
esac

# Check required environment variables based on DB_TYPE
case "$DB_TYPE" in
  mysql)
    required_vars=("MYSQL_USER" "MYSQL_PASSWORD" "MYSQL_HOST" "MYSQL_PORT" "MYSQL_DATABASE")
    ;;
  pgsql|postgres)
    required_vars=("PGSQL_USER" "PGSQL_PASSWORD" "PGSQL_HOST" "PGSQL_DATABASE")
    ;;
  sqlite3)
    required_vars=("SQLITE_DB_PATH")
    ;;
esac

# Check for missing required environment variables
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Error: Required environment variable $var is not set for $DB_TYPE."
    exit 1
  fi
done

# Determine dbconfig based on DB_TYPE and prioritize DB_CONFIG_STRING if defined
if [ -n "$DB_CONFIG_STRING" ]; then
  DB_CONFIG="$DB_CONFIG_STRING"
else
  case "$DB_TYPE" in
    mysql)
      DB_CONFIG="$MYSQL_USER:$MYSQL_PASSWORD@tcp($MYSQL_HOST:$MYSQL_PORT)/$MYSQL_DATABASE"
      ;;
    pgsql|postgres)
      DB_CONFIG="postgres://$PGSQL_USER:$PGSQL_PASSWORD@$PGSQL_HOST/$PGSQL_DATABASE?sslmode=disable&connect_timeout=10"
      ;;
    sqlite3)
      DB_CONFIG="$SQLITE_DB_PATH?_busy_timeout=5000"
      ;;
  esac
fi

# Backup the original configuration file
mv /opt/focalboard/config.json /opt/focalboard/config.json.backup

# Create the new configuration file with the required environment variables
printf '%s\n' "{
    \"serverRoot\": \"http://localhost:8000\",
    \"port\": 8000,
    \"dbtype\": \"$DB_TYPE\",
    \"dbconfig\": \"$DB_CONFIG\",
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

# Execute the provided command
exec "$@"
