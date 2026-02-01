# Техническое описание

## ⚙️ Как это работает

Прокси использует nginx с двумя режимами работы:

### 🔐 SNI Proxy (порт 443)

Основной режим для автоматических обновлений. Работает на уровне L4 (TCP) без терминации TLS.

```
Устройство UniFi                    Прокси                         Ubiquiti
      │                               │                               │
      │ ──── TLS ClientHello ────────>│                               │
      │      (SNI: fw-download...)    │                               │
      │                               │ ──── TCP connect ────────────>│
      │                               │                               │
      │ <═══════════════════════════════════ TLS passthrough ═══════> │
      │           (оригинальный сертификат Ubiquiti)                  │
```

**Преимущества:**
- Устройство видит оригинальный сертификат Ubiquiti
- Полная прозрачность — устройство не знает о прокси
- Не требуется генерация своих сертификатов

### 🌐 HTTP Proxy (порт 80)

Альтернативный режим для ручного скачивания через path-based URL.

```
https://unifi.gryzlov.com/fw-download.ubnt.com/path/to/file
        └──────┬───────┘ └───────┬────────┘ └─────┬─────┘
           наш домен         целевой домен      путь к файлу
```

## 🏗️ Архитектура

```
nginx/
├── nginx.conf              # Базовые настройки
└── conf.d/
    ├── 10-stream.conf      # SNI proxy (443) — L4, без терминации TLS
    └── 20-http.conf        # HTTP proxy (80) — path-based downloads
```

## 🚀 Поднять свой прокси

### 🐳 Docker (рекомендуется)

```bash
docker run -d \
  --name unifi-proxy \
  -p 80:80 \
  -p 443:443 \
  --restart unless-stopped \
  spinogrizz/unifi-proxy:latest
```

### 🐳 Docker Compose

```yaml
services:
  unifi-proxy:
    image: spinogrizz/unifi-proxy:latest
    ports:
      - "80:80"
      - "443:443"
    restart: unless-stopped
```

### 📦 Из исходников

```bash
git clone https://github.com/spinogrizz/unifi-proxy.git
cd unifi-proxy
docker build -t unifi-proxy .
docker run -d -p 80:80 -p 443:443 unifi-proxy
```

## 📝 Конфигурация nginx

### 🔐 SNI Proxy (10-stream.conf)

```nginx
stream {
    resolver 8.8.8.8 1.1.1.1 valid=300s ipv6=off;

    map $ssl_preread_server_name $upstream {
        fw-download.ubnt.com                    fw-download.ubnt.com:443;
        fw-update.ubnt.com                      fw-update.ubnt.com:443;
        fw-update.ui.com                        fw-update.ui.com:443;
        fw-download.ui.com                      fw-download.ui.com:443;
        apt.artifacts.ui.com                    apt.artifacts.ui.com:443;
        apt-release-candidate.artifacts.ui.com  apt-release-candidate.artifacts.ui.com:443;
        apt-beta.artifacts.ui.com               apt-beta.artifacts.ui.com:443;
    }

    server {
        listen 443;
        proxy_pass $upstream;
        ssl_preread on;
    }
}
```

### 🌐 HTTP Proxy (20-http.conf)

```nginx
http {
    resolver 8.8.8.8 1.1.1.1 valid=300s ipv6=off;

    server {
        listen 80;

        # /<domain>/<path> -> https://<domain>/<path>
        location ~ ^/(?<target_domain>[^/]+\.(ui|ubnt)\.com)/(?<target_path>.+)$ {
            proxy_pass https://$target_domain/$target_path;
            proxy_ssl_server_name on;
        }
    }
}
```

## 🤔 Почему не HTTP reverse proxy для HTTPS?

HTTP reverse proxy терминирует TLS и подставляет свой сертификат. Устройства UniFi проверяют сертификат сервера и отказываются скачивать прошивки, если он не соответствует ожидаемому.

Stream proxy работает на уровне TCP — просто пробрасывает соединение на основе SNI, не вмешиваясь в TLS handshake.

## 🛡️ Безопасность

- Прокси не расшифровывает TLS трафик
- Не сохраняет и не модифицирует прошивки
- Логирует только метаданные (IP, домен, размер, время)
- Whitelist только для доменов Ubiquiti

## 📡 Проксируемые домены

| Домен | Назначение |
|-------|------------|
| `fw-download.ubnt.com` | Основной сервер прошивок |
| `fw-update.ubnt.com` | Сервер обновлений |
| `fw-update.ui.com` | Сервер обновлений (ui.com) |
| `fw-download.ui.com` | Сервер прошивок (ui.com) |
| `apt.artifacts.ui.com` | APT репозиторий |
| `apt-release-candidate.artifacts.ui.com` | APT репозиторий (Release Candidate) |
| `apt-beta.artifacts.ui.com` | APT репозиторий (Beta) |
