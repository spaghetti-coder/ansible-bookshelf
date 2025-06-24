#!/usr/bin/env bash

gen_ssl_conf() {
  # CA cert configuration
  CA=(              # <- CA data to be used for server certs generation
    [bundle]=''
    [days]=3650     # <- Days to expire
    [cn]='My CA'    # <- Optional, leave blank to ignore
  )

  # Server cert configuration
  DAYS=365          # <- Server certificate days to expire (better <= 1 year)
  ALT_NAMES=(       # <- REQUIRED at least one either here or in *.conf file
    # # EXAMPLES:
    # '*.my-test.com'       # <- First alt name will be used for CN
    # '*.test.my-test.com'  # <- Subdomain needs another record
    # 'my-test.com'
    # 'localhost'
    # '10.54.42.6'          # <- No wildcards support for IPs
    # '10.54.42.15'
  )
  # Output server cert file prefix to generate *.crt, *.key files. I.e. with
  # PREFIX="${HOME}/my" `gen-ssl.sh gen-server` generates to "${HOME}/my.crt"
  # and "${HOME}/my.key", while `gen-ssl.sh gen-server "${HOME}/your"` generates
  # to "${HOME}/your.crt" and "${HOME}/your.key"
  PREFIX=""         # <- Optional

  # age tool is REQUIRED! https://github.com/FiloSottile/age
  # If it is not available in PATH, you can configure it here. Ex.:
  #   [age_bin]="${HOME}/app/age" [age_keygen_bin]="${HOME}/spp/age-keygen"
  AGE=(
    [age_bin]=''
    [age_keygen_bin]=''
  )
}


# ==================== END OF CONFIGURATION ZONE ====================


# shellcheck disable=SC2317,SC2092,SC2031
gen_ssl() (
  `# LINKS:`
  `# * https://www.youtube.com/watch?v=VH4gXcvkmOY`
  `# * https://two-oes.medium.com/working-with-openssl-and-dns-alternative-names-367f06a23841`
  `# * https://www.ibm.com/docs/en/hpvs/1.2.x?topic=reference-openssl-configuration-examples`

  declare -A AGE CA
  local DAYS PREFIX
  local -a ALT_NAMES
  local CONF_FILE HELP_NOTE_PRINTED=false

  local SELF_SCRIPT=gen-ssl.sh
  grep -q '.\+' -- "${0}" 2>/dev/null && SELF_SCRIPT="$(basename -- "${0}" 2>/dev/null)"

  gen_ca() {
    local pub_key_rex='public\s\+key\s*:'
    local age_secret; age_secret="$( (
      `# https://stackoverflow.com/a/16126777`
      set -o pipefail; (_age_keygen 3>&2 2>&1 1>&3) | sed -e '1!b' -e '/^\s*'"${pub_key_rex}"'/Id'
    ) 3>&2 2>&1 1>&3 )" || return
    local age_public; age_public="$(
      grep -i '^#\s*'"${pub_key_rex}" <<< "${age_secret}" \
      | sed -e 's/^[^:]\+:\s*//'
    )" || return

    local ca_key; ca_key="$(openssl genrsa 4096)" || return
    local ca_cert; ca_cert="$(
      export ca_key
      openssl req -new -x509 -days "${CA[days]}" -subj "/CN=${CA[cn]}" -key <(printenv ca_key)
    )" || return

    # By lines:
    # 1. Age public plain
    # 2. Age secret       | age-password-encode       | base64-single-line-encode
    # 3. CA cert          | base64-single-line-encode
    # 4. CA key           | age-public-encode         | base64-single-line-encode
    # And all thes lines  | base64-single-line-encode

    local lines
    lines+="${age_public}" \
      && lines+=$'\n'"$(set -o pipefail; _age -e -p <<< "${age_secret}" | base64 --wrap=0)" \
      && lines+=$'\n'"$(base64 --wrap=0 <<< "${ca_cert}")" \
      && lines+=$'\n'"$(set -o pipefail; _age -e -r "${age_public}" <<< "${ca_key}" | base64 --wrap=0)" \
    || return

    base64 --wrap=0 <<< "${lines}" || return
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
      local days_repl; days_repl="$(sed_escape_replace "${DAYS}")"
      conf_file_txt="$(gen_conf | sed -e 's/^\(\s*certDays\s*=\).*/\1 '"${days_repl}"'/')" || return

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

    # Get days from the conf
    local days; days="$(
      line_rex='^\s*certDays\s*='

      grep "${line_rex}" <<< "${conf_file_txt}" | head -n 1 \
      | sed -e 's/\s*=\s*/=/' | sed -e 's/'"${line_rex}"'\([^ #;]*\).*/\1/'
    )"

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
        -days "${days}" \
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

    # Ensure destination if configured somewhere
    [ "${#dest[@]}" -lt 1 ] && [ -n "${PREFIX}" ] && dest=("${PREFIX}")

    [ "${#dest[@]}" -lt 1 ] && {  # <- Print to stdout
      printf -- '%s\n' "${key}" "${chain}"
      return
    }

    local dest_prefix="${dest[0]}"
    local dest_dir; dest_dir="$(dirname -- "${dest_prefix}")"

    (set -x; mkdir -p -- "${dest_dir}") && {
      printf -- '%s\n' "${chain}" | (set -x; tee -- "${dest_prefix}.crt" >/dev/null)
    } && {
      local key_file="${dest_prefix}.key"
      (
        set -x
        touch -- "${key_file}" \
        && chmod '0600' -- "${key_file}" \
        && tee -- "${key_file}" <<< "${key}" >/dev/null
      )
    }
  }

  gen_conf() {
    print_nice "
      certDays  = 365   # <- Server certificate days to expire (better <= 1 year)
     ,
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
      [sans]                        # <- REQUIRED at least one. Domains and IPs here
      # # EXAMPLES:
      # DNS.0 = *.my-test.com
      # DNS.1 = *.test.my-test.com  # <- Subdomain needs another record
      # DNS.2 = my-test.com
      # DNS.3 = localhost
      # IP.0 = 10.54.42.6           # <- No wildcards support for IPs
      # IP.1 = 10.54.42.15
    "
  }

  get_ca_bundle_lines() {
    [ -n "${CA[bundle]}" ] || { echo "CA[bundle] not configured. Try --help" >&2; return 1; }
    base64 -d <<< "${CA[bundle]}"
  }

  get_age_pub() {
    (set -o pipefail; get_ca_bundle_lines | sed -n '1p')
  }

  get_age_secret() {
    local lines; lines="$(get_ca_bundle_lines)" || return
    (set -o pipefail; sed -n '2p' <<< "${lines}" | base64 -d | _age -d)
  }

  get_ca_cert() {
    local lines; lines="$(get_ca_bundle_lines)" || return
    (set -o pipefail; sed -n '3p' <<< "${lines}" | base64 -d)
  }

  get_ca_key() {  `# <- Wants passphrase`
    local lines; lines="$(get_ca_bundle_lines)" || return
    local age_secret; age_secret="$(get_age_secret)" || return

    ( set -o pipefail
      sed -n '4p' <<< "${lines}" | base64 -d \
      | _age -d -i <(cat <<< "${age_secret}")
    ) || return
  }

  get_endpoint() {
    [ -n "${1+x}" ] || {
      echo 'Command required. Try --help' >&2
      return 1
    }

    declare CMD="${1}"

    # Check if help
    case "${CMD}" in
      -\?|-h|--help ) echo print_help; return ;;
      --short       ) echo print_help_short; return ;;
      --usage       ) echo print_help_usage; return ;;
      --import      ) echo print_help_import; return ;;
    esac

    # Check if one of map commands
    declare -A commands_map=(
      [gen-ca]=gen_ca
      [gen-conf]=gen_conf
      [gen-server]=gen_server
      [ca-cert]=get_ca_cert
      [ca-key]=get_ca_key
      [age-pub]=get_age_pub
      [age-secret]=get_age_secret
    )
    declare commands_rex
    commands_rex="$(printf -- '%s\|' "${!commands_map[@]}" | sed 's/\\|$//')"
    grep -qx "\(${commands_rex}\)" <<< "${CMD}" && { echo "${commands_map[${CMD}]}"; return; }

    # Check if conf-file, i.e. generate server cert
    grep -q '\.\(cnf\|conf\)$' <<< "${CMD}" && { echo gen_server; return; }

    echo "Invalid command: '${CMD}'. Try --help" >&2
    return 1
  }

  print_help_import() {
    print_nice "
      Google Chrome: > chrome://certificate-manager/localcerts/usercerts
      Firefox: Firefox > about:preferences#privacy -> Security section ->
     ,    -> Certificates section -> View Certificates ...
      Android: > Settings -> Security & privacy -> More security & privacy ->
     ,    -> Credential storage ...
      Debian / Ubuntu:
     ,  \`\`\`sh
     ,  sudo cp CERT_FILE /usr/local/share/ca-certificates
     ,  sudo update-ca-certificates
     ,  \`\`\`
    "
  }

  print_help_note() {
    ${HELP_NOTE_PRINTED} && return 1
    HELP_NOTE_PRINTED=true

    if can_gen_server_with_conf_section; then
      print_nice "
        NOTE:
        ====
        The current script is ready for 'gen-server'. Skip steps up to 'gen-server'
        if you are fine with the conf section. Configured ALT_NAMES:
        $(
          printf -- ',  * "%s"\n' "${ALT_NAMES[@]}" \
          | sed -e '0,/$/ s/$/  # <- Will be used for CN/'
        )
      "

      if [ -n "${PREFIX}" ]; then
        print_nice "
          PREFIX configured to '${PREFIX}'.
          With \`${SELF_SCRIPT} gen-server\` will generate:
         ,  * '${PREFIX}.crt'
         ,  * '${PREFIX}.key'
        "
      fi

      return 0
    elif can_gen_conf; then
      print_nice "
        NOTE:
        ====
        The current script is ready for 'gen-conf'. Skip steps up to 'gen-conf' if
        you are fine with the conf section. If you have a server cert config file
        proceed to \`${SELF_SCRIPT} CONF_FILE\`.
      "

      if [ -n "${PREFIX}" ]; then
        print_nice "
          PREFIX configured to '${PREFIX}'.
          With \`${SELF_SCRIPT} CONF_FILE\` will generate:
         ,  * '${PREFIX}.crt'
         ,  * '${PREFIX}.key'
        "
      fi

      return 0
    fi

    return 1
  }

  print_help_usage() {
    local conffile=./ssl.cnf
    local bundle_file=bundle.pem
    local prefix=./my-cert

    print_help_note && echo
    print_nice "
      USAGE:
      =====
      # Generate passphrase encrypted CA key / cert encrypted bundle and put it
      # to CA[bundle] in the conf section of the current script
      ${SELF_SCRIPT} gen-ca
     ,
      # Generate and edit cert configuration file (*.conf or *.cnf)
      ${SELF_SCRIPT} gen-conf > ${conffile}   # After that \`vim ${conffile}\` and edit
     ,
      # Generate server SSL key / cert based on ${conffile}. Prompts for CA[bundle]
      # passphrase to decrypt age secret key that decrypts CA key
      ${SELF_SCRIPT} ${conffile} > ${bundle_file}   # Ensure \`chmod '0600' ${bundle_file}\` after that
     ,
      # Less flexible, but simpler for maintenance alternative to:
      #   ${SELF_SCRIPT} gen-conf > ${conffile}; \`# Edit ${conffile}\`; ${SELF_SCRIPT} ${conffile}
      # Fill ALT_NAMES in the conf section of the current script and execute:
      ${SELF_SCRIPT} gen-server > ${bundle_file}   # Ensure \`chmod '0600' ${bundle_file}\` after that
     ,
      # Use FILE_PREFIX to put to separate '${prefix}.crt' and '${prefix}.key'
      # files instead of '${bundle_file}' (Note: no extension for FILE_PREFIX).
      # Same can be done by setting PREFIX in the script conf section, then no
      # inline FILE_PREFIX needed
      ${SELF_SCRIPT} ${conffile} ${prefix}   # <- For configuration file
      ${SELF_SCRIPT} gen-server ${prefix}  # <- For ALT_NAMES in the conf section
     ,
      # Print current script CA cert (to import it to some client for example).
      # '--import' flag to learn more
      ${SELF_SCRIPT} ca-cert
      ${SELF_SCRIPT} ca-cert > ./ca.crt     # <- Redirect to a file for ease of use
     ,
      # You can check the full generated cert chain info:
      openssl crl2pkcs7 -nocrl -certfile CERT_FILE | openssl pkcs7 -print_certs -text -noout
    "
  }

  print_help_short() {
    print_help_note && echo

    print_nice "
      COMMANDS:
      ========
      gen-ca      # Generate passphrase protected CA bundle to stdout
      gen-conf    # Generate configuration file to stdout
      gen-server  # Generate server certificates with ALT_NAMES from the script
      CONF_FILE   # Generate server certificates from CONF_FILE (*.cnf or *.conf)
      ca-cert     # Print CA cert to stdout
      age-pub     # Print age public key
      # For private and development needs mostly:
      ca-key      # Print CA private key
      age-secret  # Print age secret key. Wants passphrase
    "
  }

  print_help() {
    print_nice "
      Keep encrypted CA and server cert configuration in a single file, that allows
      server certs generation with a single command. Alternatively server cert
      configuration can be placed to a separate file.
      Requires age tool installed: https://github.com/FiloSottile/age
    "; echo

    print_help_note && echo

    print_nice "
      --short     Print only commands
      --usage     Print only usage section
      --import    Print CA cert import instructions
    "; echo

    print_help_short; echo
    print_help_usage
  }

  can_gen_conf() { [ "$(get_ca_bundle_lines 2>/dev/null | wc -l)" -eq 4 ]; }
  can_gen_server_with_conf_section() { can_gen_conf && [ ${#ALT_NAMES[@]} -gt 0 ]; }

  _age() { "${AGE[age_bin]:-age}" "${@}"; }
  # shellcheck disable=SC2120
  _age_keygen() { "${AGE[age_keygen_bin]:-age-keygen}" "${@}"; }

  #
  # Helpers
  #
  print_nice() { sed -e 's/^\s*$//' -e '/^$/d' -e 's/^\s*//' -e 's/^,//' <<< "${1-$(cat)}"; }
  # https://gist.github.com/varlogerr/2c058af053921f1e9a0ddc39ab854577#file-sed-quote
  sed_escape_pattern() { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
  sed_escape_replace() { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

  main() {
    local endpoint; endpoint="$(get_endpoint "${@:1:1}")"  || return 1

    gen_ssl_conf

    grep -q '\.\(cnf\|conf\)$' <<< "${1}" && CONF_FILE="${1}"
    "${endpoint}" "${@:2}" || return 1
  }

  main "${@}"
)

(return 2>/dev/null) || gen_ssl "${@}"
