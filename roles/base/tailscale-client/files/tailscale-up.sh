#!/usr/bin/env bash

tailscale_up() (

  declare -a THE_CMD=(tailscale up --accept-dns --accept-routes)

  trap_help() {
    [[ "${1}" =~ ^(-\?|-h|--help)$ ]] || return

    printf -- '%s\n' \
      "Convenience tailscale alias for:" \
      "  ${THE_CMD[*]}"
  }

  main() {
    trap_help "${@}" && return

    [ "$(id -u)" -eq 0 ] || THE_CMD=(sudo "${THE_CMD[@]}")

    (set -x; "${THE_CMD[@]}") || return
    echo '# Web-UI: http://100.100.100.100'
  }

  main "${@}"
)

(return 2>/dev/null) || tailscale_up "${@}"
