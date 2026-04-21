#!/bin/bash
source /etc/misp-feed.conf

OUTPUT_FILE="${FEED_DIR}/misp-urls.txt"
PAYLOAD='{"returnFormat":"text","type":["url","uri","domain","hostname"],"category":"Network activity","last":"90d","enforceWarninglist":true,"to_ids":true}'

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
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: curl failed for URL feed" >&2
  rm -f "${TMPFILE}"
  exit 1
fi

if ! grep -qE '^https?://|^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+' "${TMPFILE}" 2>/dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: URL feed response looks invalid, keeping old file" >&2
  rm -f "${TMPFILE}"
  exit 1
fi

mv "${TMPFILE}" "${OUTPUT_FILE}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully updated ${OUTPUT_FILE}"
