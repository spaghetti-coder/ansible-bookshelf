#!/bin/bash

HEALTHY='true'
wget --spider -q http://127.0.0.1:9002/healthz || HEALTHY='false'

curl -sS --max-time 5 -X POST \
  --header "Authorization: Bearer ${GATUS_TOKEN}" \
  "${GATUS_URL}/api/v1/endpoints/${GATUS_KEY}/external?success=${HEALTHY}"
