#!/bin/sh

if [ -z "$DB_TYPE" ] || [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_PORT" ] || [ -z "$MYSQL_DATABASE" ]; then
  echo "One or more required environment variables are not set. Exiting..."
  exit 1
fi

mv /go/src/focalboard/docker/conf.json /go/src/focalboard/docker/conf.json.backup
cat <<"EOF" > /go/src/focalboard/docker/conf.json
{
    "serverRoot": "http://localhost:8000",
    "port": 8000,
    "dbtype": "$DB_TYPE",
    "dbconfig": "$MYSQL_USER:$MYSQL_PASSWORD@tcp($MYSQL_HOST:$MYSQL_PORT)/$MYSQL_DATABASE",
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
}
EOF

exec "$@"
