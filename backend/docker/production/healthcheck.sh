#!/bin/sh
# Role-aware container health check.
#   php-fpm   → FastCGI ping (process is serving)
#   queue     → recent queue heartbeat in PostgreSQL
#   scheduler → recent scheduler heartbeat in PostgreSQL
# Dependency health (DB, Redis, storage) is reported by /api/v1/health/ready.
set -eu

case "${CONTAINER_ROLE:-web}" in
    queue|scheduler)
        php -r '
            require "/var/www/html/vendor/autoload.php";
            $app = require "/var/www/html/bootstrap/app.php";
            $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
            exit(app(App\Services\Ops\Heartbeat::class)->isStale(getenv("CONTAINER_ROLE")) ? 1 : 0);
        '
        ;;
    *)
        SCRIPT_NAME=/fpm-ping SCRIPT_FILENAME=/fpm-ping REQUEST_METHOD=GET \
            cgi-fcgi -bind -connect 127.0.0.1:9000 | grep -q pong
        ;;
esac
