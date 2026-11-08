#!/bin/sh
# Post-deploy verification against the public URL of one environment.
#   deploy/scripts/smoke-test.sh deploy/env/staging.env
# Read-only: creates no users and no data.
set -eu

ENV_FILE=${1:?usage: smoke-test.sh <env-file>}
URL=$(grep '^APP_URL=' "$ENV_FILE" | cut -d= -f2)
TOKEN=$(grep '^HEALTH_CHECK_TOKEN=' "$ENV_FILE" | cut -d= -f2 | cut -d' ' -f1)
fail=0

check() { # name expected-status curl-args...
    name=$1 expected=$2; shift 2
    status=$(curl -s -o /tmp/smoke.body -w '%{http_code}' --max-time 15 "$@" || echo 000)
    if [ "$status" = "$expected" ]; then echo "ok    $name ($status)"; else echo "FAIL  $name (got $status, want $expected)"; fail=1; fi
}

# Readiness can lag a few seconds after a restart (first heartbeat).
for attempt in 1 2 3 4 5 6; do
    status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$URL/api/v1/health/ready" || echo 000)
    [ "$status" = 200 ] && break
    sleep 10
done

check "liveness"                 200 "$URL/api/v1/health"
check "readiness (all deps)"     200 -H "Authorization: Bearer $TOKEN" "$URL/api/v1/health/ready"
cat /tmp/smoke.body; echo
check "auth required"            401 -H 'Accept: application/json' "$URL/api/v1/me"
check "debug off (404 is json)"  404 -H 'Accept: application/json' "$URL/api/v1/does-not-exist"
grep -q '"success":false' /tmp/smoke.body || { echo "FAIL  404 body is not the API error format"; fail=1; }
check "mock store not routed"    404 -X POST -H 'Accept: application/json' "$URL/api/v1/billing/mock/purchases"

hsts=$(curl -sI --max-time 10 "$URL/api/v1/health" | grep -i '^strict-transport-security' || true)
[ -n "$hsts" ] && echo "ok    HSTS" || { echo "FAIL  HSTS header missing"; fail=1; }

exit $fail
