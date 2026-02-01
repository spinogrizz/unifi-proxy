# UniFi Firmware Proxy

Nginx-прокси для обновления прошивок Ubiquiti UniFi в регионах с ограниченным доступом к серверам обновлений.

**Документация для пользователей:** [unifi.gryzlov.com](https://unifi.gryzlov.com)

## Как это работает

### SNI Proxy (порт 443)

Основной механизм. Nginx работает на L4 (stream) и не терминирует TLS — читает SNI из ClientHello и прокидывает TCP на оригинальный сервер Ubiquiti. Устройство видит настоящий сертификат, TLS end-to-end.

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

### Path-based Proxy (порт 80)

Резервный механизм для ручного скачивания. Формат: `https://your-server/<domain>/<path>`

```nginx
location ~ ^/(?<target_domain>[^/]+\.(ui|ubnt)\.com)/(?<target_path>.+)$ {
    proxy_pass https://$target_domain/$target_path;
    proxy_ssl_server_name on;
}
```

## Проксируемые домены

| Домен | Назначение |
|-------|------------|
| `fw-download.ubnt.com` | Основной сервер прошивок |
| `fw-update.ubnt.com` | Сервер обновлений |
| `fw-update.ui.com` | Сервер обновлений (ui.com) |
| `fw-download.ui.com` | Сервер прошивок (ui.com) |
| `apt.artifacts.ui.com` | APT репозиторий |
| `apt-release-candidate.artifacts.ui.com` | APT (Release Candidate) |
| `apt-beta.artifacts.ui.com` | APT (Beta) |

## Архитектура

```
nginx/
├── nginx.conf              # Базовые настройки + include conf.d/*.conf
└── conf.d/
    ├── 10-stream.conf      # stream {} — SNI proxy (443)
    └── 20-http.conf        # http {} — path-based proxy + guide (80)
```

```
┌─────────────────────────────────────────────────────────┐
│                        nginx                            │
├─────────────────────────────────────────────────────────┤
│  stream (443)               │  http (80)                │
│  ───────────                │  ─────────                │
│  L4 SNI proxy               │  Path-based proxy         │
│  Без терминации TLS         │  /<domain>/<path>         │
│  Прозрачный passthrough     │  Health: /health          │
│                             │  Guide: /                 │
└─────────────────────────────────────────────────────────┘
```

## Настройка клиентов

На роутере/консоли UniFi нужно перенаправить домены обновлений на IP прокси-сервера:

```bash
# /etc/hosts на роутере
103.167.234.147  fw-download.ubnt.com
103.167.234.147  fw-update.ubnt.com
103.167.234.147  fw-update.ui.com
103.167.234.147  fw-download.ui.com
103.167.234.147  apt.artifacts.ui.com
103.167.234.147  apt-release-candidate.artifacts.ui.com
103.167.234.147  apt-beta.artifacts.ui.com
```

Или через DNS Policy в UniFi Network (CNAME/A-запись).

## Безопасность

- Нет MITM — TLS трафик проходит насквозь без расшифровки
- Нет подмены сертификата — устройство видит оригинальный сертификат Ubiquiti
- Whitelist только для доменов Ubiquiti — произвольные домены не проксируются

Проверка сертификата через прокси:

```bash
openssl s_client -connect your-proxy:443 -servername fw-download.ubnt.com \
  </dev/null 2>/dev/null | openssl x509 -noout -issuer -subject
```


## Лицензия

MIT.

Я не отвечаю за поломки вашего оборудования, вызванные в следствие подкладывания неправильных прошивок. Вы сами решаете, какую прошивку устанавливать на ваше оборудование.