#!/bin/bash

# Start OpenResty in the background
/usr/local/openresty/bin/openresty -g "daemon off;" &

# Start the Focalboard server
exec /opt/focalboard/bin/focalboard-server
