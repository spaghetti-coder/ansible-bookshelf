#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2329,SC2317

dydns_duckdns_config() {
  # Get token from your main page:
  #   https://www.duckdns.org/
  # No need to suffix domains with '.duckdns.org', only the subdomains.
  # Recommended schedule: */5 * * * *

  # Map variables
  DOMAINS=("${DUCKDNS_DOMAINS[@]}")             # <- Must come from config
  TOKEN="${DUCKDNS_TOKEN}"                      # <- Must come from secret
  SCHEDULE="${DUCKDNS_SCHEDULE:-*/5 * * * *}"   # <- Optionally comes from config
  ERR_TITLE="${DUCKDNS_ERR_TITLE:-DuckDNS: Update failure}"   # <- Optionally comes from config
  SUCCESS_REX='^OK$'

  # Setup curl args, CURL_ARGS var name matters
  local site="${1}"
  CURL_ARGS=("https://www.duckdns.org/update?&token=${TOKEN}&domains=${site}")
}

dydns_dynu_config() {
  # Get username at 'Control Panel' > 'My Account':
  #   https://www.dynu.com/en-US/ControlPanel/MyAccount
  # Use plain or MD5 / SHA256 hashed account password or gain (and alternatively
  # hash with MD5 / SHA256) an IP Update Password at 'Control Panel'
  # > 'My Account' > 'Username/Password':
  #   https://www.dynu.com/ControlPanel/ManageCredentials
  # Recommended schedule: */5 * * * *

  # Map variables
  DOMAINS=("${DYNU_DOMAINS[@]}")              # <- Must come from config
  TOKEN="${DYNU_TOKEN}"                       # <- Must come from secret (USERNAME:PASSWORD)
  SCHEDULE="${DYNU_SCHEDULE:-*/5 * * * *}"    # <- Optionally comes from config
  ERR_TITLE="${DYNU_ERR_TITLE:-Dynu: Update failure}"   # <- Optionally comes from config
  SUCCESS_REX='^\(good\s\|nochg\)'

  # Setup curl args, CURL_ARGS var name matters
  local site="${1}"
  CURL_ARGS=(-u "${TOKEN}" "https://api.dynu.com/nic/update?hostname=${site}")
}

dydns_now_dns_config() {
  # Use your password or token generated on account page:
  #   https://now-dns.com/account
  # No recommended schedule found.

  # Map variables
  DOMAINS=("${NOW_DNS_DOMAINS[@]}")             # <- Must come from config
  TOKEN="${NOW_DNS_TOKEN}"                      # <- Must come from secret (EMAIL:PASSWORD)
  SCHEDULE="${NOW_DNS_SCHEDULE:-*/5 * * * *}"   # <- Optionally comes from config
  ERR_TITLE="${NOW_DNS_ERR_TITLE:-Now-DNS: Update failure}"   # <- Optionally comes from config
  SUCCESS_REX='^"\?\(good\|nochg\)"\?'

  # Setup curl args, CURL_ARGS var name matters
  local site="${1}"
  CURL_ARGS=(-u "${TOKEN}" "https://now-dns.com/update?hostname=${site}")
}

dydns_ydns_config() {
  # Generate Token and Username in Preferences > API Credentials:
  #   https://ydns.io/user/api
  # Recommended schedule: */15 * * * *

  # Map variables
  DOMAINS=("${YDNS_DOMAINS[@]}")             # <- Must come from config
  TOKEN="${YDNS_TOKEN}"                      # <- Must come from secret (USERNAME:PASSWORD)
  SCHEDULE="${YDNS_SCHEDULE:-*/15 * * * *}"  # <- Optionally comes from config
  ERR_TITLE="${YDNS_ERR_TITLE:-YDNS: Update failure}"   # <- Optionally comes from config
  SUCCESS_REX='^\(good\|nochg\)\s'

  # Setup curl args, CURL_ARGS var name matters
  local site="${1}"
  CURL_ARGS=(-u "${TOKEN}" "https://ydns.io/api/v1/update/?host=${site}")
}


# To create custom provider just copy some dydns_*_config callback functions,
# place it to ./config/extra.sh, rename to dydns_<PROVIDER>_config with '-'
# in your provider name replaced by '_' and assign values accordingly. I.e.
# for 'hui-dns' provider it will become 'dydns_hui_dns_config' function


# ========== END OF CONF ==========


dydns_core() (
  local PROVIDER
  local CONFIG_FUNC
  local CRON_MARKER='# <- DYDNS-UPDATER'

  local DOMAINS
  local TOKEN
  local SCHEDULE
  local SUCCESS_REX
  local ERR_TITLE
  local -a CURL_ARGS

  declare -A CMD_MAP=(
    [cron-ls]=cron_ls
    [cron-rm]=cron_rm
    [cron-rm-orphans]=cron_rm_orphans
    [cron-set]=cron_set
    [update]=update
    [verify]=verify
  )

  main() {
    [[ "${1}" =~ ^(-\?|-h|--help)$ ]] && { print_help; return; }
    [ "${1}" = '--usage' ] && { print_help_usage; return; }
    [ "${1}" = '--demo' ] && { print_help_demo; return; }

    declare CONF_DIR; CONF_DIR="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}" 2>/dev/null)")/config"
    . "${CONF_DIR}/secret.sh" 2>/dev/null   # <- Contains secret tokens for all DyDNSes and optionally NOTIFY_TOKEN
    . "${CONF_DIR}/config.sh" 2>/dev/null   # <- Contains the rest of DyDNS and NOTIFY_* configurations
    . "${CONF_DIR}/extra.sh" 2>/dev/null    # <- Contains the rest of DyDNS and NOTIFY_* configurations

    # Test alert works, configs must be loaded by the moment
    [ "${1}" = '--alert-test' ] && { test_alert "${@:2}"; return; }

    local cmd; cmd="$(get_command "${1}")" || return

    # Commands that don't need PROVIDER
    printf -- '%s\n' \
      cron_ls \
      cron_rm_orphans \
    | grep -qFx -- "${cmd}" && { "${cmd}"; return; }

    PROVIDER="${2}"

    local prefix="${PROVIDER//-/_}"
    CONFIG_FUNC="dydns_${prefix}_config"
    "${CONFIG_FUNC}" 2>/dev/null

    # Commands that don't need verification
    printf -- '%s\n' \
      verify \
      cron_rm \
    | grep -qFx -- "${cmd}" && { "${cmd}"; return; }

    verify >&2 || return
    "${cmd}"
  }

  update() {
    local -a failed
    local d; for d in "${DOMAINS[@]}"; do
      "${CONFIG_FUNC}" "${d}" 2>/dev/null

      ( set -o pipefail
        curl --max-time 30 -ksSL "${CURL_ARGS[@]}" | grep -- "${SUCCESS_REX}"
      ) || failed+=("${d}")
    done

    [ ${#failed[@]} -lt 1 ]     && return
    [ -z "${NOTIFY_PROVIDER}" ] && return

    notify_core -t "${ERR_TITLE}" -- \
      "$(hostname -f)" "@ $(date +'%Y-%m-%d %H:%M:%S')" "" \
      "FAILED DOMAINS:" \
      "$(printf -- '- %s\n' "${failed[@]}")"
  }

  cron_ls() {
    local marker_rex; marker_rex="$(sed_escape_pattern "${CRON_MARKER}")"

    crontab -l 2>/dev/null \
    | grep -x '\s*[^#].\+'"${marker_rex}"'\s*' \
    | sed -e 's/'"${marker_rex}"'\s*$//' -e's/\s*$//' \
    | rev | cut -d' ' -f1 | rev | sort -n
  }

  cron_rm() {
    [ -n "${PROVIDER}" ] || { echo "PROVIDER required" >&2; return 1; }

    local suffix_rex; suffix_rex='\s'"$(
      sed_escape_pattern "${PROVIDER}"
    )"'\s\+'"$(
      sed_escape_pattern "${CRON_MARKER}"
    )"'\s*'

    local current; current="$(crontab -l 2>/dev/null)"
    ! grep -qx '\s*[^#].\+'"${suffix_rex}" <<< "${current}" && {
      echo "Unchanged"
      return
    }

    local content="${current}"
    content="$(grep -vx '\s*[^#].\+'"${suffix_rex}" <<< "${content}")"
    crontab - <<< "${content}" || return
    echo "Done"
  }

  cron_rm_orphans() {
    local providers
    providers="$(cron_ls | grep '.\+')" || return 0

    local output="Unchanged"
    local -a arr; mapfile -t arr <<< "${providers}"
    local p; for p in "${arr[@]}"; do
      # shellcheck disable=SC2030
      main verify "${p}" >/dev/null && continue
      main cron-rm "${p}" >/dev/null
      output="Done"
    done
    echo "${output}"
  }

  cron_set() {
    local current
    local schedule_rex; schedule_rex="$(sed_escape_pattern "${SCHEDULE}")"
    local suffix_rex; suffix_rex='\s'"$(
      sed_escape_pattern "${PROVIDER}"
    )"'\s\+'"$(
      sed_escape_pattern "${CRON_MARKER}"
    )"'\s*'

    current="$(crontab -l 2>/dev/null)"
    grep -qx '\s*'"${schedule_rex}"' .\+'"${suffix_rex}" <<< "${current}" && {
      echo "Unchanged"
      return
    }

    local content="${current}"
    content="$(grep -vx '\s*[^#].\+'"${suffix_rex}" <<< "${content}")"
    content+="${current:+$'\n'}${SCHEDULE}"
    # shellcheck disable=SC2016
    content+=' sleep "$(( $(shuf -i 0-40 -n 1) + 10 ))";'
    content+=" $(self_location) update ${PROVIDER} ${CRON_MARKER}"
    crontab - <<< "${content}" || return
    echo "Done"
  }

  verify() {
    local rc=0
    if \
      ! declare -p DOMAINS | cut -d' ' -f2 | grep -q a \
      || [ "${#DOMAINS[@]}" -lt 1 ] \
    ; then
      echo "# DOMAINS: none"; rc=1
    else
      printf -- 'DOMAINS='
      printf -- '%s,' "${DOMAINS[@]}" | sed 's/,\+$//'
      echo
    fi

    if [ -z "${TOKEN}" ]; then
      echo "# TOKEN: none"; rc=1
    else
      echo "TOKEN=*****"
    fi

    if [ -z "${SCHEDULE}" ]; then
      echo "# SCHEDULE: none"; rc=1
    else
      echo "SCHEDULE=${SCHEDULE}"
    fi

    if [ -z "${SUCCESS_REX}" ]; then
      echo "# SUCCESS_REX: none"; rc=1
    else
      echo "SUCCESS_REX=${SUCCESS_REX}"
    fi

    if [ -z "${ERR_TITLE}" ]; then
      echo "# ERR_TITLE: none"; rc=1
    else
      echo "ERR_TITLE=${ERR_TITLE}"
    fi

    return ${rc}
  }

  test_alert() {
    [ -z "${NOTIFY_PROVIDER}" ] && return
    notify_core "${@}"
  }

  print_help_usage() {
    local self_script; self_script="$(basename -- "${0}")"

    echo "
      ${self_script} cron-ls|cron-rm-orphans
      ${self_script} cron-rm|cron-set|update|verify PROVIDER
    " | sed -e 's/^\s*//' -e 's/\s*$//' -e '/^$/d' -e 's/^,//'
  }

  print_help_demo() {
    local self_script; self_script="$(basename -- "${0}")"
    local provider=duckdns

    echo "
      # (Given ${provider} provider configured)
     ,
      # Verify provider configuration
      ${self_script} verify ${provider}
     ,
      # Update all configured provider hosts
      ${self_script} update ${provider}
     ,
      # Set cron schedule for the provider update, the schedule is taken
      # from the provider configuration
      ${self_script} cron-set ${provider}
     ,
      # List all providers configured in cron
      ${self_script} cron-ls
     ,
      # Remove from cron all providers that fail configuration verification,
      # i.e. the ones that don't have some of the required configurations
      ${self_script} cron-rm-orphans
     ,
      # Remove the provider from cron
      ${self_script} cron-rm ${provider}
    " | sed -e 's/^\s*//' -e 's/\s*$//' -e '/^$/d' -e 's/^,//'
  }

  print_help() {
    local self_script; self_script="$(basename -- "${0}")"

    echo "
      --demo    Print only demo section
      --usage   Print only usage section
     ,
      USAGE:
        $(print_help_usage | sed 's/^/,  /')
     ,
      DEMO:
        $(print_help_demo | sed 's/^/,  /')
    " | sed -e 's/^\s*//' -e 's/\s*$//' -e '/^$/d' -e 's/^,//'
  }

  self_location() {
    local self_dir; self_dir="$(dirname -- "${0}")"
    local self_name; self_name="$(basename -- "${0}")"

    (cd -- "${self_dir}" && pwd) | printf -- '%s\n' "$(sed 's/\/$//')/${self_name}"
  }

  get_command() {
    [[ (-n "${1}" && -n "${CMD_MAP[$1]}") ]] && { echo "${CMD_MAP[$1]}"; return; }

    {
      echo "Invalid command. Supported commands:"
      printf -- '  * %s\n' "${!CMD_MAP[@]}" | sort -n
      return 1
    } >&2
  }

  # https://gist.github.com/varlogerr/2c058af053921f1e9a0ddc39ab854577#file-sed-quote
  # shellcheck disable=SC2120
  sed_escape_pattern() { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
  # shellcheck disable=SC2120
  sed_escape_replace() { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

  main "${@}"
)

(return 2>/dev/null) || dydns_core "${@}"
