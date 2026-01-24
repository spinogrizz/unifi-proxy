# UniFi Firmware Proxy

Nginx-based proxy for Ubiquiti firmware downloads. Helps users in regions with connectivity issues to Ubiquiti update servers.

## Quick Start

```bash
docker run -d -p 80:80 spinogrizz/unifi-proxy:latest
```

## How It Works

Add proxy IP to `/etc/hosts` for Ubiquiti domains:

```
# /etc/hosts
1.2.3.4  dl.ui.com
1.2.3.4  fw-download.ubnt.com
1.2.3.4  fw-update.ubnt.com
1.2.3.4  fw-update.ui.com
```

Now firmware requests go through the proxy transparently.

## Proxied Domains

- `dl.ui.com`
- `fw-download.ubnt.com`
- `fw-update.ubnt.com`
- `fw-update.ui.com`
- `apt.artifacts.ui.com`

## Guide Site

Mount your Jekyll site to `/var/www/guide`:

```yaml
volumes:
  - ./site/_site:/var/www/guide:ro
```

Visiting `/` redirects to `/guide/`.

## SSL/TLS

### Behind a Reverse Proxy (Recommended)

```yaml
services:
  unifi-proxy:
    image: spinogrizz/unifi-proxy:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.unifi-proxy.rule=Host(`unifi.example.com`)"
      - "traefik.http.routers.unifi-proxy.tls.certresolver=letsencrypt"
```

## Health Check

```bash
curl http://localhost/health
```

## License

MIT
