#!/usr/bin/env bash

# USAGE:
#   # If 'vaulted.txt' file presents in the project root, will
#   # prompt for vault password
#   SCRIPT [ANSIBLE_COMPATIBLE_ARGS]
#
#   # Will not prompt for password, will take it from BOOKSHELF_VAULT_PASS
#   # variable, even when 'vaulted.txt' is not present
#   BOOKSHELF_VAULT_PASS=VAULT_PASS SCRIPT [ANSIBLE_COMPATIBLE_ARGS]
# DEMO:
#   SCRIPT -l ubuntu-server -t docker
#   BOOKSHELF_VAULT_PASS=changeme SCRIPT -l ubuntu-server -t docker

# shellcheck disable=SC2317
play() (
  local PROJ_DIR; PROJ_DIR="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")/.."
  local REQS_DIR=vendor
  local REQS_FILE=./requirements.yaml
  # Configurable via BOOKSHELF_INVENTORY_FILE
  # Relative to the PROJ_DIR or absolute path
  local INVENTORY_FILE="${BOOKSHELF_INVENTORY_FILE-./hosts.yaml}"

  declare -a COLLECTIONS_CMD=(
    ansible-galaxy collection install -r "${REQS_FILE}" -p "${REQS_DIR}"
  )
  declare -a PLAYBOOK_CMD=(
    ansible-playbook ./playbook.yaml -i "${INVENTORY_FILE}"
  )

  init() {
    if grep -qxf <(printf -- '%s\n' \
      '--list-.\+' \
      '-\(h\|-help\)' \
    ) <<< "${1}"; then
      COLLECTIONS_CMD=(true)
      return
    fi

    cat -- "${PROJ_DIR}/${REQS_FILE}" &>/dev/null || COLLECTIONS_CMD=(true)
  }

  main() {
    init "${@}"

    cd -- "${PROJ_DIR}" || return

    (set -x; "${COLLECTIONS_CMD[@]}") || return

    if [ -n "${BOOKSHELF_VAULT_PASS+x}" ]; then
      (set -x; "${PLAYBOOK_CMD[@]}" --vault-pass-file <(printenv BOOKSHELF_VAULT_PASS) "${@}") || return
    else
      cat -- "${PROJ_DIR}/vaulted.txt" &>/dev/null && PLAYBOOK_CMD+=(-J)
      (set -x; "${PLAYBOOK_CMD[@]}" "${@}") || return
    fi
  }

  main "${@}"
)

(return 2>/dev/null) || play "${@}"
