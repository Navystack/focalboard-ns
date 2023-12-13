ARG NGINX_VERSION=1.25.3
ARG FINAL_VERSION=bookworm-slim
ARG TARGETOS
ARG TARGETARCH

FROM navystack/focalboard:nodebuild-cache as nodebuild
FROM navystack/focalboard:gobuild-cache AS gobuild
FROM navystack/ngx_mod:${NGINX_VERSION} as layershorter

RUN mkdir -p /opt/focalboard/data/files && \
    chown -R nobody:nogroup /opt/focalboard
COPY --from=nodebuild --chown=nobody:nogroup /webapp/pack /opt/focalboard/pack/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/bin/docker/focalboard-server /opt/focalboard/bin/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/LICENSE.txt /opt/focalboard/LICENSE.txt
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/docker/server_config.json /opt/focalboard/config.json

FROM debian:${FINAL_VERSION} as final
WORKDIR /opt/focalboard
COPY --from=layershorter --chown=nobody:nogroup /opt/focalboard/ /opt/focalboard
USER nobody
EXPOSE 8000/tcp 9092/tcp
VOLUME /opt/focalboard/data
CMD ["/opt/focalboard/bin/focalboard-server"]
