#!/usr/bin/env bash
#
# Deploy the WiltKey relay to a remote server.
#
# The relay is a single cross-compiled Go binary managed by pm2 (no container).
# This script cross-compiles a linux/amd64 static binary, backs up the live one
# (dated), uploads to a staging name, swaps it in, and restarts the pm2 app.
# A partial upload can never clobber the working binary — the swap happens only
# after a full transfer — and the dated backup lets you roll back instantly.
#
# Configure via environment variables (e.g. in an .env you source, or inline):
#   WK_DEPLOY_SSH     ssh host/alias of the target server            (required)
#   WK_DEPLOY_DIR     remote dir holding the binary   (default: /root/wiltkey)
#   WK_DEPLOY_APP     pm2 process name                (default: wiltkey)
#   WK_DEPLOY_BIN     binary filename in that dir     (default: wiltkey-relay)
#   WK_DEPLOY_PORT    listen port, for the verify step (default: 8090)
#
# Usage:    WK_DEPLOY_SSH=my-server ./deploy.sh        (from wiltkey_server/)
# Rollback: ssh "$WK_DEPLOY_SSH" 'cp <dir>/<bin>.bak-YYYYMMDD <dir>/<bin> && pm2 restart <app>'
#
set -euo pipefail

SSH_HOST="${WK_DEPLOY_SSH:?set WK_DEPLOY_SSH to the target ssh host/alias}"
REMOTE_DIR="${WK_DEPLOY_DIR:-/root/wiltkey}"
PM2_APP="${WK_DEPLOY_APP:-wiltkey}"
BIN_NAME="${WK_DEPLOY_BIN:-wiltkey-relay}"
PORT="${WK_DEPLOY_PORT:-8090}"
LOCAL_BIN="$(mktemp -t wiltkey-relay-linux.XXXXXX)"
STAMP="$(date +%Y%m%d)"

echo "==> Cross-compiling linux/amd64 static binary…"
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o "$LOCAL_BIN" .
file "$LOCAL_BIN"

echo "==> Backing up the live binary to $BIN_NAME.bak-$STAMP…"
ssh "$SSH_HOST" "cp $REMOTE_DIR/$BIN_NAME $REMOTE_DIR/$BIN_NAME.bak-$STAMP"

echo "==> Uploading new binary to staging ($BIN_NAME.new)…"
scp "$LOCAL_BIN" "$SSH_HOST:$REMOTE_DIR/$BIN_NAME.new"
rm -f "$LOCAL_BIN"

echo "==> Swapping in + restarting pm2 app '$PM2_APP'…"
ssh "$SSH_HOST" "chmod +x $REMOTE_DIR/$BIN_NAME.new \
  && mv $REMOTE_DIR/$BIN_NAME.new $REMOTE_DIR/$BIN_NAME \
  && pm2 restart $PM2_APP \
  && sleep 2"

echo "==> Verifying…"
ssh "$SSH_HOST" "pm2 list | grep -E '$PM2_APP|name'; \
  echo '--- port ---'; ss -tlnp 2>/dev/null | grep ':$PORT' || true; \
  echo '--- last logs ---'; pm2 logs $PM2_APP --lines 8 --nostream 2>/dev/null | tail -12"

echo "==> Done. Roll back with the dated backup if needed (see header)."
