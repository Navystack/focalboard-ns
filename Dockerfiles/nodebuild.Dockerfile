ARG NGINX_VERSION=1.25.3
ARG NODE_VERSION=18-bookworm
ARG GO_VERSION=1.21.3-bookworm
ARG FINAL_VERSION=bookworm-slim

FROM node:${NODE_VERSION} as nodebuild

RUN git clone --depth=1 https://github.com/navystack/focalboard.git && \
    cp --recursive /focalboard/webapp/ /webapp 
WORKDIR /webapp

RUN CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm install --no-optional && \
    npm run pack