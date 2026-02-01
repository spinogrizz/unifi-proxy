# UniFi Firmware Proxy

Nginx-based proxy for Ubiquiti firmware downloads. Helps users in regions with connectivity issues to Ubiquiti update servers.

## Quick Start

```bash
docker run -d -p 80:80 -p 443:443 spinogrizz/unifi-proxy:latest
```

## How It Works

### SNI Proxy (Recommended)

Uses nginx stream module for transparent L4 proxying. TLS traffic passes through without termination — devices see the original Ubiquiti certificate.

Add proxy IP to `/etc/hosts` on your router or in local DNS:

```
# /etc/hosts
1.2.3.4  dl.ui.com
1.2.3.4  fw-download.ubnt.com
1.2.3.4  fw-update.ubnt.com
1.2.3.4  fw-update.ui.com
```

Now HTTPS firmware requests go through the proxy transparently.

### Direct Downloads (Alternative)

If you can't modify DNS, use path-based access over HTTP:

```
http://your-server/dl.ui.com/path/to/firmware.bin
```

## Proxied Domains

- `fw-download.ubnt.com`
- `fw-update.ubnt.com`
- `fw-update.ui.com`
- `fw-download.ui.com`
- `apt.artifacts.ui.com`
- `apt-release-candidate.artifacts.ui.com` (RC)
- `apt-beta.artifacts.ui.com` (Beta)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      nginx                              │
├─────────────────────────────────────────────────────────┤
│  stream (port 443)          │  http (port 80)           │
│  ─────────────────          │  ──────────────           │
│  SNI-based L4 proxy         │  Path-based proxy         │
│  No TLS termination         │  /<domain>/<path>         │
│  Transparent passthrough    │  Health check /health     │
│                             │  Guide site /guide/       │
└─────────────────────────────────────────────────────────┘
```

## Guide Site

Mount your static site to `/var/www/guide`:

```yaml
volumes:
  - ./site/_site:/var/www/guide:ro
```

Visiting `/` redirects to `/guide/`.

## Health Check

```bash
curl http://localhost/health
```

## Advanced: Proxy Other Traffic

To proxy non-Ubiquiti SNI to another server, edit `nginx.conf`:

```nginx
map $ssl_preread_server_name $upstream {
    # ... Ubiquiti domains ...
    default  your-backend:443;
}
```

## License

MIT
