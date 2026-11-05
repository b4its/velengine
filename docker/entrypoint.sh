#!/usr/bin/env bash
set -e

# If storage and bootstrap/cache exist, ensure proper permissions
if [ -d "/var/www/html/storage" ]; then
    chmod -R 775 /var/www/html/storage 2>/dev/null || true
fi
if [ -d "/var/www/html/bootstrap/cache" ]; then
    chmod -R 775 /var/www/html/bootstrap/cache 2>/dev/null || true
fi

# Execute passed command (default is php-fpm)
exec "$@"
