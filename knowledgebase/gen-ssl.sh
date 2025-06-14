#!/usr/bin/env bash

gen_ssl_conf() {
  AGE=(
    [pub_key]=''
    [secret_key]=''
  )

  CA=(
    [days]=3650     # <- Days to expire
    [cn]='My CA'    # <- Optional, leave blank to ignore
    [key]=''
    [cert]=''
  )

  CERT_DAYS=365   # <- Server certificate days to expire (better <= 1 year)
  ALT_NAMES=(
    # # EXAMPLES:
    # '*.my-test.com'       # <- First alt name will be used for CN
    # '*.test.my-test.com'  # <- Subdomain needs another record
    # 'my-test.com'
    # 'localhost'
    # '10.54.42.6'          # <- No wildcards support for IPs
    # '10.54.42.15'
  )
}

# shellcheck disable=SC2317,SC2092,SC2031
gen_ssl() (
  `# LINKS:`
  `# * https://www.youtube.com/watch?v=VH4gXcvkmOY`
  `# * https://two-oes.medium.com/working-with-openssl-and-dns-alternative-names-367f06a23841`
  `# * https://www.ibm.com/docs/en/hpvs/1.2.x?topic=reference-openssl-configuration-examples`

  declare -A AGE CA
  local CERT_DAYS
  local -a ALT_NAMES
  local CONF_FILE

  local SELF_SCRIPT=gen-ssl.sh
  grep -q '.\+' -- "${0}" 2>/dev/null && SELF_SCRIPT="$(basename -- "${0}" 2>/dev/null)"

  gen_age() {
    (set -o pipefail; age-keygen | age -e -p | base64 --wrap=0) && echo
  }

  gen_ca() {
    can_gen_ca || { echo "Can't perform 'gen-ca'. Try --help" >&2; return 1; }

    local ca_key; ca_key="$(openssl genrsa 4096)" || return
    local ca_cert; ca_cert="$(
      export KEY="${ca_key}"
      openssl req -new -x509 -days "${CA[days]}" -subj "/CN=${CA[cn]}" -key <(printenv KEY)
    )" || return

    printf -- '%s\n' "CA[key]:" "=======" >&2
    (set -o pipefail; age -e -r "${AGE[pub_key]}" <<< "${ca_key}" | base64 --wrap=0) || return
    printf -- '%s\n' '' '' "CA[cert]:" "========" >&2
    (set -o pipefail; base64 --wrap=0 <<< "${ca_cert}") || return
    echo
  }

  gen_server() {
    local -a dest=("${@}")
    local ca_key ca_cert conf_file_txt

    ca_key="$(get_ca_key)" || return
    ca_cert="$(get_ca_cert)" || return

    if [ -n "${CONF_FILE+x}" ]; then
      conf_file_txt="$(cat -- "${CONF_FILE}")" || return
    else
      conf_file_txt="$(gen_conf)"

      local alt_replace
      local ix alt record ips_count=0 dns_count=0
      for ix in "${!ALT_NAMES[@]}"; do
        alt="${ALT_NAMES[$ix]}"

        `# https://stackoverflow.com/a/35701965`
        if [[ "${alt}" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
          record="IP.${ips_count} = ${alt}"
          (( ips_count++ ))
        else
          record="DNS.${dns_count} = ${alt}"
          (( dns_count++ ))
        fi

        conf_file_txt+=$'\n'"${record}"

        if [ "${ix}" -lt 1 ]; then
          alt_replace="$(sed_escape_replace "${alt}")"
          # shellcheck disable=SC2001
          conf_file_txt="$(sed -e 's/^\(\s*commonName\s*=\).*$/\1 '"${alt_replace}"'/' <<< "${conf_file_txt}")"
        fi
      done
    fi

    local key request cert chain
    key="$(set -x; openssl genrsa 4096)" || return
    request="$(
      set -x
      openssl req -new \
        -key <(cat <<< "${key}") \
        -config <(cat <<< "${conf_file_txt}")
    )" || return
    cert="$(
      set -x
      openssl x509 -req \
        -days "${CERT_DAYS}" \
        -extensions 'v3_req' \
        -extfile <(cat <<< "${conf_file_txt}") \
        -in <(cat <<< "${request}") \
        -CA <(cat <<< "${ca_cert}") \
        -CAkey <(cat <<< "${ca_key}")
    )" || return
    chain="$(
      `# https://serverfault.com/a/755815 <- In case CA cert is chain of certs`
      openssl crl2pkcs7 -nocrl -certfile <(cat <<< "${cert}"$'\n'"${ca_cert}") \
      | openssl pkcs7 -print_certs | sed -e '/^\s*\(subject\|issuer\)=/d' -e '/^\s*$/d'
    )" || return

    (set -x; openssl verify -CAfile <(cat <<< "${ca_cert}") <(cat <<< "${chain}") >&2) || return

    [[ "${#dest[@]}" -lt 1 ]] && {  # <- Print to stdout
      printf -- '%s\n' "${key}" "${chain}"
      return
    }

    local dest_prefix="${dest[0]}"
    local dest_dir; dest_dir="$(dirname -- "${dest_prefix}")"

    (set -x; mkdir -p -- "${dest_dir}") && {
      local key_file="${dest_prefix}.key"
      (
        set -x
        touch -- "${key_file}" \
        && chmod '0600' -- "${key_file}" \
        && tee -- "${dest_prefix}.key" <<< "${key}" >/dev/null
      )
    } && {
      printf -- '%s\n' "${chain}" | (set -x; tee -- "${dest_prefix}.crt" >/dev/null)
    }
  }

  gen_conf() {
    print_nice "
      [req]
      prompt                 = no
      days                   = 365
      distinguished_name     = req_distinguished_name
      req_extensions         = v3_req
     ,
      [req_distinguished_name]    # <- Uncomment / add / edit any that are required
      commonName             = CHANGEME   # <- (REQUIRED)
      # countryName            = AB
      # stateOrProvinceName    = CD
      # localityName           = EFG_HIJ
      # organizationName       = MyOrg
      # organizationalUnitName = MyOrgUnit
      # emailAddress           = emailaddress@myemail.com
     ,
      [v3_req]
      basicConstraints       = CA:false
      extendedKeyUsage       = clientAuth, serverAuth
      subjectAltName         = @sans
     ,
      [sans]                        # <- Domains and IPs here
      # # EXAMPLES:
      # DNS.0 = *.my-test.com
      # DNS.1 = *.test.my-test.com  # <- Subdomain needs another record
      # DNS.2 = my-test.com
      # DNS.3 = localhost
      # IP.0 = 10.54.42.6           # <- No wildcards support for IPs
      # IP.1 = 10.54.42.15
    "
  }

  get_ca_cert() {
    [ -n "${CA[cert]}" ] || { echo "CA[cert] not configured. Try --help" >&2; return 1; }
    base64 -d <<< "${CA[cert]}"
  }

  get_ca_key() {
    [ -n "${AGE[secret_key]}" ] || { echo "AGE[secret_key] not configured. Try --help" >&2; return 1; }
    [ -n "${CA[key]}" ] || { echo "CA[key] not configured. Try --help" >&2; return 1; }

    local age_secret ca_key

    age_secret="$(base64 -d <<< "${AGE[secret_key]}" | age -d)" || return
    base64 -d <<< "${CA[key]}" | age -d -i <(cat <<< "${age_secret}")
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
      [gen-server]=gen_server
      [ca-cert]=get_ca_cert
      [ca-key]=get_ca_key
    )
    declare commands_rex
    commands_rex="$(printf -- '%s\|' "${!commands_map[@]}" | sed 's/\\|$//')"
    grep -qx "\(${commands_rex}\)" <<< "${CMD}" && { echo "${commands_map[${CMD}]}"; return; }

    # Check if conf-file, i.e. generate server cert
    grep -q '\.\(cnf\|conf\)$' <<< "${CMD}" && { echo gen_server; return; }

    echo "Invalid command: '${CMD}'. Try --help" >&2
    return 1
  }

  print_help() {
    local conffile=./ssl.cnf
    local bundle_file=bundle.pem
    local prefix=./my-cert

    local usage="
      # Generate age public (stderr) and secret (stdout) keys and put them to the
      # conf section of the current script. Prompts for password for
      ${SELF_SCRIPT} gen-age
     ,
      # Generate CA key / cert and put them to the conf section of the current script
      ${SELF_SCRIPT} gen-ca
     ,
      # Generate and edit cert configuration file (*.conf or *.cnf)
      ${SELF_SCRIPT} gen-conf > ${conffile}
     ,
      # Generate server key / cert based on ${conffile}
      ${SELF_SCRIPT} ${conffile} > ${bundle_file}   # Ensure \`chmod '0600' ${bundle_file}\` after that
     ,
      # Alternative to:
      #   ${SELF_SCRIPT} gen-conf > ${conffile}; ${SELF_SCRIPT} ${conffile}
      # Fill ALT_LIST in the conf section of the current script and execute:
      ${SELF_SCRIPT} gen-server > ${bundle_file}   # Ensure \`chmod '0600' ${bundle_file}\` after that
     ,
      # To put to separate '${prefix}.crt' and '${prefix}.key' files instead of
      # '${bundle_file}' (no extension for ${prefix}):
      ${SELF_SCRIPT} ${conffile} ${prefix}   # <- For configuration file
      ${SELF_SCRIPT} gen-server ${prefix}  # <- For ALT_LIST in the conf section
     ,
      # Print current script CA cert (to import it to some client for example).
      #   Google Chrome: > chrome://certificate-manager/localcerts/usercerts
      #   Firefox: Firefox > about:preferences#privacy -> Security section
      #       -> Certificates section -> View Certificates ...
      #   Android: > Settings -> Security & privacy -> More security & privacy ->
      #       -> Credential storage ...
      #   Debian / Ubuntu
      #       \`\`\`sh
      #       sudo cp CERT_FILE /usr/local/share/ca-certificates
      #       sudo update-ca-certificates
      #       \`\`\`
      ${SELF_SCRIPT} ca-cert
      ${SELF_SCRIPT} ca-cert > ./ca.crt     # <- Redirect to a file for ease of use
     ,
      # You can check the full generated cert chain info:
      openssl crl2pkcs7 -nocrl -certfile CERT_FILE | openssl pkcs7 -print_certs -text -noout
    "

    if can_gen_server_with_conf_section; then
      usage="
        # NOTE:
        #   The current script contains all required configurations for 'gen-server'.
        #   Skip steps up to 'gen-server' if you are fine with the conf section.
        #   Configured ALT_NAMES:
        $(
          printf -- '#     * "%s"\n' "${ALT_NAMES[@]}" \
          | sed -e '0,/$/ s/$/  # <- Will be used for CN/'
        )
      "$'\n,\n'"${usage}"
    elif can_gen_conf; then
      usage="
        # NOTE:
        #   The current script contains all required configurations for 'gen-conf'.
        #   Skip steps up to 'gen-conf' if you are fine with the conf section.
      "$'\n,\n'"${usage}"
    fi

    print_nice "
      COMMANDS:
      ========
      gen-age     # Generate age keys
      gen-ca      # Generate CA to stdout
      gen-server  # Generate server certificates with ALT_NAMES from the script
      CONF_FILE   # Generate server certificates from CONF_FILE (*.cnf or *.conf)
      gen-conf    # Generate configuration file to stdout
      ca-cert     # Print CA cert to stdout
     ,
      USAGE:
      =====
      ${usage}
    "
  }

  can_gen_ca() { [ -n "${AGE[pub_key]}" ] && [ -n "${AGE[secret_key]}" ]; }
  can_gen_conf() { can_gen_ca && [ -n "${CA[key]}" ] && [ -n "${CA[cert]}" ]; }
  can_gen_server_with_conf_section() { can_gen_conf && [ ${#ALT_NAMES[@]} -gt 0 ]; }

  #
  # Helpers
  #
  print_nice() { sed -e 's/^\s*$//' -e '/^$/d' -e 's/^\s*//' -e 's/^,//' <<< "${1-$(cat)}"; }
  # https://gist.github.com/varlogerr/2c058af053921f1e9a0ddc39ab854577#file-sed-quote
  sed_escape_pattern() { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
  sed_escape_replace() { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

  main() {
    local endpoint

    gen_ssl_conf
    endpoint="$(get_endpoint "${@:1:1}")"  || return 1

    grep -q '\.\(cnf\|conf\)$' <<< "${1}" && CONF_FILE="${1}"
    "${endpoint}" "${@:2}" || return 1
  }

  main "${@}"
)

(return 2>/dev/null) || gen_ssl "${@}"
