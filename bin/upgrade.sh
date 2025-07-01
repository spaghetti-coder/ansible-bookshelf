#!/usr/bin/env bash

upgrade() {
  local SELF_DIR; SELF_DIR="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")"
  declare -a THE_CMD=(play -t upgradable)

  local main_branch=master

  main() {
    cd -- "${SELF_DIR}/.." || return

    git rev-parse --abbrev-ref HEAD | grep -qFx "${main_branch}" || {
      echo "Can't perform upgrade while in not ${main_branch} branch" >&2
      return 1
    }

    git status --porcelain | grep -q '.' && {
      echo "Can't perform upgrade in not clean branch" >&2
      return 1
    }

    # shellcheck disable=SC1091
    . "${SELF_DIR}/play.sh"
    "${THE_CMD[@]}" "${@}"
  }

  main "${@}"
}

(return 2>/dev/null) || upgrade "${@}"
