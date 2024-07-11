ARG NGINX_VERSION=1.25.3
ARG FINAL_VERSION=bookworm-slim
ARG TARGETOS
ARG TARGETARCH

FROM node:lts as base
WORKDIR /focalboard
RUN git clone https://github.com/AskFront/focalboard-af.git .

FROM base AS nodebuild
WORKDIR /focalboard/webapp
RUN CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm install --no-optional && \
    npm run pack

FROM golang:bookworm AS gobuild
COPY --from=base /focalboard /go/src/focalboard
WORKDIR /go/src/focalboard
RUN EXCLUDE_PLUGIN=true EXCLUDE_SERVER=true EXCLUDE_ENTERPRISE=true make server-docker os=${TARGETOS} arch=${TARGETARCH}

FROM navystack/ngx_mod:${NGINX_VERSION} AS layershorter

RUN mkdir -p /opt/focalboard/data/files && \
    chown -R nobody:nogroup /opt/focalboard
COPY --from=nodebuild --chown=nobody:nogroup /focalboard/webapp/pack /opt/focalboard/pack/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/bin/docker/focalboard-server /opt/focalboard/bin/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/LICENSE.txt /opt/focalboard/LICENSE.txt
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/docker/server_config.json /opt/focalboard/config.json

FROM debian:${FINAL_VERSION} AS final
WORKDIR /opt/focalboard
COPY --from=layershorter --chown=nobody:nogroup /opt/focalboard/ /opt/focalboard
USER nobody
EXPOSE 8000/tcp 9092/tcp
VOLUME /opt/focalboard/data
CMD ["/opt/focalboard/bin/focalboard-server"]