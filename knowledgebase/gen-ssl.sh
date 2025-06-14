#!/usr/bin/env bash

gen_ssl_conf() {
  CA_KEY=''
  CA_CERT=''

  # AGE_PUB_KEY: age1atkdw5w3uar09eguccqjr90pt7h6wyyr5frm953saa5s0c7pwgqs50348n
  # Generate with:
  #   `# Gen pub key to &2 and secret to &1 | Encrypt with passphrase | Convert to text format`
  #   age-keygen | age -e -p | base64 --wrap=0
  # Put resulting stdout to 'age_key' and use pub key to encrypt secret data:
  #   age -e -r AGE_PUB_KEY < secret.txt | base64 --wrap=0
  # Decrypt with reveal_secret function
  #   echo ENCRYPTED_SECRET | reveal_secret
  AGE=(
    [pub_key]=''
    [secret_key]=''
  )
}

# shellcheck disable=SC2317
gen_ssl() (
  local CA_KEY CA_CERT
  local SELF_SCRIPT="${0}"
  declare -A AGE

  gen_ssl_conf

  get_endpoint() {
    [ -n "${1+x}" ] || {
      echo 'Command required. Try --help' >&2
      return 1
    }

    [[ "${1}" =~ ^-\?|-h|--help$ ]] && { echo print_help; return; }

    echo 'Invalid command. Try --help' >&2
    return 1
  }

  print_help() {
    echo "
      USAGE:
        # Generate age public and secret age keys and put
        # them to the current script
        gen-age

    "
  }

  main() {
    local endpoint

    endpoint="$(get_endpoint "${@:1:1}")" || return 1
    "${endpoint}" "${@:2}" || return 1
  }

  main "${@}"
)

(return 2>/dev/null) || gen_ssl "${@}"
