#!/bin/sh
#
# Entrypoint: настраивает cron с переменными окружения и запускает nginx
#

# Генерируем crontab с переменными окружения
cat > /etc/crontabs/root << EOF
NGINX_LOG=${NGINX_LOG:-/var/log/nginx/stream.log}
STATS_FILE=${STATS_FILE:-/var/www/guide/stats.json}
0 * * * * /usr/local/bin/stats.sh
EOF

# Создаём пустой stats.json если его нет
STATS_FILE="${STATS_FILE:-/var/www/guide/stats.json}"
if [ ! -f "$STATS_FILE" ]; then
    mkdir -p "$(dirname "$STATS_FILE")"
    echo '{"unique_ips":0,"total_mb":0,"updated":""}' > "$STATS_FILE"
fi

# Симлинк для nginx, если путь отличается от дефолтного
DEFAULT_STATS="/var/www/guide/stats.json"
if [ "$STATS_FILE" != "$DEFAULT_STATS" ]; then
    ln -sf "$STATS_FILE" "$DEFAULT_STATS"
fi

# Запускаем crond и nginx
crond
exec nginx -g "daemon off;"
