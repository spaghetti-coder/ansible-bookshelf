#!/usr/bin/env bash

upgrade() {
  local SELF_DIR; SELF_DIR="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")"
  declare -a THE_CMD=(upgrade_pkg -t upgradable)

  main() {
    cd -- "${SELF_DIR}/.." || return

    # shellcheck disable=SC1091
    . "${SELF_DIR}/upgrade-pkg.sh"
    "${THE_CMD[@]}" "${@}"
  }

  main "${@}"
}

(return 2>/dev/null) || upgrade "${@}"
