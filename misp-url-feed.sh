#!/bin/bash
MISP_URL="https://misp14.berylia.org/attributes/restSearch"
MISP_TOKEN="ToKeN"
OUTPUT_FILE="/home/misp/feed/misp-urls.txt"
PAYLOAD='{"returnFormat":"text","type":["url","uri","domain","hostname"],"category":"Network activity","last":"90d","enforceWarninglist":true,"to_ids":true}'

curl -s \
  -d "${PAYLOAD}" \
  -H "Authorization: ${MISP_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-type: application/json" \
  -X POST \
  "${MISP_URL}" \
  -o "${OUTPUT_FILE}"

if [ $? -eq 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully updated ${OUTPUT_FILE}"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Failed to fetch MISP data" >&2
  exit 1
fi
