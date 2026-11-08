#!/bin/sh
# Storage / infrastructure FAILURE drill against the local Docker stack.
# NEVER run against production: it stops services and corrupts an object on purpose.
#
#   sh deploy/drills/storage-failure-drill.sh            (from the repo root)
#
# Scenarios (docs/operations/disaster-recovery.md §Drills):
#   A  backup store unavailable  → upload still works, photo is NOT "protected"; recovers
#   B  primary store unavailable → readiness 503, alert, nothing marked verified
#   C  corrupted primary object  → integrity check detects it, repair restores from backup
#   D  queue worker down         → jobs wait in Redis, nothing lost, processed on restart
#   E  database unavailable      → liveness OK, readiness 503 fast, API JSON 500 without details
#   F  restore from backup       → encrypted DB backup restores into a scratch DB
set -u

API=${API:-http://localhost:8000/api/v1}
pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }
art() { docker compose exec -T app php artisan "$@"; }
# php '<code>' [VAR=value ...]  — runs PHP in the app, variables via env (no shell escaping of PHP).
php() { code=$1; shift; envs=""; for kv in "$@"; do envs="$envs -e $kv"; done
        # shellcheck disable=SC2086
        docker compose exec -T $envs app php artisan tinker --execute="$code" 2>&1 | tr -d '\r' | tail -1; }
http() { curl -s -o /tmp/drill.body -w '%{http_code} %{time_total}' --max-time 20 "$@"; }
code_of() { echo "$1" | cut -d' ' -f1; }
status_of() { php 'echo App\Models\MemoryPhoto::find(getenv("PID"))->protectionStatus();' "PID=$1"; }
latest() { php 'echo App\Models\MemoryPhoto::max("id");'; }
wait_ready() { for _ in $(seq 1 30); do [ "$(code_of "$(http "$API/health/ready")")" = 200 ] && return 0; sleep 5; done; return 1; }
upload() { art storage:dr-drill prepare --photos=1 >/tmp/drill.prepare 2>&1; }   # exit 1 = "not protected yet" by design

env=$(php 'echo app()->environment();')
[ "$env" = "local" ] || { echo "Refusing: app environment is '$env', drill runs only in local."; exit 2; }
echo "Drill start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "== Baseline"
upload; P0=$(latest)
php 'App\Jobs\BackupMemoryPhoto::dispatchSync((int) getenv("PID"));' "PID=$P0" >/dev/null
[ "$(status_of "$P0")" = protected ] && ok "baseline photo #$P0 protected" || bad "baseline photo #$P0 is $(status_of "$P0")"
wait_ready && ok "readiness 200 before drills" || bad "readiness not 200 before drills"

echo "== A. Backup store unavailable"
docker compose stop storage_backup >/dev/null 2>&1
upload; PA=$(latest)
st=$(php 'echo App\Models\MemoryPhoto::find(getenv("PID"))->status;' "PID=$PA")
[ "$PA" != "$P0" ] && [ "$st" = verified ] && ok "upload accepted and verified on primary (#$PA)" || bad "upload while backup down: id=$PA status=$st"
s=$(status_of "$PA"); [ "$s" != protected ] && ok "photo #$PA shows '$s', not protected" || bad "photo #$PA claims protected without a backup"
r=$(http "$API/health/ready"); [ "$(code_of "$r")" = 503 ] && ok "readiness 503 in $(echo "$r" | cut -d' ' -f2)s" || bad "readiness: $r"
art ops:alerts 2>/dev/null | grep -q "backup photo store is unreachable" && ok "alert backup_unreachable" || bad "no backup alert"
docker compose start storage_backup >/dev/null 2>&1; sleep 8
php 'App\Jobs\BackupMemoryPhoto::dispatchSync((int) getenv("PID"));' "PID=$PA" >/dev/null
[ "$(status_of "$PA")" = protected ] && ok "photo #$PA protected after backup store returned" || bad "photo #$PA still $(status_of "$PA")"

echo "== B. Primary store unavailable"
before=$(php 'echo App\Models\MemoryPhoto::where("status","verified")->count();')
docker compose stop storage_primary >/dev/null 2>&1
r=$(http "$API/health/ready"); [ "$(code_of "$r")" = 503 ] && ok "readiness 503 in $(echo "$r" | cut -d' ' -f2)s" || bad "readiness: $r"
art ops:alerts 2>/dev/null | grep -q "primary photo store is unreachable" && ok "alert primary_unreachable" || bad "no primary alert"
upload
after=$(php 'echo App\Models\MemoryPhoto::where("status","verified")->count();')
[ "$before" = "$after" ] && ok "upload not completed; verified count unchanged ($after)" || bad "verified count changed $before → $after"
docker compose start storage_primary >/dev/null 2>&1; sleep 8

echo "== C. Corrupted primary object"
# Pause the worker: otherwise it repairs automatically before the intermediate state can be observed
# (that happened in run 2 — repair audit 13:29:00, i.e. the automatic path works).
docker compose stop queue >/dev/null 2>&1
php '$p = App\Models\MemoryPhoto::find(getenv("PID")); Illuminate\Support\Facades\Storage::disk("photos_primary")->put($p->storage_key, random_bytes(64)); echo "ok";' "PID=$P0" >/dev/null
pi=$(php 'App\Jobs\VerifyMemoryPhotoIntegrity::dispatchSync((int) getenv("PID")); echo App\Models\MemoryPhoto::find(getenv("PID"))->primary_integrity;' "PID=$P0")
[ "$pi" = mismatch ] && ok "integrity check detected corruption (primary=$pi)" || bad "corruption not detected (primary=$pi)"
s=$(status_of "$P0"); [ "$s" != protected ] && ok "status '$s' while corrupted (not protected)" || bad "corrupted photo still 'protected'"
res=$(php '$id = (int) getenv("PID"); App\Jobs\RepairMemoryPhoto::dispatchSync($id); App\Jobs\VerifyMemoryPhotoIntegrity::dispatchSync($id); $p = App\Models\MemoryPhoto::find($id); echo $p->primary_integrity.",".(hash("sha256", Illuminate\Support\Facades\Storage::disk("photos_primary")->get($p->storage_key)) === $p->checksum ? "sha-match" : "sha-differs");' "PID=$P0")
[ "$res" = "ok,sha-match" ] && [ "$(status_of "$P0")" = protected ] && ok "repaired from backup: SHA-256 matches original, protected" || bad "repair: $res status=$(status_of "$P0")"
docker compose start queue >/dev/null 2>&1

echo "== D. Queue worker down"
QKEY="$(php 'echo config("database.redis.options.prefix");')queues:default"
docker compose stop queue >/dev/null 2>&1
art ops:heartbeat >/dev/null 2>&1
q=$(docker exec couples_redis redis-cli LLEN "$QKEY" | tr -d '\r')
[ "${q:-0}" -ge 1 ] && ok "$q job(s) waiting in Redis while the worker is down" || bad "no job queued ($QKEY)"
docker compose start queue >/dev/null 2>&1; sleep 15
q=$(docker exec couples_redis redis-cli LLEN "$QKEY" | tr -d '\r')
age=$(php 'echo app(App\Services\Ops\Heartbeat::class)->age("queue");')
[ "$q" = 0 ] && [ "${age:-999}" -lt 60 ] && ok "worker drained the queue on restart (queue heartbeat ${age}s)" || bad "queue=$q heartbeat=${age}s"

echo "== E. Database unavailable"
docker compose stop postgres >/dev/null 2>&1
r=$(http "$API/health"); [ "$(code_of "$r")" = 200 ] && ok "liveness 200 (no DB needed)" || bad "liveness: $r"
r=$(http "$API/health/ready"); [ "$(code_of "$r")" = 503 ] && ok "readiness 503 in $(echo "$r" | cut -d' ' -f2)s" || bad "readiness: $r"
r=$(http -H 'Accept: application/json' -H 'Authorization: Bearer 1|x' "$API/me")
if [ "$(code_of "$r")" = 500 ] && grep -q '"request_id"' /tmp/drill.body && ! grep -qiE 'sqlstate|pgsql|password|/var/www' /tmp/drill.body; then
    ok "API answers JSON 500 with request_id, no internals ($(echo "$r" | cut -d' ' -f2)s)"
else
    bad "API during outage: $r $(head -c 200 /tmp/drill.body)"
fi
docker compose start postgres >/dev/null 2>&1
wait_ready && ok "readiness back to 200 after DB returned" || bad "did not recover"

echo "== F. Restore from backup"
art db:backup 2>/dev/null | grep -q succeeded && ok "encrypted DB backup created" || bad "db:backup failed"
art db:restore-check 2>/dev/null | grep -q "restore passed" && ok "backup restored into scratch DB and verified" || bad "restore-check failed"

echo
echo "Drill finished: $pass passed, $fail failed  ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
[ "$fail" = 0 ]
