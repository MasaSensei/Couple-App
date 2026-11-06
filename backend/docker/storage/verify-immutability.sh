#!/bin/sh
# Proves the application credentials cannot destroy backups (reliability.md §15).
# Uses only the app/db-backup identities for the attacks; the operator identity
# only reads results and removes the probe afterwards.
#
#   docker compose run --rm -v ./backend/docker/storage/verify-immutability.sh:/verify.sh:ro \
#       --entrypoint sh storage_init /verify.sh
set -u

E="--endpoint-url http://storage-backup:8333"
export AWS_DEFAULT_REGION=us-east-1
op()  { AWS_ACCESS_KEY_ID=dev-backup-operator AWS_SECRET_ACCESS_KEY=dev-backup-operator-secret aws $E "$@"; }
app() { AWS_ACCESS_KEY_ID=dev-backup-app AWS_SECRET_ACCESS_KEY=dev-backup-app-secret aws $E "$@"; }
dbb() { AWS_ACCESS_KEY_ID=dev-db-backup AWS_SECRET_ACCESS_KEY=dev-db-backup-secret aws $E "$@"; }

failures=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; failures=$((failures + 1)); }
denied() { if "$@" >/dev/null 2>&1; then return 1; else return 0; fi; }

version_of() { op s3api list-object-versions --bucket "$1" --prefix "$2" --query 'Versions[0].VersionId' --output text; }

key="probe/immutability-$(date +%s).bin"
echo probe > /tmp/probe

for bucket in photos-backup db-backups; do
    mode=$(op s3api get-object-lock-configuration --bucket "$bucket" --query 'ObjectLockConfiguration.Rule.DefaultRetention.Mode' --output text 2>/dev/null)
    [ "$mode" = GOVERNANCE ] || [ "$mode" = COMPLIANCE ] && pass "$bucket has default retention ($mode)" || fail "$bucket has no default retention"
done

app s3api put-object --bucket photos-backup --key "$key" --body /tmp/probe >/dev/null && pass "app can write a backup copy" || fail "app cannot write"
v=$(version_of photos-backup "$key")
denied app s3api delete-object --bucket photos-backup --key "$key" --version-id "$v" && pass "app cannot delete a locked version" || fail "app deleted a locked version"
denied app s3api delete-object --bucket photos-backup --key "$key" --version-id "$v" --bypass-governance-retention && pass "app cannot bypass governance" || fail "app bypassed governance"
denied app s3api put-object-retention --bucket photos-backup --key "$key" --version-id "$v" --bypass-governance-retention \
    --retention '{"Mode":"GOVERNANCE","RetainUntilDate":"2000-01-01T00:00:00Z"}' && pass "app cannot shorten retention" || fail "app shortened retention"
denied app s3api put-object-lock-configuration --bucket photos-backup \
    --object-lock-configuration '{"ObjectLockEnabled":"Enabled"}' && pass "app cannot change bucket lock config" || fail "app changed lock config"
denied app s3api delete-bucket --bucket photos-backup && pass "app cannot delete the bucket" || fail "app deleted the bucket"
app s3api delete-object --bucket photos-backup --key "$key" >/dev/null 2>&1
[ "$(version_of photos-backup "$key")" = "$v" ] && pass "a plain delete only hides the object (version kept)" || fail "plain delete removed the version"

denied app s3api put-object --bucket db-backups --key "$key" --body /tmp/probe && pass "photo app cannot touch db-backups" || fail "photo app wrote db-backups"
denied dbb s3api put-object --bucket photos-backup --key "$key" --body /tmp/probe && pass "db-backup identity cannot touch photos-backup" || fail "db identity wrote photos-backup"
dbb s3api put-object --bucket db-backups --key "$key" --body /tmp/probe >/dev/null
w=$(version_of db-backups "$key")
denied dbb s3api delete-object --bucket db-backups --key "$key" --version-id "$w" && pass "db-backup identity cannot delete a locked dump" || fail "db identity deleted a dump"

# Cleanup (operator, GOVERNANCE bypass; impossible under COMPLIANCE, which is the point).
for b in photos-backup db-backups; do
    for id in $(op s3api list-object-versions --bucket "$b" --prefix "$key" --query '[Versions[].VersionId, DeleteMarkers[].VersionId][]' --output text); do
        op s3api delete-object --bucket "$b" --key "$key" --version-id "$id" --bypass-governance-retention >/dev/null 2>&1
    done
done

echo "failures=$failures"
exit "$failures"
