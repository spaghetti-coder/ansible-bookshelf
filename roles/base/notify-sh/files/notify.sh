#!/usr/bin/env bash

# shellcheck source=/dev/null
# shellcheck disable=SC2092

notify_config() {
  `# Configure NOTIFY_* variables.`

  NOTIFY_PROVIDER='' `#   <- (REQUIRED) One of: discord, gotify, telegram`

  `# NOTIFY_TOKEN='<HOOK_ID>/<HOOK_TOKEN>'      # <- From discord channel`
  `# NOTIFY_TOKEN='<GOTIFY_APPLICATION_TOKEN>'  # <- From https://${NOTIFY_SERVER}/#/applications`
  `# NOTIFY_TOKEN='<TELEGRAM_BOT_TOKEN>'        # <- From BotFather`
  NOTIFY_TOKEN='' `#      <- (REQUIRED)`
}

`# ===== PROVIDER SPECIFIC OPTIONS =====`

notify_config_gotify() {
  NOTIFY_SERVER='' `#     <- (REQUIRED for gotify)`
}

notify_config_telegram() {
  `# Telegram setup instructions:`
  `#   https://gist.github.com/spaghetti-coder/2b4befe34f8b4af56080a2c4744a1efb`
  NOTIFY_CHAT_ID='' `#    <- (REQUIRED for telegram) '<CHAT_ID>' or '<CHAT_ID>/<THREAD_ID>'`
}



`# ==================== END OF CONFIGURATION ZONE ====================`



notify_core() {
  local PROVIDER \
        SERVER \
        TOKEN \
        CHAT_ID

  local -a CONFFILES
  local ACTION=perform_push

  local -a MESSAGES
  local TITLE

  declare -a SUPPORTED_PROVIDERS=(
    discord
    gotify
    telegram
  )

  local SELF_SCRIPT=notify.sh
  head -n 1 -- "${0}" | grep -q '^#!' && SELF_SCRIPT="$(basename -- "${0}")"

  main() {
    init "${@}" || return
    ${ACTION} || return
  }

  init() {
    local self_prefix="${SELF_SCRIPT%.*}"
    local self_dir; self_dir="$(dirname -- "${0}")"
    local extra_file="${self_dir}/${self_prefix}._extra_.sh"
    local secret_file="${self_dir}/${self_prefix}._secret_.sh"

    #
    # Load all sources that can have NOTIFY_PROVIDER
    #

    parse_args "${@}" || return                                 # <- '-p PROVIDER'
    [ -n "${PROVIDER}" ] || {
      # Stash environment variables to avoid being overriden overriden
      local int_NOTIFY_TOKEN="${NOTIFY_TOKEN}" \
            int_NOTIFY_SERVER="${NOTIFY_SERVER}" \
            int_NOTIFY_CHAT_ID="${NOTIFY_CHAT_ID}"

      # loading ENV VARS                                          # <- Env vars are already here
      init_set_provider
      local NOTIFY_PROVIDER

      declare -F notify_config &>/dev/null && notify_config       # <- notify_config function
      init_set_provider
      cat -- "${extra_file}" &>/dev/null && . "${extra_file}"     # <- SCRIPT_NAME._extra_.sh file
      init_set_provider
      cat -- "${secret_file}" &>/dev/null && . "${secret_file}"   # <- SCRIPT_NAME._secret_.sh file
      init_set_provider
      local f; for f in "${CONFFILES[@]}"; do                     # <- '-f CONFFILE'...
        f="$(cat -- "${f}")" || return; . <(printf -- '%s\n' "${f}")
        init_set_provider
      done

      PROVIDER="${PROVIDER-${NOTIFY_PROVIDER}}"   # <- It's either loaded from '-p' or from other sources
      PROVIDER="${PROVIDER-_invalid_}"            # <- Provide with some invalid value

      # Preserve environment variables
      local NOTIFY_TOKEN="${int_NOTIFY_TOKEN}" \
            NOTIFY_SERVER="${int_NOTIFY_SERVER}" \
            NOTIFY_CHAT_ID="${int_NOTIFY_CHAT_ID}"
    }

    #
    # Load all sources to load the rest of the configuration
    #

    local prov_func="notify_config_${PROVIDER}"
    local prov_file="${self_dir}/${self_prefix}._${PROVIDER}_.sh"
    local prov_secret_file="${self_dir}/${self_prefix}._${PROVIDER}_.secret.sh"

    # loading ENV VARS                                          # <- Env vars are already here
    init_set_vars
    local NOTIFY_TOKEN \
          NOTIFY_SERVER \
          NOTIFY_CHAT_ID

    declare -F notify_config &>/dev/null && notify_config       # <- notify_config function
    init_set_vars
    declare -F "${prov_func}" &>/dev/null && "${prov_func}"     # <- notify_config_PROVIDER function
    init_set_vars
    cat -- "${extra_file}" &>/dev/null && . "${extra_file}"     # <- SCRIPT_NAME._extra_.sh file
    init_set_vars
    cat -- "${prov_file}" &>/dev/null && . "${prov_file}"       # <- SCRIPT_NAME._PROVIDER_.sh file
    init_set_vars
    cat -- "${secret_file}" &>/dev/null && . "${secret_file}"   # <- SCRIPT_NAME._secret_.sh file
    init_set_vars
    cat -- "${prov_secret_file}" &>/dev/null && . "${prov_secret_file}"   # <- SCRIPT_NAME._PROVIDER_.secret.sh file
    init_set_vars
    local f; for f in "${CONFFILES[@]}"; do                     # <- '-f CONFFILE'...
      f="$(cat -- "${f}")" || return; . <(printf -- '%s\n' "${f}")
      init_set_vars
    done
  }

  init_set_provider() {
    [ -n "${NOTIFY_PROVIDER}" ] && PROVIDER="${NOTIFY_PROVIDER}"  # <- Only when not empty
    NOTIFY_PROVIDER=""  # <- Empty it for the next source
  }

  init_set_vars() {
    [ -n "${NOTIFY_TOKEN}" ] && TOKEN="${NOTIFY_TOKEN}"
    [ -n "${NOTIFY_SERVER}" ] && SERVER="${NOTIFY_SERVER}"
    [ -n "${NOTIFY_CHAT_ID}" ] && CHAT_ID="${NOTIFY_CHAT_ID}"
    NOTIFY_TOKEN=""
    NOTIFY_SERVER=""
    NOTIFY_CHAT_ID=""
  }

  parse_args() {
    local endparams=false
    local arg

    while [ $# -gt 0 ]; do
      ${endparams} && arg='*' || arg="${1}"

      case "${arg}" in
        -\?|-h|--help       ) print_help; exit ;;
        --usage             ) print_help_usage; exit ;;
        --demo              ) print_help_demo; exit ;;
        --genconf|--confgen ) gen_conf; exit ;;
        -p|--provider )
          [ -n "${2}" ] || { echo "${1} option requires non-empty PROVIDER" >&2; return 1; }
          PROVIDER="${2}"
          shift
          ;;
        --provider=*  )
          local provider="${1#*=}"
          [ -n "${provider}" ] || { echo "${1} option requires non-empty PROVIDER" >&2; return 1; }
          PROVIDER="${provider}"
          ;;
        -f|--conffile )
          [ -n "${2}" ] || { echo "${1} option requires non-empty CONFFILE" >&2; return 1; }
          CONFFILES+=("${2}")
          shift
          ;;
        --conffile=*  )
          local file="${1#*=}"
          [ -n "${file}" ] || { echo "${1} option requires non-empty CONFFILE" >&2; return 1; }
          CONFFILES+=("${file}")
          ;;
        -t|--title    )
          [ -n "${2}" ] || { echo "${1} option requires non-empty TITLE" >&2; return 1; }
          TITLE="${2}"
          shift
          ;;
        --title=*     )
          local title="${1#*=}"
          [ -n "${title}" ] || { echo "${1} option requires non-empty TITLE" >&2; return 1; }
          TITLE="${title}"
          ;;
        --test        ) ACTION=perform_test ;;
        --            ) endparams=true ;;
        -*            ) echo "Unsupported argument ${1}" >&2; return 1 ;;
        *             ) MESSAGES+=("${1}") ;;
      esac

      shift
    done
  }

  # shellcheck disable=SC2016
  gen_conf() {
    printf -- '%s\n' '#!/usr/bin/env bash' '# shellcheck disable=SC2092' ''

    local -a funcs=(notify_config)
    local p; for p in "${SUPPORTED_PROVIDERS[@]}"; do
      funcs+=("notify_config_${p}")
    done

    local ctr=0
    local f; for f in "${funcs[@]}"; do
      declare -F "${f}" &>/dev/null || continue

      [ ${ctr} -gt 0 ] && echo
      [ ${ctr} -eq 1 ] && {
        echo '`# ===== PROVIDER SPECIFIC OPTIONS =====`'
        echo
      }

      declare -f "${f}"
      (( ctr++ ))
    done

    printf -- '%s\n' \
      '' \
      '`# ===== END OF CONFIGURATION ZONE =====`' \
      '' \
      'notify_config' \
      'if declare -F "notify_config_${PROVIDER}" &>/dev/null; then' \
      '  "notify_config_${PROVIDER}"' \
      'fi'

    return 0
  }

  print_help_usage() {
    local script_name="${SELF_SCRIPT%.*}"

    echo "
      # Send notifycation
      ${SELF_SCRIPT} [-p|--provider PROVIDER] [-f|--conffile CONFFILE]... \\
     ,  [-t|--title TITLE] [--] MESSAGE...
     ,
      # Test the provider specific configs are set
      ${SELF_SCRIPT} [-p|--provider PROVIDER] [-f|--conffile CONFFILE] --test
     ,
      # Generate config file to stdout
      ${SELF_SCRIPT} --genconf > ${script_name}._extra_.sh  # <- With redirect to file
      ${SELF_SCRIPT} --confgen                      # <- Alias to --genconf
     ,
      ${SELF_SCRIPT} --usage  # <- Print only usage help section
      ${SELF_SCRIPT} --demo   # <- Print only demo help section
    " | sed -e 's/^\s\+//' -e 's/\s\+$//' -e '/^\s*$/d' -e 's/^,//'
  }

  print_help_demo() {
    local script_name="${SELF_SCRIPT%.*}"

    echo "
      # Given NOTIFY_PROVIDER=gotify and NOTIFY_SERVER configured
      ${SELF_SCRIPT} -t 'My Title' -- 'My message'
     ,
      # Given NOTIFY_SERVER configured, push to gotify provider
      ${SELF_SCRIPT} -p gotify -- 'Line 1' 'Line 2'   # <- Two line message
     ,
      # Given NOTIFY_SERVER is not configured, push to gotify provider.
      # NOTIFY_PROVIDER is ignored due to inline '--provider'
      export NOTIFY_SERVER=https://gotify.home
      ${SELF_SCRIPT} --provider gotify --title 'My title' -- 'My message'
     ,
      # Given ${SELF_SCRIPT} is in PWD and nothing is configured in it, or
      # you just want to ignore its configuration
      cat <<EOF > '${script_name}._extra_.sh'
     ,  NOTIFY_PROVIDER=gotify
     ,  NOTIFY_TOKEN=123
     ,  NOTIFY_SERVER=https://gotify.home
      EOF
      ${SELF_SCRIPT} -p gotify -t 'My title' -- 'My message'
     ,
      # Given there are 2 files with configs you want to use
      ${SELF_SCRIPT} -f ~/conf1.sh -f ~/conf2.sh -t 'My title' -- 'My message'
     ,
      # Other tricks
      cat <<EOF > '${script_name}._extra_.sh'
     ,  discord_conf() { NOTIFY_TOKEN='...'; \`# other telegram settins\`; }
     ,  gotify_conf() { NOTIFY_TOKEN='...'; \`# other gotify settins\`; }
     ,  telegram_conf() { NOTIFY_TOKEN='...'; \`# other telegram settins\`; }
     ,  [ -z \"\${PROVIDER}\" ] || \"\${PROVIDER}_conf\"  # <- PROVIDER defined internally
      EOF
      ${SELF_SCRIPT} -p telegram -t 'My title' -- 'My message'
    " | sed -e 's/^\s\+//' -e 's/\s\+$//' -e '/^\s*$/d' -e 's/^,//'
  }

  print_help() {
    local self_prefix; self_prefix="notify-me"

    echo "
      Push message to one of supported providers:
      $(printf -- ',  * %s\n' "${SUPPORTED_PROVIDERS[@]}")
      Configuration via notify_config and notify_config_PROVIDER functions inside the
      script. Also can be configured with env vars and external files.
     ,
      notify_config_PROVIDER function where PROVIDER suffix is chosen provider in the
      current script will be loaded if exists, so that the script can be configured to
      use multiple providers and manipulated provider with '-p' on run.
     ,
      If in the current script directory files with the same name as the current
      script and extensions listed below exist, they will be loaded:
     ,  ._extra_.sh, ._PROVIDER_.sh, ._secret_.sh, ._PROVIDER_.secret.sh
      I.e. given current script file name is '${self_prefix}.sh' or '${self_prefix}' will
      search for:
     ,  * ${self_prefix}._extra_.sh
     ,  * ${self_prefix}._gotify_.sh (if provider configured and equals 'gotify')
     ,  * ${self_prefix}._secret_.sh (can be used to keep NOTIFY_TOKEN separately)
     ,  * ${self_prefix}._gotify_.secret.sh
     ,
      Variables source priority (lowest to highest):
      * Env vars
      * Non-empty vars in notify_config function
      * Non-empty vars in notify_config_PROVIDER function (excluding NOTIFY_PROVIDER)
      * Non-empty vars in SCRIPT_NAME._extra_.sh file
      * Non-empty vars in SCRIPT_NAME._PROVIDER_.sh file (excluding NOTIFY_PROVIDER)
      * Non-empty vars in SCRIPT_NAME._secret_.sh file
      * Non-empty vars in SCRIPT_NAME._PROVIDER_.secret.sh file
      * Non-empty vars in file provided with -f CONFFILE argument
      * -p PROVIDER argument
     ,
      USAGE:
      $(print_help_usage | sed 's/^/,  /')
     ,
      DEMO:
      $(print_help_demo | sed 's/^/,  /')
    " | sed -e 's/^\s\+//' -e 's/\s\+$//' -e '/^\s*$/d' -e 's/^,//'
  }

  perform_push() {
    perform_test || return

    local endpoint \
          payload
    local params_maker="make_params_${PROVIDER}"

    [ "${#MESSAGES[@]}" -gt 0 ] || { echo "MESSAGE required" >&2; return 1; }

    "${params_maker}" endpoint payload || return

    curl -sSL -X POST -H 'Content-Type: application/json' \
      --data "${payload}" -- "${endpoint}"
  }

  make_params_discord() {
    local -n _endpoint="${1}"
    local -n _payload="${2}"

    local message; message="$(printf -- '%s\n' "${MESSAGES[@]}")"
    local embeds; embeds='"description": '"$(json_quote "${message}")" || return
    [ -n "${TITLE}" ] && { embeds+=', "title": '"$(json_quote "${TITLE}")" || return; }

    _endpoint=https://discord.com/api/webhooks; _endpoint+="/$(urlencode "${TOKEN}")" || return
    _payload='{ "embeds": [{ '"${embeds}"' }] }'
  }

  make_params_gotify() {
    local -n _endpoint="${1}"
    local -n _payload="${2}"

    local content_type='text/plain'; content_type="$(json_quote "${content_type}")" `# <- Can be 'text/markdown', risky` || return
    local priority=5

    local message; message="$(printf -- '%s\n' "${MESSAGES[@]}")"
    local full_msg; full_msg='"message": '"$(json_quote "${message}")" || return
    [ -n "${TITLE}" ] && { full_msg+=', "title": '"$(json_quote "${TITLE}")" || return; }

    _endpoint="${SERVER%*/}/message"; _endpoint+="?token=$(urlencode "${TOKEN}")" || return
    _payload='{
        '"${full_msg}"', "priority": '"${priority}"',
        "extras": { "client::display": { "contentType": '"${content_type}"' } }
      }'
  }

  make_params_telegram() {
    local -n _endpoint="${1}"
    local -n _payload="${2}"
    local chat_id="${CHAT_ID%%/*}"
    local thread_id

    [[ "${CHAT_ID}" =~ '/' ]] && thread_id="${CHAT_ID#/*}"

    local -a text_arr
    [ -n "${TITLE}" ] && {
      text_arr=("<b>$(html_escape "${TITLE}")</b>" '<b>~~~~~~~~~~</b>') || return
    }

    text_arr+=("$(printf -- '%s\n' "${MESSAGES[@]}" | html_escape)") || return

    local text; text="$(printf -- '%s\n' "${text_arr[@]}")"

    _endpoint=https://api.telegram.org
    _endpoint+="/bot$(urlencode "${TOKEN}")/sendMessage" || return
    _endpoint+="?chat_id=$(urlencode "${chat_id}")" || return
    [ -n "${thread_id}" ] && { _endpoint+="&message_thread_id=$(urlencode "${thread_id}")" || return; }

    _payload='{"text": "'"${text}"'", "parse_mode": "html", "disable_notification": false}'
  }

  perform_test() {
    local rc=0

    [ -n "${PROVIDER}" ] || { echo "PROVIDER not specified" >&2; return 1; }

    printf -- '%s\n' "${SUPPORTED_PROVIDERS[@]}" | grep -qFx -- "${PROVIDER}" || {
      echo "Unsupported provider: '${PROVIDER}'" >&2
      return 1
    }

    [ -n "${TOKEN}" ] || { rc=1; echo "TOKEN required" >&2; }

    case "${PROVIDER}" in
      gotify    )
          [ -n "${SERVER}" ] || { rc=1; echo "SERVER required" >&2; }
        ;;
      telegram  )
          [ -n "${CHAT_ID}" ] || { rc=1; echo "CHAT_ID required" >&2; }
        ;;
    esac

    return ${rc}
  }

  #
  # HELPERS
  #

  # USAGE:
  #   json_quote STRING         # <- Wirh argument
  #   echo STRING | json_quote  # <- Wirh stdin
  # Requires python3 or jq. https://stackoverflow.com/a/50380697, https://stackoverflow.com/a/13466143
  json_quote() {
    local -a quote_cmd=(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
    python3 --version &>/dev/null || {
      quote_cmd=(jq -Rsa .)
      jq --version &>/dev/null
    } || {
      echo "Required python3 or jq" >&2; return 1
    }
    printf -- '%s' "${1-$(cat)}" | "${quote_cmd[@]}"
  }

  # USAGE:
  #   urlencode STRING          # <- Wirh argument
  #   echo STRING | urlencode   # <- Wirh stdin
  # DEMO:
  #   echo "https://sample.com/?q=$(urlencode "foo bar")"
  # Requires python3 or jq. https://stackoverflow.com/a/34407620, https://stackoverflow.com/a/62788692
  urlencode() {
    local -a encode_cmd=(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read()))')
    python3 --version &>/dev/null || {
      encode_cmd=(jq -sRr '@uri')
      jq --version &>/dev/null
    } || {
      echo "Required python3 or jq" >&2; return 1
    }
    printf -- '%s' "${1-$(cat)}" | "${encode_cmd[@]}"
  }

  html_escape() { printf -- '%s' "${1-$(cat)}" | python3 -c 'import html,sys; print(html.escape(sys.stdin.read()))'; }

  main "${@}"
}

(return 2>/dev/null) || notify_core "${@}"
