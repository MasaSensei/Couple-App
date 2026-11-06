#!/bin/sh
# Dev-only bucket bootstrap. Runs with operator credentials, never the app's.
set -eu

bucket() { # endpoint key secret bucket extra-create-args...
    endpoint=$1 key=$2 secret=$3 name=$4; shift 4
    export AWS_ACCESS_KEY_ID=$key AWS_SECRET_ACCESS_KEY=$secret AWS_DEFAULT_REGION=us-east-1

    until aws --endpoint-url "$endpoint" s3api list-buckets >/dev/null 2>&1; do sleep 2; done

    if ! aws --endpoint-url "$endpoint" s3api head-bucket --bucket "$name" >/dev/null 2>&1; then
        aws --endpoint-url "$endpoint" s3api create-bucket --bucket "$name" "$@"
    fi

    aws --endpoint-url "$endpoint" s3api put-bucket-versioning --bucket "$name" \
        --versioning-configuration Status=Enabled

    # Bytes replaced by repair or hidden by a purge's delete marker stay restorable
    # for 30 days, then expire. The app itself never deletes object versions.
    aws --endpoint-url "$endpoint" s3api put-bucket-lifecycle-configuration --bucket "$name" \
        --lifecycle-configuration '{"Rules":[{"ID":"expire-noncurrent","Status":"Enabled","Filter":{"Prefix":""},"NoncurrentVersionExpiration":{"NoncurrentDays":30}}]}'
}

bucket http://storage-primary:8333 dev-primary-operator dev-primary-operator-secret photos-primary
# Object lock can only be turned on at bucket creation; retention rules come in STEP 10.
bucket http://storage-backup:8333 dev-backup-operator dev-backup-operator-secret photos-backup \
    --object-lock-enabled-for-bucket
# Encrypted PostgreSQL dumps (db:backup): same store as the photo backup, own bucket and credential.
bucket http://storage-backup:8333 dev-backup-operator dev-backup-operator-secret db-backups \
    --object-lock-enabled-for-bucket

# Every new version in the backup buckets is locked for 30 days. GOVERNANCE in dev
# so an operator can still clean up; production uses COMPLIANCE (see reliability.md §15).
for name in photos-backup db-backups; do
    aws --endpoint-url http://storage-backup:8333 s3api put-object-lock-configuration --bucket "$name" \
        --object-lock-configuration '{"ObjectLockEnabled":"Enabled","Rule":{"DefaultRetention":{"Mode":"GOVERNANCE","Days":30}}}'
done

echo "storage buckets ready"
