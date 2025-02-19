#!/usr/bin/env bash

# shellcheck disable=SC2317
play_upgrade() (
  main() {
    declare SELF_DIR; SELF_DIR="$(dirname -- "${BASH_SOURCE[0]}")"

    # shellcheck disable=SC1091
    . "${SELF_DIR}/play.sh"

    play -t upgradable "${@}"
  }

  main "${@}"
)

(return 2>/dev/null) || play_upgrade "${@}"
