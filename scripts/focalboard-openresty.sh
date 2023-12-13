#!/bin/bash

"/usr/local/openresty/bin/openresty" "-g" "daemon off;" &

/opt/focalboard/bin/focalboard-server