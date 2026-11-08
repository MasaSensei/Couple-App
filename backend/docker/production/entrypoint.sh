#!/bin/sh
# Container start for every role (php-fpm, queue worker, scheduler).
# Never runs migrations: those are an explicit deploy step (deploy/README.md).
set -eu

: "${APP_KEY:?APP_KEY must be set}"
export PHP_FPM_MAX_CHILDREN="${PHP_FPM_MAX_CHILDREN:-10}"

if [ "${APP_ENV:-production}" != "local" ] && [ "${APP_DEBUG:-false}" != "false" ]; then
    echo "Refusing to start: APP_DEBUG must be false outside local development." >&2
    exit 1
fi

# Cache config/routes/views/events with the real environment.
php artisan optimize --no-ansi >/dev/null

exec "$@"
