#!/bin/sh
# Automated smoke test for the dirvish container.
# dirvish is a backup scheduler (not a network server), so the meaningful
# check is: the container comes up, the runit-managed services (cron +
# postfix) are running, and dirvish itself is functional (parses a master.conf
# and reports its version).
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
IMG=dirvish-test
CN=dirvish-test-run

cleanup() { docker rm -f "$CN" >/dev/null 2>&1 || true; }
trap cleanup EXIT

fail() { echo "FAIL: $1"; exit 1; }

echo ">> building image"
docker build -t "$IMG" "$SCRIPT_DIR"

echo ">> starting container"
docker rm -f "$CN" >/dev/null 2>&1 || true
# mount the repo's dirvish config so entrypoint drops a master.conf into
# /etc/dirvish (dirvish needs one even to answer --version)
docker run -d --name "$CN" -v "$SCRIPT_DIR/config/dirvish:/config:ro" "$IMG" >/dev/null

echo ">> waiting for runit services to come up (up to 60s)"
up=0
for _ in $(seq 1 30); do
  if docker exec "$CN" sv status /container/config/runit/cron 2>/dev/null | grep -q '^run:' \
  && docker exec "$CN" sv status /container/config/runit/postfix 2>/dev/null | grep -q '^run:' \
  && docker exec "$CN" sh -c "ps aux | grep -q '[s]bin/master'" 2>/dev/null; then
    up=1; break
  fi
  sleep 2
done
[ "$up" = 1 ] || fail "runit services did not reach 'run' state in time"

echo ">> assert: container is running"
[ "$(docker inspect -f '{{.State.Running}}' "$CN")" = true ] || fail "container not running"
echo "ok - container running"

echo ">> assert: runsvdir is PID 1"
docker exec "$CN" sh -c "ps -o comm= -p 1 | grep -q runsvdir" || fail "runsvdir is not PID 1"
echo "ok - runsvdir supervising"

echo ">> assert: runit reports cron service running"
docker exec "$CN" sv status /container/config/runit/cron | grep -q '^run:' || fail "cron service not running"
echo "ok - cron service up"

echo ">> assert: runit reports postfix service running"
docker exec "$CN" sv status /container/config/runit/postfix | grep -q '^run:' || fail "postfix service not running"
echo "ok - postfix service up"

echo ">> assert: cron process present"
docker exec "$CN" sh -c "ps aux | grep -q '[/]usr/sbin/cron'" || fail "cron process not running"
echo "ok - cron running"

echo ">> assert: postfix master process present"
docker exec "$CN" sh -c "ps aux | grep -q '[s]bin/master'" || fail "postfix master not running"
echo "ok - postfix master running"

echo ">> assert: dirvish parses master.conf and reports its version"
ver=$(docker exec "$CN" dirvish --version 2>&1) || fail "dirvish --version exited non-zero (got: $ver)"
echo "$ver" | grep -qi 'dirvish version' || fail "dirvish did not report a version (got: $ver)"
echo "ok - dirvish version: $(echo "$ver" | tr -d '\r' | head -1)"

echo ""
echo "ALL TESTS PASSED"
