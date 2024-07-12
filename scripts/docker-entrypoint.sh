#!/bin/bash

set -e

# Check and set UID and GID if provided
if [ "$(id -u)" = '0' ]; then
  # Handle UID and GID if provided
  if [ -z "$UID" ] || [ -z "$GID" ]; then
      printf "Using Default UID:GID (1001:1001)\n"
  else
      echo "Using provided UID = $UID / GID = $GID"
      usermod -u "$UID" focalboard
      groupmod -g "$GID" focalboard
  fi

  # Check if configuration file exists, else create it
  if [ ! -f "/opt/focalboard/config.json" ]; then
      if [ -z "$DB_CONFIG_STRING" ]; then
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
              *)
                  printf "Error: Unsupported DB_TYPE: %s. Supported types are mysql, postgres(pgsql), sqlite3.\n" "$DB_TYPE"
                  printf "Set variables properly or mount config.json file directly.\n"
                  exit 1
                  ;;
          esac

          # Check required environment variables
          for var in "${required_vars[@]}"; do
              if [ -z "${!var}" ]; then
                  printf "Error: Required environment variable %s for %s is not set.\n" "$var" "$DB_TYPE"
                  printf "Set variables properly or mount config.json file directly.\n"
                  exit 1
              fi
          done

          # Generate DB_CONFIG based on DB_TYPE
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
      else
          DB_CONFIG="$DB_CONFIG_STRING"
          DB_TYPE="$DB_TYPE"
      fi

      # Generate config.json file
      printf '%s\n' '{
      "serverRoot": "http://localhost:8000",
      "port": 8000,
      "dbtype": "'"$DB_TYPE"'",
      "dbconfig": "'"$DB_CONFIG"'",
      "useSSL": false,
      "webpath": "./pack",
      "filespath": "./data/files",
      "telemetry": true,
      "prometheusaddress": ":9092",
      "session_expire_time": 2592000,
      "session_refresh_time": 18000,
      "localOnly": false,
      "enableLocalMode": true,
      "localModeSocketLocation": "/var/tmp/focalboard_local.socket",
      "enablePublicSharedBoards": true
  }' > /opt/focalboard/config.json

      printf "Configuration file created: /opt/focalboard/config.json\n"
  else
      printf "Configuration file already exists. Skipping file creation.\n"
  fi

  # Change ownership of /opt/focalboard directory
  chown -R focalboard:focalboard /opt/focalboard/

  # Execute the script as focalboard user
  exec gosu focalboard "$@"
fi
