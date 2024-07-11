FROM node:lts as base
ARG TARGETOS
ARG TARGETARCH

WORKDIR /focalboard
RUN git clone https://github.com/AskFront/focalboard-af.git .

FROM base AS nodebuild
WORKDIR /focalboard/webapp
RUN CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm install --no-optional && \
    npm run pack

FROM golang:bookworm AS gobuild
ARG TARGETOS
ARG TARGETARCH
COPY --from=base /focalboard /go/src/focalboard
WORKDIR /go/src/focalboard
RUN EXCLUDE_PLUGIN=true EXCLUDE_SERVER=true EXCLUDE_ENTERPRISE=true make server-docker os=${TARGETOS} arch=${TARGETARCH}

FROM navystack/openresty:1.25.3 AS layershorter

RUN mkdir -p /opt/focalboard/data/files && \
    chown -R nobody:nogroup /opt/focalboard
COPY --from=nodebuild --chown=nobody:nogroup /focalboard/webapp/pack /opt/focalboard/pack/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/bin/docker/focalboard-server /opt/focalboard/bin/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/LICENSE.txt /opt/focalboard/LICENSE.txt
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/docker/server_config.json /opt/focalboard/config.json
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tini \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM navystack/openresty:1.25.3 AS final

WORKDIR /opt/focalboard
COPY --from=layershorter /usr/bin/tini /usr/bin/tini
COPY --from=layershorter --chown=nobody:nogroup /opt/focalboard/ /opt/focalboard
COPY --from=layershorter /usr/local/openresty/nginx/modules /usr/local/openresty/nginx/modules
COPY --from=layershorter /usr/local/openresty/nginx/conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80/tcp 9092/tcp
VOLUME /opt/focalboard/data

ADD scripts/focalboard-openresty.sh /
CMD ["/focalboard-openresty.sh"]
