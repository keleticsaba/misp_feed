#!/bin/bash
source /etc/misp-feed.conf

OUTPUT_FILE="${FEED_DIR}/misp-hashes.txt"
PAYLOAD='{"returnFormat":"text","type":["md5","sha1","sha256"],"category":"Payload delivery","last":"90d","enforceWarninglist":true,"to_ids":true}'

TMPFILE=$(mktemp)
curl -s \
  -d "${PAYLOAD}" \
  -H "Authorization: ${MISP_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-type: application/json" \
  -X POST \
  "${MISP_URL}/attributes/restSearch" \
  -o "${TMPFILE}"

if [ $? -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: curl failed for hash feed" >&2
  rm -f "${TMPFILE}"
  exit 1
fi

if ! grep -qE '^[0-9a-fA-F]{32}' "${TMPFILE}" 2>/dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: hash feed response looks invalid, keeping old file" >&2
  rm -f "${TMPFILE}"
  exit 1
fi

mv "${TMPFILE}" "${OUTPUT_FILE}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully updated ${OUTPUT_FILE}"
