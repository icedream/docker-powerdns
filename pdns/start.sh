#!/bin/bash -e

mkdir -p /etc/powerdns/pdns.d

PDNSVARS="${!PDNSCONF_*}"
touch /etc/powerdns/pdns.conf

for var in $PDNSVARS; do
  varname="$(awk '{print tolower($0)}' <<<"${var#"PDNSCONF_"}")"
  varname="${varname//_/-}"
  value="${!var}"
  echo "$varname=$value" >>/etc/powerdns/pdns.conf
done

if [ -n "${PDNSCONF_API_KEY:-}" ]; then
  cat >/etc/powerdns/pdns.d/api.conf <<EOF
api=yes
webserver=yes
webserver-address=0.0.0.0
webserver-allow-from=0.0.0.0/0
EOF

fi

# Wait for configured MySQL server to be up
if [ -n "$PDNSCONF_GMYSQL_HOST" ]; then
  if [ -z "$PDNSCONF_GMYSQL_DBNAME" ]; then
    echo "ERROR: Missing MySQL database name." >&2
    exit 1
  fi
  if command -v mariadb >/dev/null; then
    mysql_conn_args=(
      "-h$PDNSCONF_GMYSQL_HOST"
    )
    if [ "${PDNSCONF_GMYSQL_SSL:-}" != "yes" ]; then
      mysql_conn_args+=(--skip_ssl)
    fi
    if [ -n "${PDNSCONF_GMYSQL_USER:-}" ]; then
      mysql_conn_args+=("-u$PDNSCONF_GMYSQL_USER")
    fi
    if [ -n "${PDNSCONF_GMYSQL_PASSWORD:-}" ]; then
      mysql_conn_args+=("-p$PDNSCONF_GMYSQL_PASSWORD")
    fi
    if [ -n "${PDNSCONF_GMYSQL_PORT:-}" ]; then
      mysql_conn_args+=("-P$PDNSCONF_GMYSQL_PORT")
    fi
    mysqlcheck() {
      # Wait for MySQL to be available...
      COUNTER=20
      until mariadb "${mysql_conn_args[@]}" -e "show databases" 2>/dev/null; do
        echo "WARNING: MySQL still not up. Trying again..." >&2
        sleep 10
        COUNTER=$((COUNTER - 1))
        if [ $COUNTER -lt 1 ]; then
          echo "ERROR: MySQL connection timed out. Aborting." >&2
          exit 1
        fi
      done

      count=$(mysql "${mysql_conn_args[@]}" -e "select count(*) from information_schema.tables where table_type='BASE TABLE' and table_schema='$PDNSCONF_GMYSQL_DBNAME';" | tail -1)
      if [ "$count" == "0" ]; then
        echo "Database is empty. Importing PowerDNS schema..." >&2
        mysql "${mysql_conn_args[@]}" "$PDNSCONF_GMYSQL_DBNAME" </usr/share/doc/pdns-backend-mysql/schema.mysql.sql && echo "Import done."
      fi
    }
    mysqlcheck
  else
    echo "WARNING: mysql command missing, not waiting for configured MySQL server to be up." >&2
  fi
elif [ -n "$PDNSCONF_GPGSQL_HOST" ]; then
  if command -v psql >/dev/null; then
    if [ -z "$PDNSCONF_GPGSQL_DBNAME" ]; then
      echo "ERROR: Missing PostgreSQL database name." >&2
      exit 1
    fi
    psqlcheck() {
      export PGPASSWORD="${PDNSCONF_GPGSQL_PASSWORD:-}"
      export PGDATABASE="${PDNSCONF_GPGSQL_DBNAME:-}"
      export PGUSER="${PDNSCONF_GPGSQL_USER:-}"
      export PGHOST="${PDNSCONF_GPGSQL_HOST}"
      export PGPORT="${PDNSCONF_GPGSQL_PORT:-5432}"

      COUNTER=20
      until psql -w -l >/dev/null 2>&1; do
        echo "WARNING: PostgreSQL still not up. Trying again..." >&2
        sleep 10
        COUNTER=$((COUNTER - 1))
        if [ $COUNTER -lt 1 ]; then
          echo "ERROR: PostgreSQL connection timed out. Aborting." >&2
          exit 1
        fi
      done

      if ! psql -w -c 'SELECT 1 FROM domains' >/dev/null 2>&1; then
        echo "Database not yet provisioned. Importing PowerDNS schema..." >&2
        psql -w </usr/share/doc/pdns-backend-pgsql/schema.pgsql.sql && echo "Import done."
      fi
    }
    psqlcheck
  else
    echo "WARNING: psql command missing, not waiting for configured PostgreSQL server to be up." >&2
  fi
else
  echo "ERROR: a backend must be configured via environment." >&2
  exit 1
fi

if [ "$SECALLZONES_CRONJOB" == "yes" ]; then
  cat >/etc/crontab <<EOF
PDNSCONF_API_KEY=$PDNSCONF_API_KEY
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
# m  h dom mon dow user    command
0,30 *  *   *   *  root    /usr/local/bin/secallzones.sh > /var/log/cron.log 2>&1
EOF
  ln -sf /proc/1/fd/1 /var/log/cron.log
  cron -f &
fi

# Start PowerDNS
# same as /etc/init.d/pdns monitor
echo "Starting PowerDNS..." >&2

if [ "$#" -gt 0 ]; then
  /usr/sbin/pdns_server "$@" &
else
  /usr/sbin/pdns_server --daemon=no --guardian=no --loglevel=9 &
fi
pdns_pid=$!

trap 'pdns_control quit || true; wait $pdns_pid' TERM INT EXIT

wait $pdns_pid
