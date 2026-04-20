# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A lightweight threat intelligence feed system that fetches indicators (hashes, IPs, URLs) from a MISP instance every minute and serves them over HTTP for downstream consumers (firewalls, SOC tools).

## Running & Deployment

Follow `http-server-install.txt` for the full step-by-step deployment. Short version:

```bash
# Deploy config (set real token first)
sudo install -m 640 -o root -g misp misp-feed.conf /etc/misp-feed.conf

# Deploy scripts
sudo cp simple_http_server.py update-feeds.sh misp-*.sh /home/misp/
sudo chmod +x /home/misp/update-feeds.sh /home/misp/misp-*.sh

# Systemd service
sudo cp http-server.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now http-server

# Cron (as misp user) — one line
* * * * * /home/misp/update-feeds.sh >> /var/log/misp-feed.log 2>&1
```

**Verify:**
```bash
curl http://localhost:40000/status          # health check
curl http://localhost:40000/misp-ips.txt
curl http://localhost:40000/misp-hashes.txt
curl http://localhost:40000/misp-urls.txt
```

## Architecture

```
/etc/misp-feed.conf  (token + URLs)
        ↓
update-feeds.sh  [cron every minute]
    ├─ misp-hash-feed.sh  →  /home/misp/feed/misp-hashes.txt
    ├─ misp-ipv4-feed.sh  →  /home/misp/feed/misp-ipv4.txt
    ├─ misp-ipv6-feed.sh  →  /home/misp/feed/misp-ipv6.txt
    └─ misp-url-feed.sh   →  /home/misp/feed/misp-urls.txt
                                        ↓
                         simple_http_server.py  :40000
                         serves /home/misp/feed/, max 5 concurrent
                         GET /status  →  health check endpoint
```

## Configuration

All config lives in `/etc/misp-feed.conf` (not in scripts):

| Variable | Purpose |
|---|---|
| `MISP_URL` | Base URL of MISP instance |
| `MISP_TOKEN` | MISP API auth token |
| `FEED_DIR` | Directory served by HTTP server (default `/home/misp/feed`) |

`simple_http_server.py` has two constants: `MAX_SESSIONS=5` and `SERVE_DIR` (should match `FEED_DIR`).

## Feed Collector Pattern

Each `misp-*.sh` script:
1. Sources `/etc/misp-feed.conf`
2. POSTs to MISP `restSearch` — filters: `last=90d`, `enforceWarninglist=true`, `to_ids=true`
3. Writes to a `mktemp` file
4. Validates the response content with a regex before replacing the live file (`mv`)
5. On any failure, removes the temp file and exits — the old feed file is preserved

## HTTP Server

`simple_http_server.py` extends `SimpleHTTPRequestHandler` with:
- `GET /status` returns `200 OK` for health checks
- `threading.Semaphore(MAX_SESSIONS)` — returns HTTP 503 when exhausted
- Custom `translate_path()` to serve from `SERVE_DIR` regardless of working directory
- All requests logged to syslog via `LOG_DAEMON` facility (visible in `journalctl` and `/var/log/syslog`)
