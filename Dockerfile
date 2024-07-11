# Base 이미지 설정
FROM node:lts AS base
ARG TARGETOS
ARG TARGETARCH
WORKDIR /focalboard
RUN git clone https://github.com/AskFront/focalboard-af.git .

# Node.js 빌드 단계
FROM base AS nodebuild
WORKDIR /focalboard/webapp
RUN CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm install --no-optional && \
    npm run pack

# Go 빌드 단계
FROM golang:bookworm AS gobuild
ARG TARGETOS
ARG TARGETARCH
COPY --from=base /focalboard /go/src/focalboard
WORKDIR /go/src/focalboard
RUN EXCLUDE_PLUGIN=true EXCLUDE_SERVER=true EXCLUDE_ENTERPRISE=true make server-docker os=${TARGETOS} arch=${TARGETARCH}

# 최적화 및 단축 단계
FROM node:lts AS layershorter
RUN mkdir -p /opt/focalboard/data/files && \
    chown -R nobody:nogroup /opt/focalboard
COPY --from=nodebuild --chown=nobody:nogroup /focalboard/webapp/pack /opt/focalboard/pack/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/bin/docker/focalboard-server /opt/focalboard/bin/
COPY --from=gobuild --chown=nobody:nogroup /go/src/focalboard/LICENSE.txt /opt/focalboard/LICENSE.txt

RUN apt-get update && \
    apt-get install -y --no-install-recommends tini && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 최종 이미지 설정
FROM debian:bookworm-slim AS final
ENV GOSU_VERSION="1.17"

RUN set -eux; \
    groupadd --gid 1001 focalboard; \
    useradd --uid 1001 --gid 1001 --home-dir /opt/focalboard focalboard; \
    install -d -o focalboard -g focalboard -m 700 /opt/focalboard

RUN set -eux; \
    # save list of currently installed packages for later so we can clean up
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates gnupg wget; \
    rm -rf /var/lib/apt/lists/*; \
    \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    \
    # verify the signature
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
    \
    # clean up fetch dependencies
    apt-mark auto '.*' > /dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    \
    chmod +x /usr/local/bin/gosu; \
    # verify that the binary works
    gosu --version; \
    gosu nobody true

WORKDIR /opt/focalboard

COPY --from=layershorter /usr/bin/tini /usr/bin/tini
COPY --from=layershorter --chown=focalboard:focalboard /opt/focalboard/ /opt/focalboard

EXPOSE 8000/tcp
VOLUME /opt/focalboard/data
COPY scripts/docker-entrypoint.sh /

ENTRYPOINT [ "tini", "--", "/docker-entrypoint.sh" ]

CMD [ "/opt/focalboard/bin/focalboard-server" ]
