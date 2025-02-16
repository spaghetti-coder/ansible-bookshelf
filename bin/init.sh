#!/usr/bin/env bash

# shellcheck disable=SC2317
init() (
  collections() {
    (set -x; ansible-galaxy collection install -r ./requirements.yaml -p ./requirements "${@}")
  }

  main() {
    "${@}"
  }

  main "${@}"
)

(return 2>/dev/null) || (
  declare PROJ_DIR; PROJ_DIR="$(dirname -- "${BASH_SOURCE[0]}")/.."
  cd -- "${PROJ_DIR}" || exit

  .dev/build.sh
  init collections "${@}" || exit
)
