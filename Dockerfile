FROM --platform=${BUILDPLATFORM} alpine/curl AS download

# Updated automatically by .github/workflows/update-cgiproxy.yml
ARG CGIPROXY_VERSION=2.2.4
ARG CGIPROXY_SHA256=a72c60031b519c373d3719c94326367de89be0fdf4f0b667e59b82d30be829c9

COPY jmarshall.com.code-signing.pub.pem /tmp/jmarshall.com.code-signing.pub.pem

RUN apk add --no-cache openssl

RUN --mount=type=cache,target=/cache <<'EOT'
set -eu
release_file="cgiproxy.${CGIPROXY_VERSION}.tar.gz"
inner_file="cgiproxy-inner.${CGIPROXY_VERSION}.tar.gz"
cached="/cache/${release_file}"
mkdir /tmp/cgiproxy
cd /tmp/cgiproxy

# Checks the outer archive's sha256, then the inner archive's signature
verify() {
    echo "${CGIPROXY_SHA256}  ${cached}" | sha256sum -c - &&
    tar xzf "${cached}" &&
    openssl dgst -sha256 -verify /tmp/jmarshall.com.code-signing.pub.pem \
        -signature "${inner_file}.sig" "${inner_file}"
}

download() {
    curl -fLsS -o "${cached}.part" "https://www.jmarshall.com/tools/cgiproxy/releases/${release_file}"
    mv "${cached}.part" "${cached}"
}

if [ ! -f "${cached}" ]; then
    download
elif ! verify; then
    echo "Cached ${release_file} failed verification; downloading again" >&2
    rm -rf "${cached}" /tmp/cgiproxy/*
    download
fi

# A fresh download gets verified here; a good cached file is verified again
rm -rf /tmp/cgiproxy/*
verify
tar xvzf "${inner_file}"
EOT



FROM  debian:trixie-slim AS base
LABEL maintainer="Robert Loomans <rloomans@users.noreply.github.com>"
LABEL url="https://github.com/rloomans/docker-cgiproxy-fcgi"
LABEL source="https://github.com/rloomans/docker-cgiproxy-fcgi.git"
LABEL org.opencontainers.image.authors="Robert Loomans <rloomans@users.noreply.github.com>"
LABEL org.opencontainers.image.source="https://github.com/rloomans/docker-cgiproxy-fcgi.git"

ARG APT_HTTP_PROXY

RUN \
        export DEBIAN_FRONTEND=noninteractive &&  \
        if [ -n "$APT_HTTP_PROXY" ]; then \
                printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
        fi &&  \
        apt-get update &&  \
        apt-get upgrade -y -o Dpkg::Options::="--force-confold" &&  \
        apt-get install -y --no-install-recommends \
                ca-certificates \
                cron \
                curl \
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
                tzdata  \
        && apt-get clean  \
        && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/apt/apt.conf.d/apt-proxy.conf

RUN mkdir -m 0750 -p /app/cgiproxy/ /app/cgiproxy/bin /app/cgiproxy/sqlite /app/cgiproxy/perl5

COPY --from=download --chmod=0750 --chown=root:www-data /tmp/cgiproxy/nph-proxy.cgi /app/cgiproxy/bin/

RUN perl -pi -E 's{^\$PROXY_DIR=.*;$}{\$PROXY_DIR= "/app/cgiproxy" ;}' /app/cgiproxy/bin/nph-proxy.cgi

WORKDIR /app/cgiproxy

RUN \
        export DEBIAN_FRONTEND=noninteractive  \
        && if [ -n "$APT_HTTP_PROXY" ]; then \
                printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
        fi \
        && apt-get update  \
        && /app/cgiproxy/bin/nph-proxy.cgi install-modules \
        && apt-get clean \
        && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/apt/apt.conf.d/apt-proxy.conf

RUN  /app/cgiproxy/bin/nph-proxy.cgi create-db \
        && rm -rf /tmp/* /var/tmp/*

COPY    cron.d/cgiproxy /etc/cron.d/cgiproxy
COPY    cgiproxy.conf.template /app/cgiproxy/cgiproxy.conf.template
COPY    docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 8002

VOLUME ["/app/cgiproxy"]

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/app/cgiproxy/bin/nph-proxy.cgi", "start-fcgi"]
