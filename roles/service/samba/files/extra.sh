#!/usr/bin/with-contenv bash
# shellcheck shell=bash

json_conf() {
  yq --output-format=json e '(.. | select(tag == "!!str")) |= envsubst' "${CONFIG_FILE}" 2>/dev/null
}

if [[ "$(json_conf | jq '.groups')" != "null" ]]; then
  for group in $(json_conf | jq -r '.groups[] | @base64'); do
    _jq() { echo "${group}" | base64 --decode | jq -r "${1}"; }
    name=$(_jq '.name')
    gid=$(_jq '.gid')

    echo "Creating group ${name} ${gid}"
    getent group "${gid}" &>/dev/null || getent group "${gid}" "${name}" &>/dev/null || addgroup -g "${gid}" -S "${name}"
  done
fi

if [[ "$(json_conf | jq '.auth')" != "null" ]]; then
  for auth in $(json_conf | jq -r '.auth[] | @base64'); do
    _jq() { echo "${auth}" | base64 --decode | jq -r "${1}"; }
    [[ "$(_jq '.groups')" == "null" ]] && continue

    echo "Adding user $(_jq '.user') to groups $(_jq '.groups')"
    usermod -aG "$(_jq '.groups')" "$(_jq '.user')"
  done
fi
