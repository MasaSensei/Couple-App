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
}

bucket http://storage-primary:8333 dev-primary-operator dev-primary-operator-secret photos-primary
# Object lock can only be turned on at bucket creation; retention rules come in STEP 10.
bucket http://storage-backup:8333 dev-backup-operator dev-backup-operator-secret photos-backup \
    --object-lock-enabled-for-bucket

echo "storage buckets ready"
