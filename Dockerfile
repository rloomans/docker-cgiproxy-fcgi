FROM  debian:trixie-slim AS base
LABEL maintainer="Robert Loomans <robert@loomans.org>"
LABEL url="https://github.com/rloomans/docker-cgiproxy-fcgi"
LABEL source="https://github.com/rloomans/docker-cgiproxy-fcgi.git"
LABEL org.opencontainers.image.authors="Robert Loomans <robert@loomans.org>"
LABEL org.opencontainers.image.source="https://github.com/rloomans/docker-cgiproxy-fcgi.git"

ARG APT_HTTP_PROXY

RUN \
        export DEBIAN_FRONTEND=noninteractive && \
        if [ -n "$APT_HTTP_PROXY" ]; then \
            printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
        fi && \
        apt-get update && \
        apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
        apt-get install -y --no-install-recommends \
          curl \
          ca-certificates && \
        apt-get clean && \
        rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/apt/apt.conf.d/apt-proxy.conf

RUN \
        export DEBIAN_FRONTEND=noninteractive && \
        if [ -n "$APT_HTTP_PROXY" ]; then \
            printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
        fi && \
        apt-get update && \
        apt-get install -y --no-install-recommends \
            cron \
            libcompress-raw-lzma-perl \
            libconfig-yaml-perl \
            libcpan-meta-perl \
            libcrypt-ssleay-perl \
            libdbd-sqlite3 \
            libdbd-sqlite3-perl \
            libfcgi-perl \
            libfcgi-procmanager-perl \
            libio-compress-lzma-perl \
            libjavascript-minifier-xs-perl \
            libjson-perl \
            libjson-pp-perl \
            libjson-xs-perl \
            liblocal-lib-perl \
            libmodule-build-perl \
            libmodule-install-perl \
            libnet-ssleay-perl \
            libperlio-gzip-perl \
            liburi-perl \
            libwww-perl \
            libyaml-libyaml-perl \
            libyaml-perl \
            perl-modules \
            tzdata && \
        apt-get clean && \
        rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/apt/apt.conf.d/apt-proxy.conf

RUN \
        mkdir /tmp/cgiproxy/ && \
        cd /tmp/cgiproxy/ && \
        curl -L -O https://www.jmarshall.com/tools/cgiproxy/releases/cgiproxy.latest.tar.gz && \
        tar xvzf cgiproxy.latest.tar.gz && \
        tar xvzf cgiproxy-inner.*.tar.gz && \
        perl -pi -E 's{^\$PROXY_DIR=.*;$}{\$PROXY_DIR= "/app/cgiproxy" ;}' nph-proxy.cgi && \
        mkdir -m 0750 -p /app/cgiproxy/ /app/cgiproxy/bin /app/cgiproxy/sqlite /app/cgiproxy/perl5 && \
        install -o root -g www-data -m 0750 nph-proxy.cgi /app/cgiproxy/bin/ && \
        rm -rf /tmp/* /var/tmp/*

WORKDIR /app/cgiproxy

RUN \
        export DEBIAN_FRONTEND=noninteractive && \
        if [ -n "$APT_HTTP_PROXY" ]; then \
            printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
        fi && \
        apt-get update && \
        /app/cgiproxy/bin/nph-proxy.cgi install-modules && \
        apt-get clean && \
        rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/apt/apt.conf.d/apt-proxy.conf

RUN \
        /app/cgiproxy/bin/nph-proxy.cgi create-db && \
        rm -rf /tmp/* /var/tmp/*

COPY    cron.d/cgiproxy /etc/cron.d/cgiproxy
COPY    cgiproxy.conf.template /app/cgiproxy/cgiproxy.conf.template
COPY    docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 8002

VOLUME ["/app/cgiproxy"]

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/app/cgiproxy/bin/nph-proxy.cgi", "start-fcgi"]
