#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MISP_HOME="/home/misp"
FEED_DIR="${MISP_HOME}/feed"
SERVICE_NAME="http-server"
CRON_LINE="* * * * * ${MISP_HOME}/update-feeds.sh >> /var/log/misp-feed.log 2>&1"

# Must run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run with sudo: sudo bash $0" >&2
  exit 1
fi

# misp user must exist
if ! id misp &>/dev/null; then
  echo "ERROR: 'misp' user does not exist. Create it first:" >&2
  echo "  sudo useradd -r -m -d ${MISP_HOME} -s /bin/bash misp" >&2
  exit 1
fi

echo "==> Deploying config"
install -m 640 -o root -g misp "${SCRIPT_DIR}/misp-feed.conf" /etc/misp-feed.conf

echo "==> Creating feed directory"
mkdir -p "${FEED_DIR}"
chown misp:misp "${FEED_DIR}"

echo "==> Deploying scripts"
cp "${SCRIPT_DIR}/simple_http_server.py" \
   "${SCRIPT_DIR}/update-feeds.sh" \
   "${SCRIPT_DIR}/misp-hash-feed.sh" \
   "${SCRIPT_DIR}/misp-ipv4-feed.sh" \
   "${SCRIPT_DIR}/misp-ipv6-feed.sh" \
   "${SCRIPT_DIR}/misp-url-feed.sh" \
   "${MISP_HOME}/"
chown misp:misp "${MISP_HOME}"/*.sh "${MISP_HOME}/simple_http_server.py"
chmod +x "${MISP_HOME}/update-feeds.sh" ${MISP_HOME}/misp-*.sh

echo "==> Installing systemd service"
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=MISP Threat Intel Feed Server
After=network.target

[Service]
User=misp
WorkingDirectory=${MISP_HOME}
ExecStart=/usr/bin/python3 ${MISP_HOME}/simple_http_server.py
Restart=on-failure
RestartSec=5
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"

echo "==> Installing cron job for misp user"
# Add only if not already present
existing=$(crontab -u misp -l 2>/dev/null || true)
if echo "${existing}" | grep -qF "update-feeds.sh"; then
  echo "    (cron entry already exists, skipping)"
else
  (echo "${existing}"; echo "${CRON_LINE}") | crontab -u misp -
fi

echo "==> Running initial feed update"
sudo -u misp bash "${MISP_HOME}/update-feeds.sh" || echo "WARNING: initial feed update failed (MISP may not be reachable yet)"

echo ""
echo "==> Verifying"
sleep 2
systemctl status "${SERVICE_NAME}" --no-pager -l

echo ""
echo "==> Testing endpoints"
for feed in status misp-ipv4.txt misp-ipv6.txt misp-hashes.txt misp-urls.txt; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:40000/${feed}")
  printf "    %-25s HTTP %s\n" "/${feed}" "${code}"
done

echo ""
echo "Install complete. Logs: journalctl -u ${SERVICE_NAME} -f"
