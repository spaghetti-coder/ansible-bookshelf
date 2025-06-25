#!/usr/bin/env bash

# REQUIREMENTS:
# * Linux environment with basic GNU tools (grep, sed, etc.)
# * openssl
# * age available in the PATH (https://github.com/FiloSottile/age)
#   Why not used openssl encryption capabilities to decrease dependencies:
#     https://stackoverflow.com/a/16056298

gen_ssl_conf() {
  # CA cert configuration
  CA=(              # <- CA data to be used for TLS certs generation
    [bundle]=''
    [days]=3650     # <- Days to expire
    [cn]='My CA'    # <- Optional, leave blank to ignore
  )

  # TLS cert configuration
  DAYS="$(max_cert_days)"   # <- Future proof days to expire, or not future proof hardcode `DAYS=365`
  ALT_NAMES=(               # <- REQUIRED at least one either here or in *.conf file
    # # EXAMPLES:
    # '*.my-test.com'       # <- First alt name will be used for TLS cert CN
    # '*.test.my-test.com'  # <- Subdomain needs another record
    # 'my-test.com'
    # 'localhost'
    # '10.54.42.6'          # <- No wildcards support for IPs
    # '10.54.42.15'
  )
  # Output TLS cert file prefix to generate *.crt, *.key files. I.e. with
  # PREFIX="${HOME}/my" `gen-ssl.sh gen-tls` generates to "${HOME}/my.crt"
  # and "${HOME}/my.key", while `gen-ssl.sh gen-tls "${HOME}/your"` generates
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
gen_ssl_core() (
  `# LINKS:`
  `# * https://www.youtube.com/watch?v=VH4gXcvkmOY`
  `# * https://two-oes.medium.com/working-with-openssl-and-dns-alternative-names-367f06a23841`
  `# * https://www.ibm.com/docs/en/hpvs/1.2.x?topic=reference-openssl-configuration-examples`
  `# * https://github.com/ChristianLempa/cheat-sheets/blob/77b2ae1735167435c534187b7480ef63cf8ad77e/misc/ssl-certs.md`

  declare -A AGE CA
  local DAYS PREFIX
  local -a ALT_NAMES
  local CONF_FILE HELP_NOTE_PRINTED=false

  local SELF_SCRIPT=gen-ssl.sh
  grep -q '.\+' -- "${0}" 2>/dev/null && SELF_SCRIPT="$(basename -- "${0}" 2>/dev/null)"

  # https://stackoverflow.com/a/42449998
  # shellcheck disable=SC2034
  local -r  T_BOLD='\033[1m' \
            T_DIM='\033[2m' \
            T_ITALIC='\033[3m' \
            T_UNDER='\033[4m' \
            T_RESET='\033[0m'
  local -r  SECS_IN_DAY="$(( 24 * 60 * 60 ))"

  main() {
    local command; command="$(get_command "${@:1:1}")"  || return 1

    gen_ssl_conf

    grep -q '\.\(cnf\|conf\)$' <<< "${1}" && CONF_FILE="${1}"
    "${command}" "${@:2}" || return 1
  }

  get_command() {
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
      [gen-ca]=gen_ca_bundle
      [gen-conf]=gen_conf
      [gen-tls]=gen_tls
      [ca-cert]=get_ca_cert
      [ca-key]=get_ca_key
      [age-pub]=get_age_pub
      [age-secret]=get_age_secret
    )
    declare commands_rex
    commands_rex="$(printf -- '%s\|' "${!commands_map[@]}" | sed 's/\\|$//')"
    grep -qx "\(${commands_rex}\)" <<< "${CMD}" && { echo "${commands_map[${CMD}]}"; return; }

    # Check if conf-file, i.e. generate TLS cert
    grep -q '\.\(cnf\|conf\)$' <<< "${CMD}" && { echo gen_tls; return; }

    echo "Invalid command: '${CMD}'. Try --help" >&2
    return 1
  }

  #
  # COMMANDS
  #

  gen_ca_bundle() {
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

  gen_tls() {
    local -a dest=("${@}")
    local ca_key ca_cert conf_file_txt

    propagate_age_secret || return

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
      set -o pipefail; ( (
        (set -x; openssl req -new -key <(cat <<< "${key}") -config <(cat <<< "${conf_file_txt}")) \
      3>&2 2>&1 1>&3 ) | sed '/^+\+\s\+cat$/d' ) 3>&2 2>&1 1>&3
    )" || return
    cert="$(
      set -o pipefail; ( (
        ( set -x; openssl x509 -req \
          -days "${days}" \
          -extensions 'v3_req' \
          -extfile <(cat <<< "${conf_file_txt}") \
          -in <(cat <<< "${request}") \
          -CA <(cat <<< "${ca_cert}") \
          -CAkey <(cat <<< "${ca_key}")
        ) \
      3>&2 2>&1 1>&3 ) | sed '/^+\+\s\+cat$/d' ) 3>&2 2>&1 1>&3
    )" || return
    chain="$(
      `# https://serverfault.com/a/755815 <- In case CA cert is chain of certs`
      set -o pipefail; ( (
        (set -x;
          openssl crl2pkcs7 -nocrl -certfile <(cat <<< "${cert}"$'\n'"${ca_cert}") \
          | openssl pkcs7 -print_certs
        ) \
      3>&2 2>&1 1>&3 ) | sed '/^+\+\s\+cat$/d' ) 3>&2 2>&1 1>&3 \
      | sed -e '/^\s*\(subject\|issuer\)=/d' -e '/^\s*$/d'
    )" || return

    (
      set -o pipefail; ( (
        set -x; openssl verify -CAfile <(cat <<< "${ca_cert}") <(cat <<< "${chain}") >/dev/null
      ) 3>&2 2>&1 1>&3 ) | sed '/^+\+\s\+cat$/d'
    ) 3>&2 2>&1 1>&3 || return

    # Ensure destination if configured somewhere
    [ "${#dest[@]}" -lt 1 ] && [ -n "${PREFIX}" ] && dest=("${PREFIX}")

    if [ "${#dest[@]}" -lt 1 ]; then  # <- Print to stdout
      printf -- '%s\n' "${key}" "${chain}"
    else
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
    fi

    local ca_cert_end; ca_cert_end="$(openssl x509 -enddate -noout -in <(cat <<< "${ca_cert}") | sed 's/^[^=]\+=//')"
    local ca_cert_end_ts; ca_cert_end_ts="$(date -d "${ca_cert_end}" '+%s')"
    local now_ts; now_ts="$(date '+%s')"
    local cert_end_ts; cert_end_ts="$(( now_ts + "$(( days * "${SECS_IN_DAY}" ))" ))"
    local cert_end; cert_end="$(date -u -d @"${cert_end_ts}" '+%Y-%m-%d %T %Z')"
    local max_days; max_days="$(max_cert_days)"

    echo -e "----- ${T_BOLD}INFO${T_RESET}: TLS certificate is valid up until ${cert_end} (${days} days)" >&2
    if [ "${cert_end_ts}" -gt "${ca_cert_end_ts}" ]; then
      ca_cert_end="$(date -u -d @"${ca_cert_end_ts}" '+%Y-%m-%d %T %Z')"
      echo -e "----- ${T_BOLD}WARN${T_RESET}: CA expires on ${ca_cert_end}, which is earlier than the TLS certificate." >&2
    fi
    if [ "${days}" -gt "${max_days}" ]; then
      {
        echo -e "----- ${T_BOLD}WARN${T_RESET}: TLS certificate validity is more than supported ${max_days} days."
        echo -e "-----       https://www.ssl.com/article/preparing-for-47-day-ssl-tls-certificates/"
        echo -e "-----       https://www.digicert.com/blog/tls-certificate-lifetimes-will-officially-reduce-to-47-days"
      } >&2
    fi
  }

  gen_conf() {
    print_nice "
      certDays  = $(max_cert_days)   # <- TLS certificate days to expire (better <= $(max_cert_days) days)
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

  get_age_pub() {
    (set -o pipefail; get_ca_bundle_lines | sed -n '1p')
  }

  get_age_secret() {
    [ -n "${GEN_SSL_AGE_SECRET}" ] && { cat <<< "${GEN_SSL_AGE_SECRET}"; return; }
    local lines; lines="$(set -o pipefail; get_ca_bundle_lines | sed -n '2p')" || return
    (set -o pipefail; base64 -d <<< "${lines}" | _age -d)
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
      # Generate TLS key / cert based on ${conffile}. Prompts for CA[bundle]
      # passphrase to decrypt age secret key that decrypts CA key
      ${SELF_SCRIPT} ${conffile} > ${bundle_file}   # Ensure \`chmod '0600' ${bundle_file}\` after that
     ,
      # Less flexible, but simpler for maintenance alternative to:
      #   ${SELF_SCRIPT} gen-conf > ${conffile}; \`# Edit ${conffile}\`; ${SELF_SCRIPT} ${conffile}
      # Fill ALT_NAMES in the conf section of the current script and execute:
      ${SELF_SCRIPT} gen-tsl > ${bundle_file}   # Ensure \`chmod '0600' ${bundle_file}\` after that
     ,
      # Use FILE_PREFIX to put to separate '${prefix}.crt' and '${prefix}.key'
      # files instead of '${bundle_file}' (Note: no extension for FILE_PREFIX).
      # Same can be done by setting PREFIX in the script conf section, then no
      # inline FILE_PREFIX needed
      ${SELF_SCRIPT} ${conffile} ${prefix}   # <- For configuration file
      ${SELF_SCRIPT} gen-tls ${prefix}     # <- For ALT_NAMES in the conf section
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
      gen-conf    # Generate TLS certs configuration file to stdout
      gen-tls     # Generate TLS certs with ALT_NAMES from the script to stdout / file
      CONF_FILE   # Generate TLS certs from CONF_FILE (*.cnf / *.conf) to stdout / file
      ca-cert     # Print CA cert to stdout
      age-pub     # Print age public key to stdout
      # For private and development needs mostly:
      ca-key      # Print CA private key to stdout
      age-secret  # Print age secret key to stdout. Wants passphrase
    "
  }

  print_help() {
    print_nice "
      Keep encrypted CA and TLS cert configuration in a single file, that allows TLS
      certs generation with a single command. Alternatively TLS cert configuration
      can be placed to a separate file.
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

  #
  # CORE
  #

  print_help_note() {
    ${HELP_NOTE_PRINTED} && return 1
    HELP_NOTE_PRINTED=true

    if can_gen_tls_with_conf_section; then
      print_nice "
        NOTE:
        ====
        The current script is ready for 'gen-tls'. Skip steps up to 'gen-tls' if you
        are fine with the conf section. Configured ALT_NAMES:
        $(
          printf -- ',  - %s\n' "${ALT_NAMES[@]}" \
          | sed -e '0,/$/ s/$/          # <- Will be used for TLS cert CN/'
        )
      "

      if [ -n "${PREFIX}" ]; then
        print_nice "
          PREFIX configured to '${PREFIX}'.
          With \`${SELF_SCRIPT} gen-tls\` will generate:
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
        you are fine with the conf section. If you have a TLS cert config file
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

  get_ca_bundle_lines() {
    [ -n "${CA[bundle]}" ] || { echo "CA[bundle] not configured. Try --help" >&2; return 1; }
    base64 -d <<< "${CA[bundle]}"
  }

  can_gen_conf() { [ "$(get_ca_bundle_lines 2>/dev/null | wc -l)" -eq 4 ]; }
  can_gen_tls_with_conf_section() { can_gen_conf && [ ${#ALT_NAMES[@]} -gt 0 ]; }

  _age() { "${AGE[age_bin]:-age}" "${@}"; }
  # shellcheck disable=SC2120
  _age_keygen() { "${AGE[age_keygen_bin]:-age-keygen}" "${@}"; }

  propagate_age_secret() {
    [ -n "${GEN_SSL_AGE_SECRET}" ] && return
    declare -g GEN_SSL_AGE_SECRET; GEN_SSL_AGE_SECRET="$(get_age_secret)" || return
  }

  print_nice() { sed -e 's/^\s*$//' -e '/^$/d' -e 's/^\s*//' -e 's/^,//' <<< "${1-$(cat)}"; }
  # https://gist.github.com/varlogerr/2c058af053921f1e9a0ddc39ab854577#file-sed-quote
  sed_escape_pattern() { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
  sed_escape_replace() { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

  #
  # Helpers
  #

  max_cert_days() {
    # https://www.ssl.com/article/preparing-for-47-day-ssl-tls-certificates/

    local max_days=365   # <- Formally it's 13 months, but 1 year is more rounded
    declare -A date_to_days_map=(
      # [DATE]=MAX_LIFESPAN
      [2026-03-15]=200
      [2027-03-15]=100
      [2029-03-15]=47
    )

    declare -A ts_to_days_map
    local ts
    local d; for d in "${!date_to_days_map[@]}"; do
      ts="$(date -d "${d} 00:00:00 UTC" '+%s')"
      ts_to_days_map["${ts}"]="${date_to_days_map[${d}]}"
    done

    local now; now="$(date '+%s')"
    local days secs
    local prev_secs; prev_secs="$(( max_days * "${SECS_IN_DAY}" ))"
    local ts; while read -r ts; do
      days="${ts_to_days_map[${ts}]}"
      secs="$(( days * "${SECS_IN_DAY}" ))"

      [ "$(( "${now}" + "${prev_secs}" ))" -lt "$(( "${ts}" + "${secs}" ))" ] && break

      max_days="${days}"
      if [ "$(( "${ts}" + "${secs}"))" -gt "$(( "${now}" + "${prev_secs}"))" ]; then
        # Previous period timespan can be applied
        max_days="$(( "${prev_secs}" / "${SECS_IN_DAY}" ))"
      elif [ "${ts}" -gt "${now}" ]; then
        max_days="$(( ("${ts}" + "${secs}" - "${now}") / "${SECS_IN_DAY}" ))"
      fi

      prev_secs="${secs}"
    done <<< "$(printf -- '%s\n' "${!ts_to_days_map[@]}" | sort -n)"

    echo "${max_days}"
  }

  main "${@}"
)

(return 2>/dev/null) || gen_ssl_core "${@}"
