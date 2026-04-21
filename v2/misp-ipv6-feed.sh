#!/bin/bash
source /etc/misp-feed.conf

OUTPUT_FILE="${FEED_DIR}/misp-ipv6.txt"
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
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: curl failed for IPv6 feed" >&2
  rm -f "${TMPFILE}"
  exit 1
fi

# Filter only IPv6 lines (must contain at least one colon), discard IPv4
FILTERED=$(mktemp)
grep -E '^[0-9a-fA-F:]+:[0-9a-fA-F:]*(/[0-9]+)?$' "${TMPFILE}" > "${FILTERED}"
rm -f "${TMPFILE}"

if [ ! -s "${FILTERED}" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: no IPv6 indicators returned (feed may be legitimately empty)" >&2
  rm -f "${FILTERED}"
  # Write empty file so consumers get a valid (empty) feed rather than stale data
  > "${OUTPUT_FILE}"
  exit 0
fi

mv "${FILTERED}" "${OUTPUT_FILE}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully updated ${OUTPUT_FILE}"
