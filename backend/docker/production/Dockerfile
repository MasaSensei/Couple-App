# syntax=docker/dockerfile:1
#
# Production image. Targets:
#   app  – PHP-FPM (API + Filament); also runs the queue worker and scheduler
#   web  – Nginx serving public/ and proxying PHP to app:9000
#
# Build (from backend/):
#   docker build -f docker/production/Dockerfile --target app -t couples-app:<sha> .
#   docker build -f docker/production/Dockerfile --target web -t couples-web:<sha> .
#
# The development image (docker/Dockerfile) is unchanged and must not be deployed.

# OPcache is part of the PHP 8.5 core (no docker-php-ext-install opcache).
ARG PHP_VERSION=8.5

# ── 1. PHP base with extensions ─────────────────────────────────────────────
FROM php:${PHP_VERSION}-fpm-trixie AS php-base

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev libicu-dev libzip-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
        postgresql-client libfcgi-bin \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" pdo_pgsql intl zip gd pcntl \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get purge -y --auto-remove libpq-dev libicu-dev libzip-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
    && apt-get install -y --no-install-recommends libpq5 libicu76 libzip5 libfreetype6 libjpeg62-turbo libpng16-16t64 \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

COPY docker/production/php.ini /usr/local/etc/php/conf.d/zz-production.ini
COPY docker/production/php-fpm.conf /usr/local/etc/php-fpm.d/zz-www.conf

# ── 2. Composer dependencies (no dev packages, no scripts yet) ──────────────
FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --no-progress --prefer-dist \
        --no-scripts --no-autoloader --ignore-platform-reqs

# ── 3. Application image (PHP-FPM) ──────────────────────────────────────────
FROM php-base AS app

WORKDIR /var/www/html

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY --from=vendor /app/vendor ./vendor
COPY --chown=www-data:www-data . .

# Optimised autoloader + package discovery + Filament assets. Config/route
# caching happens at container start, when the real environment is present.
RUN composer dump-autoload --no-dev --optimize --classmap-authoritative \
    && php artisan package:discover --ansi \
    && php artisan filament:assets \
    && mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache public \
    && rm /usr/bin/composer

COPY --chmod=0755 docker/production/entrypoint.sh /usr/local/bin/app-entrypoint
COPY --chmod=0755 docker/production/healthcheck.sh /usr/local/bin/app-healthcheck

USER www-data

ENV APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr \
    LOG_STDERR_FORMATTER=Monolog\\Formatter\\JsonFormatter

EXPOSE 9000
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=3 CMD ["app-healthcheck"]

ENTRYPOINT ["app-entrypoint"]
CMD ["php-fpm"]

# ── 4. Web server (static files + FastCGI proxy) ────────────────────────────
FROM nginx:1.29-alpine AS web

COPY docker/production/nginx.conf /etc/nginx/nginx.conf
COPY --from=app /var/www/html/public /var/www/html/public

# Runs entirely as the unprivileged nginx user: port 8080, pid and temp files in /tmp.
USER nginx
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/nginx-health || exit 1
