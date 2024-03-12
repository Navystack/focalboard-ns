FROM node:lts as base
ARG TARGETOS
ARG TARGETARCH

WORKDIR /focalboard
RUN git clone https://github.com/NavyStack/focalboard.git .

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

FROM navystack/ngx_mod:1.25.3 AS layershorter

RUN mkdir -p /opt/focalboard/data/files && \
    chown -R nobody:nogroup /opt/focalboard
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tini \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=nodebuild --chown=nobody:nogroup /focalboard/webapp/pack /opt/focalboard/pack/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/bin/docker/focalboard-server /opt/focalboard/bin/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/LICENSE.txt /opt/focalboard/LICENSE.txt
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/docker/server_config.json /opt/focalboard/config.json

FROM debian:bookworm-slim AS final

WORKDIR /opt/focalboard
COPY --from=layershorter --chown=nobody:nogroup /opt/focalboard/ /opt/focalboard
COPY --from=layershorter /usr/bin/tini /usr/bin/tini
# COPY --from=hairyhenderson/gomplate:stable /gomplate /usr/local/bin/gomplate

USER nobody
EXPOSE 8000/tcp 9092/tcp
VOLUME /opt/focalboard/data

ENTRYPOINT ["tini", "--"]

CMD ["/opt/focalboard/bin/focalboard-server"]