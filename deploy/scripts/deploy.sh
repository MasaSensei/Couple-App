#!/bin/sh
# Deploy a CI-built image tag to ONE environment on its Docker host.
#
#   deploy/scripts/deploy.sh staging    <git-sha>
#   deploy/scripts/deploy.sh production <git-sha>   # only after staging passed + explicit approval
#
# Steps: pull → pre-deploy DB backup → migrate (one-off, isolated) → roll app
# containers → smoke test → on failure, roll back to the previous tag.
# Migrations are expand-only (additive); rolling back the code never needs a
# down-migration. See deploy/README.md §Rollback.
set -eu

ENVIRONMENT=${1:?usage: deploy.sh <staging|production> <git-sha>}
TAG=${2:?usage: deploy.sh <staging|production> <git-sha>}
DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$DIR/env/$ENVIRONMENT.env"
STATE="$DIR/env/.$ENVIRONMENT.current-tag"

[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE" >&2; exit 1; }

if [ "$ENVIRONMENT" = "production" ] && [ "${CONFIRM_PRODUCTION:-}" != "yes" ]; then
    echo "Production deploy requires CONFIRM_PRODUCTION=yes (after staging verification and approval)." >&2
    exit 1
fi

REGISTRY=$(grep '^APP_IMAGE=' "$ENV_FILE" | cut -d= -f2 | sed 's#/couples-app:.*##')
PREVIOUS=$(cat "$STATE" 2>/dev/null || echo "")

compose() {
    APP_IMAGE="$REGISTRY/couples-app:$1" WEB_IMAGE="$REGISTRY/couples-web:$1" \
        docker compose -f "$DIR/docker-compose.prod.yml" --env-file "$ENV_FILE" "$@"
}
# shellcheck disable=SC2120
c() { tag=$1; shift; APP_IMAGE="$REGISTRY/couples-app:$tag" WEB_IMAGE="$REGISTRY/couples-web:$tag" \
    docker compose -f "$DIR/docker-compose.prod.yml" --env-file "$ENV_FILE" "$@"; }

echo "==> [$ENVIRONMENT] deploying $TAG (previous: ${PREVIOUS:-none})"

echo "==> pull images"
c "$TAG" pull app web

echo "==> data services up (no-op when already running)"
c "$TAG" up -d --wait postgres redis

echo "==> pre-deploy database backup (must succeed)"
if [ -n "$PREVIOUS" ]; then
    c "$PREVIOUS" exec -T scheduler php artisan db:backup
fi

echo "==> migrations (one-off container, --isolated lock)"
c "$TAG" run --rm migrate

echo "==> roll out app, queue, scheduler, web"
c "$TAG" up -d --no-deps --wait app queue scheduler web
c "$TAG" up -d --no-deps caddy

echo "==> smoke test"
if "$DIR/scripts/smoke-test.sh" "$ENV_FILE"; then
    echo "$TAG" > "$STATE"
    echo "==> [$ENVIRONMENT] $TAG is live"
else
    echo "!! smoke test failed" >&2
    if [ -n "$PREVIOUS" ]; then
        echo "==> rolling back to $PREVIOUS" >&2
        c "$PREVIOUS" up -d --no-deps --wait app queue scheduler web
        "$DIR/scripts/smoke-test.sh" "$ENV_FILE" && echo "==> rollback to $PREVIOUS healthy" >&2
    fi
    exit 1
fi
