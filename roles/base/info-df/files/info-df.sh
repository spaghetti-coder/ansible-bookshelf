#!/usr/bin/env bash

info_df_config() {
  INFO_DF_SCHEDULE="${INFO_DF_SCHEDULE:-0 12 * * 6}"    # <- Defaults to Saturday 12:00
  INFO_DF_FILESYSTEMS=("${INFO_DF_FILESYSTEMS[@]}")
}

print_help() {
  local SELF_SCRIPT; SELF_SCRIPT="$(basename -- "${0}")"

  echo -e "
    USAGE:
   ,  ${SELF_SCRIPT} cron-set|cron-rm
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

[[ "${1}" =~ ^(-\?|-h|--help)$ ]] && {
  print_help; exit
}


declare -a args=(-h --local -x tmpfs -x overlay)
[ $# -gt 0 ] && args=(-h -- "${@}")

df "${args[@]}"
