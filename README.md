# UniFi Firmware Proxy

Nginx-прокси для обновления прошивок Ubiquiti/UniFi в регионах с ограниченным доступом к серверам обновлений.

> ## 🌐 Готовый публичный прокси — **[unifi.gryzlov.com](https://unifi.gryzlov.com)**
>
> Инструкция для пользователей и конвертер ссылок для ручного скачивания — там же, разворачивать ничего не нужно. Ниже — как поднять **свой** сервер. 

## Как это работает

### SNI Proxy (порт 443)

Основной механизм. Nginx работает на L4 (stream) и не терминирует TLS — читает SNI из ClientHello и прокидывает TCP на оригинальный сервер Ubiquiti. Устройство видит настоящий сертификат, TLS end-to-end.

В конфигурации ниже проксируются все домены вида `*.ui.com` и `*.ubnt.com` на тот же хост:443, но можно убрать ```hostnames;``` и добавить конкретные домены в map.

```nginx
stream {
    resolver 8.8.8.8 1.1.1.1 valid=300s ipv6=off;

    # Любой поддомен *.ui.com / *.ubnt.com -> тот же хост:443.
    # Ключ hostnames обязателен, иначе не работает wildcard.
    map $ssl_preread_server_name $upstream {
        hostnames;
        .ui.com     $ssl_preread_server_name:443;
        .ubnt.com   $ssl_preread_server_name:443;
        default     "";
    }

    server {
        listen 443;
        proxy_pass $upstream;
        ssl_preread on;
    }
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
| `static.ubnt.com` | Иконки устройств |
| `nca-iot-us-west-2.svc.ui.com` | MQTT-канал к облаку (порт 8883) |



## Настройка клиентов

На роутере/консоли UniFi нужно перенаправить домены обновлений на IP прокси-сервера:

```bash
# /etc/hosts на роутере
<IP-вашего-прокси>  fw-download.ubnt.com
<IP-вашего-прокси>  fw-update.ubnt.com
<IP-вашего-прокси>  fw-update.ui.com
<IP-вашего-прокси>  fw-download.ui.com
<IP-вашего-прокси>  apt.artifacts.ui.com
<IP-вашего-прокси>  apt-release-candidate.artifacts.ui.com
<IP-вашего-прокси>  apt-beta.artifacts.ui.com
<IP-вашего-прокси>  static.ubnt.com
<IP-вашего-прокси>  nca-iot-us-west-2.svc.ui.com
```

Или через DNS Policy в UniFi Network — CNAME с каждого домена на `<ваш-домен>`.

## Иконки устройств (static.ubnt.com)

Иконки в списке устройств берутся из fingerprint'ов, которые консоль тянет с `static.ubnt.com/fingerprint/0/devicelist.json` и кеширует у себя.

Проксируется как обычный SNI-домен, он уже в есть в списке выше. После прописывания правила подождите несколько часов или перезагрузите консоль.


## MQTT-канал к облаку (nca-iot-*.svc.ui.com)

Консоль держит постоянное MQTT-соединение с `nca-iot-us-west-2.svc.ui.com:8883` — обратный канал к Ubiquiti, через который она видна онлайн в [unifi.ui.com](https://unifi.ui.com). DPI иногда режет установку нового соединения. Пока коннект жив — всё ок, но после обрыва (реконнект, ребут) переподключиться уже не выходит и консоль выпадает в офлайн.

Это лечится проксированием порта **8883**, поэтому нужен отдельный stream-listener:

```nginx
map $ssl_preread_server_name $mqtt_upstream {
    hostnames;
    .svc.ui.com   $ssl_preread_server_name:8883;
    default       "";
}

server {
    listen 8883;
    proxy_pass $mqtt_upstream;
    ssl_preread on;
}
```

Клиенту надо указать DNS запись CNAME `nca-iot-us-west-2.svc.ui.com` → `<ваш-домен>` (регион в имени может отличаться — проверьте, к какому именно брокеру коннектится ваша консоль).


## Как развернуть

**Первая опция — свой nginx.** 
Нужен nginx со stream-модулем `ngx_stream_module`. На сервере должны быть свободные порты **443** (для обновлений) и **8883** (MQTT). Кладете `stream {}` блоки из примеров выше и перезагружаете nginx. Мой публичный сервер так и поднят.

**Вторая опция — docker compose.**
Образ и конфиги собраны вместе — скачиваете compose-файл и запускаете```docker compose up -d```. Порты 443 и 8883 на хосте должны быть свободны на этом сервере.

## Безопасность

- Нет MITM — TLS трафик проходит насквозь без расшифровки
- Нет подмены сертификата — устройство видит оригинальный сертификат Ubiquiti
- Whitelist только для доменов Ubiquiti — произвольные домены не проксируются

Проверка сертификата через прокси:

```bash
openssl s_client -connect <ваш-домен>:443 -servername fw-download.ubnt.com \
  </dev/null 2>/dev/null | openssl x509 -noout -issuer -subject
```


## Лицензия

MIT — я не отвечаю за поломки вашего оборудования, вызванные в следствие подкладывания неправильных прошивок. Вы сами решаете, какую прошивку устанавливать на ваше оборудование.