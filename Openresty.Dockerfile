ARG OPENRESTY_VERSION=openresty-1.21.4.3
ARG OPENRESTY_DOCKER_VERSION=1.21.4.3-jammy
ARG TARGETOS
ARG TARGETARCH

FROM node:lts as base
WORKDIR /focalboard
RUN git clone https://github.com/NavyStack/focalboard.git .

FROM base AS nodebuild
WORKDIR /focalboard/webapp
RUN CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm install --no-optional && \
    npm run pack

FROM golang:bookworm AS gobuild
COPY --from=base /focalboard /go/src/focalboard
WORKDIR /go/src/focalboard
RUN EXCLUDE_PLUGIN=true EXCLUDE_SERVER=true EXCLUDE_ENTERPRISE=true make server-docker os=${TARGETOS} arch=${TARGETARCH}

FROM navystack/ngx_mod:${OPENRESTY_VERSION} AS layershorter

RUN mkdir -p /opt/focalboard/data/files && \
    chown -R nobody:nogroup /opt/focalboard
COPY --from=nodebuild --chown=nobody:nogroup /focalboard/webapp/pack /opt/focalboard/pack/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/bin/docker/focalboard-server /opt/focalboard/bin/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/LICENSE.txt /opt/focalboard/LICENSE.txt
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/docker/server_config.json /opt/focalboard/config.json

FROM openresty/openresty:${OPENRESTY_DOCKER_VERSION} AS final

WORKDIR /opt/focalboard
COPY --from=layershorter --chown=nobody:nogroup /opt/focalboard/ /opt/focalboard
COPY --from=layershorter /usr/local/openresty/nginx/modules /usr/local/openresty/nginx/modules
COPY --from=layershorter /usr/local/openresty/nginx/conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
EXPOSE 80/tcp 9092/tcp
VOLUME /opt/focalboard/data

RUN rm -rf /etc/nginx/conf.d/default.conf && \
    cat <<"EOF" > /etc/nginx/conf.d/default.conf
########################
# Virtual Host Configs #
########################
upstream focalboard {
    server localhost:8000;
    keepalive 2;
}

server {
    listen 80;
    server_name _;

    pagespeed standby;
    pagespeed FileCachePath /var/run/openresty/ngx_pagespeed_cache;
    pagespeed XHeaderValue "";

    #################
    # Gzip Settings #
    #################
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 1;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 1024;
    gzip_types
    text/plain
    text/css
    text/js
    text/xml
    text/javascript
    application/javascript
    application/x-javascript
    application/json
    application/xml
    application/xml+rss
    image/svg+xml;

    ###################
    # Brotli Settings #
    ###################

    brotli on;
    brotli_comp_level 6;
    brotli_static on;
    brotli_min_length 1024;
    brotli_types
    text/plain
    text/css
    text/js
    text/xml
    text/javascript
    application/javascript
    application/x-javascript
    application/json
    application/xml
    application/xml+rss
    image/svg+xml;

    #################
    # Block crawler #
    #################

    location = /robots.txt {
        return 200 "User-agent: *\nDisallow: /\n";
    }

    location ~ /ws/* {
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        client_max_body_size 500M;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_buffers 256 16k;
        proxy_buffer_size 128k;
        client_body_timeout 60;
        send_timeout 300;
        lingering_timeout 5;
        proxy_connect_timeout 7200;
        proxy_send_timeout 7200;
        proxy_read_timeout 7200;
        proxy_pass http://focalboard;
    }

    location / {
        client_max_body_size 500M;
        proxy_set_header Connection $http_upgrade;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_buffers 256 16k;
        proxy_buffer_size 128k;
        proxy_read_timeout 7200;
        proxy_cache_revalidate on;
        proxy_cache_min_uses 2;
        proxy_cache_use_stale timeout;
        proxy_cache_lock on;
        proxy_http_version 1.1;
        proxy_pass http://focalboard;
    }
}
EOF

ADD scripts/focalboard-openresty.sh /
CMD ["/focalboard-openresty.sh"]