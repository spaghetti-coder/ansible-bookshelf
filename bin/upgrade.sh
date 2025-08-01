#!/usr/bin/env bash

upgrade() {
  local SELF_DIR; SELF_DIR="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")"
  declare -a THE_CMD=(upgrade_pkg -t upgradable)

  main() {
    cd -- "${SELF_DIR}/.." || return

    local force_code_server=false
    if [ "${1}" = "-!" ]; then
      force_code_server=true
      shift
    fi

    if true \
      && [ "${TERM_PROGRAM,,}" = vscode ] \
      && [ "${NODE_EXEC_PATH}" = '/usr/lib/code-server/lib/node' ] \
      && ! ${force_code_server:-false} \
    ; then
      printf -- '%s\n' \
        "Upgrade from Code-Server is not allowed as update can break the connection." \
        "Or pass '-!' flag as the very first argument to bypass it." \
      >&2
      return 1
    fi

    # shellcheck disable=SC1091
    . "${SELF_DIR}/upgrade-pkg.sh"
    "${THE_CMD[@]}" "${@}"
  }

  main "${@}"
}

(return 2>/dev/null) || upgrade "${@}"
