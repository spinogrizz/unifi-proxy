#!/bin/sh
#
# Скрипт для сбора статистики из stream логов nginx
# Запускается по cron каждый час
#
# Использование: stats.sh <stream.log> <stats.json>
#

if [ $# -lt 2 ]; then
    echo "Usage: $0 <stream.log> <stats.json>" >&2
    exit 1
fi

LOG="$1"
STATS="$2"

# Минимальный размер файла для учёта (1 MB)
MIN_BYTES=1048576

# Читаем предыдущие значения из stats.json
if [ -f "$STATS" ]; then
    PREV_MB=$(jq -r '.total_mb // 0' "$STATS")
    PREV_DOWNLOADS=$(jq -r '.downloads_total // 0' "$STATS")
    LAST_TS=$(jq -r '.last_ts // ""' "$STATS")
else
    PREV_MB=0
    PREV_DOWNLOADS=0
    LAST_TS=""
fi

# Для 24ч окна: учитываем вчерашний архив, если есть
LOGDIR=$(dirname "$LOG")
LOGNAME=$(basename "$LOG" .log)
YESTERDAY=$(date -d "yesterday" +%Y%m%d 2>/dev/null || date -v-1d +%Y%m%d)
ARCHIVE="${LOGDIR}/${LOGNAME}.${YESTERDAY}.log.gz"

# Парсим лог
if [ -s "$ARCHIVE" ]; then
    RESULT=$( (gzip -cd "$ARCHIVE"; cat "$LOG") | awk -v last_ts="$LAST_TS" -v min_bytes="$MIN_BYTES" '
{
    # Определяем формат: с таймстемпом или без
    if ($1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
        timestamp = $1
        ip = $2
    } else {
        timestamp = ""
        ip = $1
    }

    # Извлекаем bytes_sent
    bytes = 0
    match($0, /bytes_sent=([0-9]+)/)
    if (RSTART > 0) {
        bytes_str = substr($0, RSTART + 11)
        match(bytes_str, /^[0-9]+/)
        bytes = substr(bytes_str, 1, RLENGTH) + 0
    }

    # Уникальные IP за вчера+сегодня (архив + текущий лог)
    ips[ip] = 1

    # Новые данные (после последнего запуска) - для накопительных счётчиков
    if (timestamp == "" || last_ts == "" || timestamp > last_ts) {
        if (bytes > min_bytes) {
            new_bytes += bytes
            new_downloads++
        }
    }

    # Запоминаем последний таймстемп
    if (timestamp != "") {
        max_ts = timestamp
    }
}
END {
    printf "%d %d %d %s\n", length(ips), new_downloads, new_bytes, max_ts
}')
else
    RESULT=$(awk -v last_ts="$LAST_TS" -v min_bytes="$MIN_BYTES" '
{
    # Определяем формат: с таймстемпом или без
    if ($1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
        timestamp = $1
        ip = $2
    } else {
        timestamp = ""
        ip = $1
    }

    # Извлекаем bytes_sent
    bytes = 0
    match($0, /bytes_sent=([0-9]+)/)
    if (RSTART > 0) {
        bytes_str = substr($0, RSTART + 11)
        match(bytes_str, /^[0-9]+/)
        bytes = substr(bytes_str, 1, RLENGTH) + 0
    }

    # Уникальные IP за текущий лог
    ips[ip] = 1

    # Новые данные (после последнего запуска) - для накопительных счётчиков
    if (timestamp == "" || last_ts == "" || timestamp > last_ts) {
        if (bytes > min_bytes) {
            new_bytes += bytes
            new_downloads++
        }
    }

    # Запоминаем последний таймстемп
    if (timestamp != "") {
        max_ts = timestamp
    }
}
END {
    printf "%d %d %d %s\n", length(ips), new_downloads, new_bytes, max_ts
}' "$LOG")
fi

# Парсим результат
UNIQUE_IPS=$(echo "$RESULT" | cut -d' ' -f1)
NEW_DOWNLOADS=$(echo "$RESULT" | cut -d' ' -f2)
NEW_BYTES=$(echo "$RESULT" | cut -d' ' -f3)
MAX_TS=$(echo "$RESULT" | cut -d' ' -f4)

# Добавляем новые значения к накопленным
NEW_MB=$(awk "BEGIN { printf \"%.1f\", $NEW_BYTES / 1048576 }")
TOTAL_MB=$(awk "BEGIN { printf \"%.1f\", $PREV_MB + $NEW_MB }")
TOTAL_DOWNLOADS=$((PREV_DOWNLOADS + NEW_DOWNLOADS))

# Генерируем JSON
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n \
    --argjson ips "$UNIQUE_IPS" \
    --argjson downloads "$TOTAL_DOWNLOADS" \
    --argjson mb "$TOTAL_MB" \
    --arg ts "$MAX_TS" \
    --arg updated "$NOW" \
    '{unique_ips: $ips, downloads_total: $downloads, total_mb: $mb, last_ts: $ts, updated: $updated}' > "${STATS}.tmp" && mv "${STATS}.tmp" "$STATS"

# Ротация: раз в сутки в 00:xx
if [ "$(date +%H)" = "00" ]; then
    # Архивируем текущий лог в gz
    if [ -s "$LOG" ]; then
        gzip -c "$LOG" > "${LOGDIR}/${LOGNAME}.${YESTERDAY}.log.gz"
        : > "$LOG"  # очищаем текущий лог
    fi

    # Удаляем архивы старше 14 дней
    find "$LOGDIR" -name "${LOGNAME}.*.log.gz" -mtime +14 -delete 2>/dev/null
fi
