#!/usr/bin/env bash

info_df_config() {
  INFO_DF_SCHEDULE="${INFO_DF_SCHEDULE:-0 12 * * 6}"    # <- Defaults to Saturday 12:00
  INFO_DF_FILESYSTEMS=("${INFO_DF_FILESYSTEMS[@]}")     # <- Acts like filter. If empty, print all significant
}

info_df_core() {
  declare -A CMD_MAP=(
    [cron-rm]=cron_rm
    [cron-set]=cron_set
    [inform]=inform
  )

  main() {
    [[ "${1}" =~ ^(-\?|-h|--help)$ ]] && { print_help; return; }

    local cmd; cmd="$(get_command "${1}")" || return
    "${cmd}" "${@:2}"
  }

  print_help() {
    local SELF_SCRIPT; SELF_SCRIPT="$(basename -- "${0}")"

    echo "
      USAGE:
    ,  ${SELF_SCRIPT} cron-set|cron-rm|verify
    ,  ${SELF_SCRIPT} inform [FS...]
    ,
      DEMO:
    ,  # Set cron schedule for filesystems configured in the configureation.
    ,  # The schedule is also taken from the configuration
    ,  ${SELF_SCRIPT} cron-set
    ,
    ,  # Same but with custom schedule
    ,  INFO_DF_SCHEDULE='0 15 * * 7' ${SELF_SCRIPT} cron-set
    ,
    ,  # Remove cron schedule
    ,  ${SELF_SCRIPT} cron-rm
    " | sed -e 's/^\s\+//' -e 's/\s\+$//' -e '/^$/d' -e 's/^,//'
  }

  inform() {
    declare -a args=(-h --local -x tmpfs -x overlay)
    [ $# -gt 0 ] && args=(-h -- "${@}")
    df "${args[@]}"
  }

  get_command() {
    [[ (-n "${1}" && -n "${CMD_MAP[$1]}") ]] && { echo "${CMD_MAP[$1]}"; return; }

    {
      echo "Invalid command. Supported commands:"
      printf -- '  * %s\n' "${!CMD_MAP[@]}" | sort -n
      return 1
    } >&2
  }

  main "${@}"
}

(return 2>/dev/null) || info_df_core "${@}"
