#!/usr/bin/env bash
#
# Deploy the WiltKey TEST relay (test.wiltkey.org) — a fully ISOLATED instance.
#
# This never touches production: separate remote dir, separate pm2 app,
# separate Postgres database (wiltkey_test), separate Redis DB index, separate
# local storage dir. The binary runs with WK_TEST_MODE=true, so /ping reports
# {"mode":"test"} and connected apps show the "TEST SERVER" banner.
#
# Same safety pattern as deploy.sh: cross-compile locally, upload to a staging
# name, dated backup, swap, restart — a partial upload can never clobber the
# working binary.
#
# Configure via environment variables:
#   WK_DEPLOY_SSH        ssh host/alias of the target server     (required)
#   WK_TEST_DIR          remote dir          (default: /root/wiltkey-test)
#   WK_TEST_APP          pm2 process name    (default: wiltkey-test)
#   WK_TEST_BIN          binary filename     (default: wiltkey-relay-test)
#   WK_TEST_PORT         listen port         (default: 8091)
#   WK_TEST_REDIS_DB     Redis DB index      (default: 2  — prod uses 1)
#   WK_TEST_DAILY_MINTS  token mints/IP/day  (default: 50 — relaxed for testing)
#   WK_TEST_STORAGE_DIR  large-file dir      (default: <WK_TEST_DIR>/storage)
#   WK_TEST_POSTGRES_URL optional override; by default DERIVED from the prod
#                        /root/wiltkey/.env with the DB renamed
#                        wiltkey → wiltkey_test (same credentials, isolated data)
#
# First run also: creates the remote dir + wiltkey_test Postgres database and
# registers the pm2 app. Later runs behave like deploy.sh (backup/swap/restart).
#
# Rollback: ssh "$WK_DEPLOY_SSH" 'cp <dir>/<bin>.bak-YYYYMMDD <dir>/<bin> \
#   && pm2 restart <app>'
#
set -euo pipefail

SSH_HOST="${WK_DEPLOY_SSH:?set WK_DEPLOY_SSH to the target ssh host/alias}"
REMOTE_DIR="${WK_TEST_DIR:-/root/wiltkey-test}"
PM2_APP="${WK_TEST_APP:-wiltkey-test}"
BIN_NAME="${WK_TEST_BIN:-wiltkey-relay-test}"
PORT="${WK_TEST_PORT:-8091}"
REDIS_DB="${WK_TEST_REDIS_DB:-2}"
DAILY_MINTS="${WK_TEST_DAILY_MINTS:-50}"
STORAGE_DIR="${WK_TEST_STORAGE_DIR:-$REMOTE_DIR/storage}"
TEST_DB_NAME="wiltkey_test"
LOCAL_BIN="$(mktemp -t wiltkey-relay-test.XXXXXX)"
STAMP="$(date +%Y%m%d)"

echo "==> Cross-compiling linux/amd64 static binary…"
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o "$LOCAL_BIN" .
file "$LOCAL_BIN"

echo "==> Preparing remote dir $REMOTE_DIR (+ storage dir, first-run safe)…"
ssh "$SSH_HOST" "mkdir -p $REMOTE_DIR $STORAGE_DIR"

echo "==> Ensuring Postgres database '$TEST_DB_NAME' exists (idempotent)…"
ssh "$SSH_HOST" "sudo -u postgres psql -tc \"SELECT 1 FROM pg_database WHERE datname='$TEST_DB_NAME'\" | grep -q 1 \
  || sudo -u postgres createdb $TEST_DB_NAME"

echo "==> Resolving POSTGRES_URL for the test DB…"
if [ -n "${WK_TEST_POSTGRES_URL:-}" ]; then
  TEST_PG_URL="$WK_TEST_POSTGRES_URL"
else
  # Derive from the production .env: same credentials, DB renamed to
  # wiltkey_test. Nothing about the prod DB is touched — we only READ its URL.
  TEST_PG_URL="$(ssh "$SSH_HOST" "grep -E '^POSTGRES_URL=' /root/wiltkey/.env 2>/dev/null | head -n1 | cut -d= -f2-" \
    | sed -E 's#(/)[^/?]+(\?)#\1'"$TEST_DB_NAME"'\2#')"
  if [ -z "$TEST_PG_URL" ]; then
    echo "ABORT: could not derive POSTGRES_URL from /root/wiltkey/.env." >&2
    echo "Set WK_TEST_POSTGRES_URL='postgres://user:pass@localhost:5432/$TEST_DB_NAME?sslmode=disable' and re-run." >&2
    exit 1
  fi
  case "$TEST_PG_URL" in
    *"$TEST_DB_NAME"*) : ;;
    *) echo "ABORT: derived URL does not point at $TEST_DB_NAME — refusing (got: $TEST_PG_URL)" >&2; exit 1 ;;
  esac
fi
echo "    (DB name only — password not printed)"

echo "==> Writing $REMOTE_DIR/.env (POSTGRES_URL only; no bucket, no FCM on test)…"
ssh "$SSH_HOST" "umask 077 && printf 'POSTGRES_URL=%s\n' '$TEST_PG_URL' > $REMOTE_DIR/.env"

echo "==> Backing up the existing test binary (if any) to $BIN_NAME.bak-$STAMP…"
ssh "$SSH_HOST" "test -f $REMOTE_DIR/$BIN_NAME && cp $REMOTE_DIR/$BIN_NAME $REMOTE_DIR/$BIN_NAME.bak-$STAMP || true"

echo "==> Uploading new binary to staging ($BIN_NAME.new)…"
scp "$LOCAL_BIN" "$SSH_HOST:$REMOTE_DIR/$BIN_NAME.new"
rm -f "$LOCAL_BIN"

echo "==> Writing pm2 ecosystem config ($PM2_APP)…"
ssh "$SSH_HOST" "cat > $REMOTE_DIR/ecosystem.test.config.js <<'EOF'
module.exports = {
  apps: [{
    name: '$PM2_APP',
    script: '$REMOTE_DIR/$BIN_NAME',
    cwd: '$REMOTE_DIR',
    env: {
      PORT: '$PORT',
      WK_TEST_MODE: 'true',
      REDIS_ADDR: 'localhost:6379',
      REDIS_DB: '$REDIS_DB',
      WK_LOCAL_STORAGE_DIR: '$STORAGE_DIR',
      WK_ISSUANCE_DAILY_IP: '$DAILY_MINTS'
    }
  }]
};
EOF"

echo "==> Swapping in the new binary…"
ssh "$SSH_HOST" "chmod +x $REMOTE_DIR/$BIN_NAME.new \
  && mv -f $REMOTE_DIR/$BIN_NAME.new $REMOTE_DIR/$BIN_NAME"

echo "==> Starting/restarting pm2 app '$PM2_APP'…"
ssh "$SSH_HOST" "if pm2 describe $PM2_APP >/dev/null 2>&1; then \
    pm2 restart $PM2_APP; \
  else \
    pm2 start $REMOTE_DIR/ecosystem.test.config.js; \
  fi; pm2 save"
echo "    (note: envs live in ecosystem.test.config.js, baked at first start —"
echo "     to CHANGE an env: pm2 delete $PM2_APP && pm2 start $REMOTE_DIR/ecosystem.test.config.js)"

echo "==> Verifying (local port ping must say mode:test)…"
sleep 2
ssh "$SSH_HOST" "curl -s http://127.0.0.1:$PORT/ping; echo; \
  pm2 list | grep -E '$PM2_APP' || true; \
  echo '--- last logs ---'; pm2 logs $PM2_APP --lines 8 --nostream 2>/dev/null | tail -12"

echo ""
echo "==> Done. Test relay is LIVE on the box at 127.0.0.1:$PORT."
echo "    External reach still needs (one-time, see TEST_RELAY_SETUP.md):"
echo "      1. Cloudflare DNS: test.wiltkey.org -> this VPS (proxied)"
echo "      2. nginx server block for test.wiltkey.org -> 127.0.0.1:$PORT"
echo "    Verify after that: curl https://test.wiltkey.org/ping   -> {\"mode\":\"test\"}"
echo "    Tear down any time: ssh '$SSH_HOST' 'pm2 delete $PM2_APP' (data is disposable)."
