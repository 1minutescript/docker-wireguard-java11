FROM ghcr.io/linuxserver/baseimage-ubuntu:focal

# set version label
ARG BUILD_DATE
ARG VERSION
ARG WIREGUARD_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

ENV DEBIAN_FRONTEND="noninteractive"

RUN \
 echo "**** install dependencies ****" && \
 apt-get update && \
 apt-get install -y --no-install-recommends \
	bc \
	build-essential \
	curl \
	dkms \
	git \
	gnupg \ 
	ifupdown \
	iproute2 \
	iptables \
	iputils-ping \
	jq \
	libc6 \
	libelf-dev \
	net-tools \
	openresolv \
	perl \
	pkg-config \
	qrencode && \
 echo "**** install wireguard-tools ****" && \
 if [ -z ${WIREGUARD_RELEASE+x} ]; then \
	WIREGUARD_RELEASE=$(curl -sX GET "https://api.github.com/repos/WireGuard/wireguard-tools/tags" \
	| jq -r .[0].name); \
 fi && \
 cd /app && \
 git clone https://git.zx2c4.com/wireguard-linux-compat && \
 git clone https://git.zx2c4.com/wireguard-tools && \
 cd wireguard-tools && \
 git checkout "${WIREGUARD_RELEASE}" && \
 make -C src -j$(nproc) && \
 make -C src install && \
 echo "**** install CoreDNS ****" && \
 COREDNS_VERSION=$(curl -sX GET "https://api.github.com/repos/coredns/coredns/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]' | awk '{print substr($1,2); }') && \
 curl -o \
	/tmp/coredns.tar.gz -L \
	"https://github.com/coredns/coredns/releases/download/v${COREDNS_VERSION}/coredns_${COREDNS_VERSION}_linux_amd64.tgz" && \
 tar xf \
	/tmp/coredns.tar.gz -C \
	/app 

## Install Project dependencies

## INSTALL POSTGRESS CLIENT
## add postgresql-client to sources repos
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

## install wget
RUN apt-get install -y wget

## install signing package 
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

## update package 
RUN apt-get update

## install psql to test database access
RUN apt-get install -y postgresql-client

## Install java 11
RUN apt-get install -y openjdk-11-jdk

## Install Nodejs 16 & PM2 for monitoring App lunching
RUN curl -s https://deb.nodesource.com/setup_16.x | bash
RUN apt-get install nodejs -y
RUN npm install -g pm2
RUN pm2 startup

## Clean up install folders
RUN echo "**** clean up ****" && \
 rm -rf \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

# add local files
COPY /root /

# ports and volumes
EXPOSE 51820/udp
