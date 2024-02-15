#!/bin/bash
set -vx
set -e -o nounset

timezone() {
  timezone="${1:-"UTC"}"
  [[ -e /usr/share/zoneinfo/$timezone ]] || {
    echo "ERROR: invalid timezone specified: $timezone" >&2
    return
  }

  if [[ -w /etc/timezone && $(cat /etc/timezone) != $timezone ]]; then
    echo "$timezone" >/etc/timezone
    ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
    dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1
  fi
}

[[ "${TZ:-""}" ]] && timezone "$TZ"

if [[ "${SECRET_PATH:-""}" = "" ]]; then
    echo "ERROR: SECRET_PATH environment variable must be set" >&2
    exit 10
fi

perl -p -E 's{^\$SECRET_PATH=.*;\$}{\$SECRET_PATH= "'"$SECRET_PATH"'" ;}' /app/cgiproxy/cgiproxy.conf.template > /app/cgiproxy/cgiproxy.conf
chown root:www-data /app/cgiproxy/cgiproxy.conf
chmod 0640 /app/cgiproxy/cgiproxy.conf
echo Wrote new config file with secret $SECRET_PATH


touch /var/log/cron.log

service cron start && (tail -f /var/log/cron.log &)

exec "$@"
