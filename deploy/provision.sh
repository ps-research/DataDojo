#!/bin/bash
# Provision the DataDojo production host (Ubuntu 24.04). Idempotent-ish.
# Installs: Node 20, MongoDB, Redis, PostgreSQL, MariaDB, SQL Server 2022,
# Python+pandas, R, nginx, certbot. Mirrors the proven dev-box setup.
set -e
export DEBIAN_FRONTEND=noninteractive
LOG=/root/provision.log
exec > >(tee -a "$LOG") 2>&1
echo "=== provision start $(date -u) ==="

apt-get update -qq

# --- base tools ---
apt-get install -y -qq curl gnupg ca-certificates lsb-release build-essential ufw python3-pip

# --- Node 20 (NodeSource) ---
if ! command -v node >/dev/null || [ "$(node -v | cut -c2-3)" -lt 20 ]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
  apt-get install -y -qq nodejs
fi
echo "node $(node -v)"

# --- Redis ---
apt-get install -y -qq redis-server
sed -i 's/^# *maxmemory .*/maxmemory 200mb/; s/^# *maxmemory-policy .*/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf || true
systemctl enable --now redis-server

# --- MongoDB 7 ---
if ! command -v mongod >/dev/null; then
  curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --batch --yes --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
  echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list
  apt-get update -qq
  apt-get install -y -qq mongodb-org
fi
# cap wiredtiger cache
mkdir -p /etc/mongod.conf.d
sed -i '/wiredTiger/d; /cacheSizeGB/d' /etc/mongod.conf || true
systemctl enable --now mongod

# --- PostgreSQL 16 ---
apt-get install -y -qq postgresql postgresql-contrib
systemctl enable --now postgresql
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';" >/dev/null 2>&1 || true
sudo -u postgres psql -c "CREATE DATABASE datadojo_judge;" 2>/dev/null || true

# --- MariaDB ---
apt-get install -y -qq mariadb-server
systemctl enable --now mariadb
mysql -u root -e "CREATE DATABASE IF NOT EXISTS datadojo_judge;" 2>/dev/null || true

# --- SQL Server 2022 (with jammy libldap shim for noble) ---
if ! command -v /opt/mssql/bin/sqlservr >/dev/null; then
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --batch --yes --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/22.04/mssql-server-2022 jammy main" > /etc/apt/sources.list.d/mssql.list
  apt-get update -qq
  apt-get install -y -qq mssql-server
  # noble libldap-2.5 shim
  cd /tmp
  name=$(curl -fsSL "http://security.ubuntu.com/ubuntu/pool/main/o/openldap/" | grep -oE 'libldap-2.5-0_[^"]*_amd64.deb' | sort -u | tail -1)
  curl -fsSL "http://security.ubuntu.com/ubuntu/pool/main/o/openldap/$name" -o ldap.deb
  dpkg-deb -x ldap.deb ./ldapx
  cp -av ./ldapx/usr/lib/x86_64-linux-gnu/lib{lber,ldap}-2.5.so.0* /usr/lib/x86_64-linux-gnu/
  ldconfig
fi
MSSQL_SA_PASSWORD="${MSSQL_SA_PASSWORD:-DataDojo!2026}" MSSQL_PID=Developer ACCEPT_EULA=Y /opt/mssql/bin/mssql-conf -n setup accept-eula 2>/dev/null || true
systemctl enable --now mssql-server 2>/dev/null || true

# --- Python + pandas (judge engine) ---
pip3 install --break-system-packages -q pandas 2>/dev/null || pip3 install -q pandas

# --- R + basics (judge engine) ---
apt-get install -y -qq r-base

# --- nginx + certbot ---
apt-get install -y -qq nginx certbot python3-certbot-nginx

# --- firewall ---
ufw allow 22/tcp >/dev/null 2>&1 || true
ufw allow 80/tcp >/dev/null 2>&1 || true
ufw allow 443/tcp >/dev/null 2>&1 || true
yes | ufw enable >/dev/null 2>&1 || true

echo "=== provision done $(date -u) ==="
