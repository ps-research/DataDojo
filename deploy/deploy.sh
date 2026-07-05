#!/bin/bash
# Build + (re)deploy DataDojo on the production host. Run ON the Vultr box after
# provision.sh has completed and the repo is synced to /root/DataDojo.
set -e
ROOT=/root/DataDojo
cd "$ROOT"
echo "=== deploy $(date -u) ==="

# --- API: install, build ---
cd "$ROOT/app/api"
npm install --no-audit --no-fund
npm run build

# --- .env (generate once; keep secrets stable across deploys) ---
if [ ! -f "$ROOT/app/api/.env" ]; then
  cp "$ROOT/app/api/.env.example" "$ROOT/app/api/.env"
  SECRET=$(openssl rand -hex 32)
  sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$SECRET|" "$ROOT/app/api/.env"
  echo "generated .env with fresh JWT_SECRET"
fi

# --- Web: install, build, publish to a www-data-readable dir ---
cd "$ROOT/app/web"
npm install --no-audit --no-fund
npm run build
mkdir -p /var/www/datadojo
rm -rf /var/www/datadojo/*
cp -r "$ROOT/app/web/dist/"* /var/www/datadojo/
chown -R www-data:www-data /var/www/datadojo
chmod -R a+rX /var/www/datadojo

# --- systemd service ---
cp "$ROOT/deploy/datadojo-api.service" /etc/systemd/system/datadojo-api.service
systemctl daemon-reload
systemctl enable datadojo-api
systemctl restart datadojo-api

# --- nginx ---
cp "$ROOT/deploy/nginx-datadojo.conf" /etc/nginx/sites-available/datadojo
ln -sf /etc/nginx/sites-available/datadojo /etc/nginx/sites-enabled/datadojo
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo "=== waiting for API health ==="
for i in $(seq 1 20); do
  sleep 2
  if curl -s -m 2 http://127.0.0.1:4000/api/health >/dev/null 2>&1; then
    echo "API healthy: $(curl -s http://127.0.0.1:4000/api/health)"
    break
  fi
done
echo "=== deploy done ==="
