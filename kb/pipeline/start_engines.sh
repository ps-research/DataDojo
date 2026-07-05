#!/bin/bash
# Start the four SQL engines used by the KB verification farm.
# Idempotent-ish: safe to run after a fresh session (servers are not persistent).
set -e
KB=/workspace/webdev/DataDojo/kb
PGBIN=/usr/lib/postgresql/16/bin

# PostgreSQL on :5433, unix socket in /tmp
if ! PGHOST=/tmp psql -p 5433 -U postgres -c 'select 1' >/dev/null 2>&1; then
  chown -R postgres:postgres "$KB/.pgdata" 2>/dev/null || true
  sudo -u postgres $PGBIN/pg_ctl -D "$KB/.pgdata" -o "-p 5433 -k /tmp" -l /tmp/pglog.txt start
fi

# MariaDB on :3307, unix socket /tmp/mariadb.sock
mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld
if ! mariadb --socket=/tmp/mariadb.sock -u root -e 'select 1' >/dev/null 2>&1; then
  /usr/sbin/mariadbd --user=mysql --datadir="$KB/.mariadata" \
    --socket=/tmp/mariadb.sock --port=3307 --pid-file=/run/mysqld/dd.pid \
    >/tmp/mariadb.log 2>&1 &
  sleep 6
fi
# MS SQL Server 2022 on :1433 (needs jammy libldap-2.5 shims already installed)
if ! pgrep -x sqlservr >/dev/null 2>&1; then
  chown -R mssql:mssql /var/opt/mssql 2>/dev/null || true
  setsid sudo -u mssql env ACCEPT_EULA=Y MSSQL_SA_PASSWORD='DataDojo!2026' MSSQL_PID=Developer \
    /opt/mssql/bin/sqlservr >/tmp/mssql.log 2>&1 </dev/null &
  disown
  until grep -q 'ready for client connections' /tmp/mssql.log 2>/dev/null; do sleep 2; done
fi

echo "postgres: $(PGHOST=/tmp psql -p 5433 -U postgres -tAc 'select version()' 2>&1 | head -1)"
echo "mariadb : $(mariadb --socket=/tmp/mariadb.sock -u root -Ne 'select version()' 2>&1 | head -1)"
echo "mssql   : up on :1433 (SA)"
