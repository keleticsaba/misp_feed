#!/bin/bash
source /etc/misp-feed.conf

OUTPUT_FILE="${FEED_DIR}/misp-ipv4.txt"
PAYLOAD='{"returnFormat":"text","type":["ip-src","ip-dst"],"category":"Network activity","last":"90d","enforceWarninglist":true,"to_ids":true}'

TMPFILE=$(mktemp)
curl -s \
  -d "${PAYLOAD}" \
  -H "Authorization: ${MISP_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-type: application/json" \
  -X POST \
  "${MISP_URL}" \
  -o "${TMPFILE}"

if [ $? -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: curl failed for IPv4 feed" >&2
  rm -f "${TMPFILE}"
  exit 1
fi

# Filter only IPv4 lines (including CIDR notation), discard IPv6
FILTERED=$(mktemp)
grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]+)?$' "${TMPFILE}" > "${FILTERED}"
rm -f "${TMPFILE}"

if [ ! -s "${FILTERED}" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: IPv4 feed response looks invalid, keeping old file" >&2
  rm -f "${FILTERED}"
  exit 1
fi

mv "${FILTERED}" "${OUTPUT_FILE}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully updated ${OUTPUT_FILE}"
