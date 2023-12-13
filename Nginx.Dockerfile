ARG NGINX_VERSION=1.25.3
ARG NODE_VERSION=18-bookworm

FROM navystack/focalboard:nodebuild-cache as nodebuild
FROM navystack/focalboard:gobuild-cache AS gobuild
FROM navystack/ngx_mod:${NGINX_VERSION} as layershorter-nginx-moduler

RUN mkdir -p /opt/focalboard/data/files && \
    chown -R nobody:nogroup /opt/focalboard
COPY --from=nodebuild --chown=nobody:nogroup /webapp/pack /opt/focalboard/pack/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/bin/docker/focalboard-server /opt/focalboard/bin/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/LICENSE.txt /opt/focalboard/LICENSE.txt
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/docker/server_config.json /opt/focalboard/config.json

FROM nginx:${NGINX_VERSION} as final

WORKDIR /opt/focalboard
COPY --from=layershorter-nginx-moduler --chown=nobody:nogroup /opt/focalboard/ /opt/focalboard
COPY --from=layershorter-nginx-moduler /usr/lib/nginx/modules/*.so /usr/lib/nginx/modules/
EXPOSE 80/tcp 9092/tcp
VOLUME /opt/focalboard/data

RUN mkdir -p /var/run/ngx_pagespeed_cache && \
    mkdir -p /var/run/nginx-cache && \
    chown www-data:www-data /var/run/ngx_pagespeed_cache && \
    chown www-data:www-data /var/run/nginx-cache && \
    echo "load_module modules/ngx_pagespeed.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf && \
    echo "load_module modules/ngx_http_immutable_module.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf && \
    echo "load_module modules/ngx_http_cache_purge_module.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf && \
    echo "load_module modules/ngx_http_brotli_static_module.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf && \
    echo "load_module modules/ngx_http_brotli_filter_module.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf && \
    rm -rf /etc/nginx/conf.d/default.conf && \
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
    pagespeed FileCachePath /var/run/ngx_pagespeed_cache;
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
        proxy_buffer_size 16k;
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

ADD scripts/focalboard-nginx.sh /

CMD ["/focalboard-nginx.sh"]