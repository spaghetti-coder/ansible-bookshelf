#!/usr/bin/env bash

# shellcheck disable=SC2317
play() (
  main() {
    declare PROJ_DIR; PROJ_DIR="$(dirname -- "${BASH_SOURCE[0]}")/.."
    cd -- "${PROJ_DIR}" || return

    (set -x; ansible-playbook ./playbook.yaml -i ./hosts.yaml "${@}")
  }

  main "${@}"
)

(return 2>/dev/null) || play "${@}"
