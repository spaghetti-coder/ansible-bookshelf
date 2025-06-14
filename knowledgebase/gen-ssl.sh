#!/usr/bin/env bash

gen_ssl_conf() {
  AGE=(
    [pub_key]='age1kzwptyqnh466ns5xw7m2zmaexlgl9vmyelz92we7uktuffkfep7qm7yrl4'
    [secret_key]='YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IHNjcnlwdCBkMTlZZ0FKT0ZUbU5YYy92amJwZTR3IDE4Ckh5L2NQcDdxSHh6Q2VIVzFYdUp4WXlzZUJVSHdUOWw0b3RNdmVaVWlXZXcKLS0tIG43NHBNeW1rcXBQZzQyYXE4bXc4V25neUc4Z3ZtTmhkU3liZSsrZDkwZzgKhhjnSWBIE/2HgeZe3ndbSuIgpiFnnSWIM+H5FbClyDl2K1ndhd+kWShyJ3WMc3VLGW8fD4jCNit6qZ/7ZbbZJ9Ee3svyCm6FMLyJtuDySbTEmRipQOlgQ/M3eyOGNAT/+n3WYpHgPnmD4N5TuMBn/0jvxKmZZTNrg7ckNsntvOQqVSjxAqSO0SdBjGMH+a9g2RcsqbEJbTsFi2pQHmrRXqsrJyXHRN0ILHdHi02KAv4m7wJdmKkusG36yr8TYrjofCon78J/f8rzFPpUuorS/PHPLOnyoEx59AJfS7M='
  )

  CA_KEY='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'
  CA_CERT='LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZBVENDQXVtZ0F3SUJBZ0lVRzRjZUNYVkRHSFo2SjE5M1AzYXJHUExNc2Uwd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0VERU9NQXdHQTFVRUF3d0ZUWGtnUTBFd0hoY05NalV3TmpFME1UWXdOREE1V2hjTk16VXdOakV5TVRZdwpOREE1V2pBUU1RNHdEQVlEVlFRRERBVk5lU0JEUVRDQ0FpSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnSVBBRENDCkFnb0NnZ0lCQUtSRFg2dExJWFNvTSs3dEl4ODdZU0N2OTVnK2tZbnp0WFJCTk9qeTlTc2E3RkhyRjltRnN1dmsKNDZqM1ZSMlJvQkkxeUR6VzZQNkFiT2lIck4zdEdwNFV0OVdMV2NlRUJnb3pIdjhsS1pPU01PZ1FrS3kwRHRJQgpIRGx1eGxjRTFsbGpWMDhaaGpYSTdSSE02RXdDS0RNajIzbVN4YlNEY3I3b2poeHA1a0pIVS9NdCtaV0o5U2dXCjlFYnNtMU1zN0dURTJrZDVzNS9mcnowZG9kbEo3VEpWVEVDZ0RXckRrS21TcUg4NWFNb1lIaUhwR29FS0NBZjIKQStpWWt5MEFVekgzRWZaTUVyQzNDdUVYS3lvM1RTaVdkRkhhaEVTWm5sZzFQZTZEVWJxU09YVjlEOTVkTlJVOApHZ0lMbVJEejJiajVHUDNtS2RJS0JyZjRqTWorbkVmVzhVT2FwVS9GMlozMTloOFRxcnNuY3BLTWpsQkdDeHNqCmVKaEFYdnI5Z3Z2djFUN0tkdWxLR2Z2c0lLV1NpNXJyZVhWcXlHazJveklnOGlFek95Z09kUWxBZk4rS2JOL1AKTG4yQW1BaDJxN3ZUZk5nUkVETHFDekdUUDhYMWh4UUlSMHhvTmdjOTR5UldvZWtPRU9oejdaZm00OWRSazhwdgo4WG54TjFWZTNQVC9nWWtKNUc5ZmM1eFVDQ05oVjViNS9TOEMyMnZTRGhzczJTOCtZY04wNEtxcFFNRXFRSXAwCm9XV0hMQzJlTUt0WER0QnBtODRUVFdYSHRySm5LWTJVaWhvTnpNUmNOa0NBazg5Yzg1Mkx4dmhEL3UvUEVhUVgKZFFnWStSSXRrOVh0N2pJNmlueDRQeFQyZWZpd2tkQ3drVW1reVJCTG5NQnZraFU2aVhOdkFnTUJBQUdqVXpCUgpNQjBHQTFVZERnUVdCQlIrVnFtVjBmU0VzbXVKMTVKQzdPTkRBbENCZkRBZkJnTlZIU01FR0RBV2dCUitWcW1WCjBmU0VzbXVKMTVKQzdPTkRBbENCZkRBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUEwR0NTcUdTSWIzRFFFQkN3VUEKQTRJQ0FRQ1ZnTHUvSFJtTXZHYmFyQ1BoWmlFVHdZcjZYdDFFcm9sM0ZzblVrOTNJaEsxU0V1TWw0TnFLTnR0QwpZWGFVNkRIZWMyaHNxSnFjK0tjN1V0cUMyMDBrbS9SNWVlOUhoWVRZZ283QzQ4UnFaekVUZmdVakRnMzFuKzk3CnFVanZDQjZKUGNWM3l6ZTcvOTgvdzJIMHZlNWdyV0FQVjdEQVNxa3dncjdxUk9MRWV0c2tuWFdhdUFOak1BbVQKQ1BlOHh5YnpTQmhTejNKSC9uMExjb3NuczFLMlo0KzYwRkg1bUp1K2NLbFlsUXFJdmJhenZxUlZHaHlPeEs3SgoyQkJhRTAvbktDSUZVYVArSjg0U21uT2xCaHBJVGl5Qis3K2UxUFBTcnpyN3BjS2RYa3lReXJxaUpOYXVwZ1JNCldoZ2dEdmlleDAxVWpmYUNJNXM1VzdONUZkS1hiSW1hdmkrOGxnM1pXSUNFMlI5NzZQN2Y4RmRsb0N3ZENJcGsKOGdPb2c1c0YzazllYkhzTis0djIzTDg3bEc1K29zVHZ5ZEdGYk1Fd0JjKzd6SkMzcCt1SkhaVUUwWVg0b0N0UgphMFhCdWx5SmRER3BqbTN0U1ZuUzBJUnVrbjlHK0t2VlRrakRoMk1RNjRzQ2lOckFOYm8wS3U1SWNjclIxL2NiClNRMFBna3hzQzZyb2NFU3VwQm5uc050YXpIS2NqWlgyVlFKdEYvUWJuUnhXbTdQekJybmRCUjN2cGI5cUFveWkKVzlReHpQSm15L0dIUFNBaUJBMktQZktEMGdJN2ZWN1ZYMzhjSlF3UDRPZEdMNkpXcER1SWsxQjBvUXZxdkxMWQovV0U1TStQeXA0NFBaMTU2dmx1dXpkUXJJdjNhNGV0MVZVS1pCSTBhS0pCeVl1T2twZz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K'

  CA_DAYS=3650    # <- Days to expire
  CA_CN='My CA'   # <- Optional, leave blank to ignore
  CERT_DAYS=365   # <- Server certificate days to expire (better <= 1 year)
}

# shellcheck disable=SC2317
gen_ssl() (
  local CA_DAYS CA_CN CA_KEY CA_CERT CERT_DAYS
  local SELF_SCRIPT=gen-ssl.sh
  local CONF_FILE
  declare -A AGE

  gen_age() {
    (set -o pipefail; age-keygen | age -e -p | base64 --wrap=0) && echo
  }

  gen_ca() {
    [ -n "${AGE[pub_key]+x}" ] || {
      echo "pub_key not configured for age. Try --help" >&2
      return 1
    }

    local ca_key; ca_key="$(openssl genrsa 4096)" || return
    local ca_cert; ca_cert="$(
      export CA_KEY="${ca_key}"
      openssl req -new -x509 -days "${CA_DAYS}" -subj "/CN=${CA_CN}" -key <(printenv CA_KEY)
    )" || return

    printf -- '%s\n' "CA KEY:" "======" >&2
    (set -o pipefail; age -e -r "${AGE[pub_key]}" <<< "${ca_key}" | base64 --wrap=0) || return
    printf -- '%s\n' '' '' "CA CERT:" "=======" >&2
    (set -o pipefail; base64 --wrap=0 <<< "${ca_cert}") || return
    echo
  }

  ca_cert() {
    [ -n "${CA_CERT+x}" ] || {
      echo "CA_CERT not configured. Try --help" >&2
      return 1
    }

    base64 -d <<< "${CA_CERT}"
  }

  get_endpoint() {
    [ -n "${1+x}" ] || {
      echo 'Command required. Try --help' >&2
      return 1
    }

    declare CMD="${1}"

    # Check if help
    [[ "${CMD}" =~ ^-\?|-h|--help$ ]] && { echo print_help; return; }

    # Check if one of map commands
    declare -A commands_map=(
      [gen-age]=gen_age
      [gen-ca]=gen_ca
      [gen-conf]=gen_conf
      [ca-cert]=ca_cert
    )
    declare commands_rex
    commands_rex="$(printf -- '%s\|' "${!commands_map[@]}" | sed 's/\\|$//')"
    grep -qx "\(${commands_rex}\)" <<< "${CMD}" && { echo "${commands_map[${CMD}]}"; return; }

    # Check if conf-file, i.e. generate server cert
    grep -q '\.\(cnf\|conf\)$' <<< "${CMD}" && { CONF_FILE="${CMD}"; echo gen_server; return; }

    echo "Invalid command: '${CMD}'. Try --help" >&2
    return 1
  }

  print_help() {
    echo "
      USAGE:
      =====
      # Generate age public (stderr) and secret (stdout) keys and put them to the
      # conf section of the current script. Prompts for password for
      ${SELF_SCRIPT} gen-age
     ,
      # Generate CA key / cert and put them to the conf section of the current script
      ${SELF_SCRIPT} gen-ca
     ,
      TODO: missed steps here
     ,
      # Print current script CA cert (to import it to some client for example)
      ${SELF_SCRIPT} ca-cert
      ${SELF_SCRIPT} ca-cert > ./ca.crt     # <- Redirect to a file for ease of use
    " | sed -e 's/^\s*$//' -e '/^$/d' -e 's/^\s*//' -e 's/^,//'
  }

  main() {
    local endpoint

    gen_ssl_conf
    endpoint="$(get_endpoint "${@:1:1}")" || return 1
    "${endpoint}" "${@:2}" || return 1
  }

  main "${@}"
)

(return 2>/dev/null) || gen_ssl "${@}"
