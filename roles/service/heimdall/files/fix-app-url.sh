#!/usr/bin/env bash

# https://github.com/linuxserver/Heimdall/issues/423#issuecomment-995246073

ENV_FILE=/config/www/.env

fix_app_url() {
  sed -i -e 's#^\(\s*APP_URL=\).*#\1'"${BASE_URL}"'#' -- "${ENV_FILE}"
}

# Give it up to 30 secs to expand the filesystem
timeout=30 ctr=0
while ! cat -- "${ENV_FILE}" &>/dev/null; do
  [ "${ctr}" -lt "${timeout}" ] || return
  (( ctr++ ))
  sleep 1
done

fix_app_url
