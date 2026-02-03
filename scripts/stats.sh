#!/bin/sh
#
# Скрипт для сбора статистики из stream логов nginx
# Запускается по cron каждый час
#

LOG="${STATS_LOG:-/var/log/nginx/stream.log}"
STATS="${STATS_OUTPUT:-/var/www/guide/stats.json}"

# Минимальный размер файла для учёта (1 MB)
MIN_BYTES=1048576

# Читаем предыдущие значения из stats.json
if [ -f "$STATS" ]; then
    PREV_MB=$(jq -r '.total_mb // 0' "$STATS")
    LAST_TS=$(jq -r '.last_ts // ""' "$STATS")
else
    PREV_MB=0
    LAST_TS=""
fi

# Получаем cutoff для уникальных IP (24 часа назад)
CUTOFF_24H=$(date -u -d "@$(($(date +%s) - 86400))" +%Y-%m-%dT%H:%M:%S 2>/dev/null || echo "1970-01-01T00:00:00")

# Парсим лог
RESULT=$(awk -v cutoff_24h="$CUTOFF_24H" -v last_ts="$LAST_TS" -v min_bytes="$MIN_BYTES" '
{
    # Определяем формат: с таймстемпом или без
    if ($1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
        timestamp = $1
        ip = $2
    } else {
        timestamp = ""
        ip = $1
    }

    # Уникальные IP за последние 24 часа
    if (timestamp == "" || timestamp >= cutoff_24h) {
        ips[ip] = 1
    }

    # Новые bytes (после последнего запуска)
    if (timestamp == "" || last_ts == "" || timestamp > last_ts) {
        match($0, /bytes_sent=([0-9]+)/)
        if (RSTART > 0) {
            bytes_str = substr($0, RSTART + 11)
            match(bytes_str, /^[0-9]+/)
            bytes = substr(bytes_str, 1, RLENGTH) + 0

            if (bytes > min_bytes) {
                new_bytes += bytes
            }
        }
    }

    # Запоминаем последний таймстемп
    if (timestamp != "") {
        max_ts = timestamp
    }
}
END {
    printf "%d %d %s\n", length(ips), new_bytes, max_ts
}' "$LOG")

# Парсим результат
UNIQUE_IPS=$(echo "$RESULT" | cut -d' ' -f1)
NEW_BYTES=$(echo "$RESULT" | cut -d' ' -f2)
MAX_TS=$(echo "$RESULT" | cut -d' ' -f3)

# Добавляем новые байты к накопленному значению
NEW_MB=$(awk "BEGIN { printf \"%.1f\", $NEW_BYTES / 1048576 }")
TOTAL_MB=$(awk "BEGIN { printf \"%.1f\", $PREV_MB + $NEW_MB }")

# Генерируем JSON
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n \
    --argjson ips "$UNIQUE_IPS" \
    --argjson mb "$TOTAL_MB" \
    --arg ts "$MAX_TS" \
    --arg updated "$NOW" \
    '{unique_ips: $ips, total_mb: $mb, last_ts: $ts, updated: $updated}' > "${STATS}.tmp" && mv "${STATS}.tmp" "$STATS"

# Ротация: раз в сутки в 00:xx
if [ "$(date +%H)" = "00" ]; then
    LOGDIR=$(dirname "$LOG")
    LOGNAME=$(basename "$LOG" .log)
    YESTERDAY=$(date -d "yesterday" +%Y%m%d 2>/dev/null || date -v-1d +%Y%m%d)

    # Архивируем текущий лог в gz
    if [ -s "$LOG" ]; then
        gzip -c "$LOG" > "${LOGDIR}/${LOGNAME}.${YESTERDAY}.log.gz"
        : > "$LOG"  # очищаем текущий лог
    fi

    # Удаляем архивы старше 14 дней
    find "$LOGDIR" -name "${LOGNAME}.*.log.gz" -mtime +14 -delete 2>/dev/null
fi
