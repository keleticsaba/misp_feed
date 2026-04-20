#!/bin/bash
# Single entry point for all feed updates — run via cron every minute
cd "$(dirname "$0")"

bash misp-hash-feed.sh
bash misp-ipv4-feed.sh
bash misp-ipv6-feed.sh
bash misp-url-feed.sh
