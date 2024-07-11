#!/bin/bash

# Start nginx in the background
nginx -g "daemon off;" &

# Start the Focalboard server
exec /opt/focalboard/bin/focalboard-server
