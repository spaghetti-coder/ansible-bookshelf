#!/usr/bin/env bash

cheat-tmux() { _cheatsheet_browse https://tmuxcheatsheet.com "${@}"; }
cheat-vim() { _cheatsheet_browse https://vim.rtorr.com "${@}"; }


# ~~~~~ CORE ~~~~~


_cheatsheet_browse() {
  local caller="${FUNCNAME[1]}"
  local prefix='cheat-'
  local target

  # shellcheck disable=SC2034
  local T_BOLD='\033[1m' \
        T_DIM='\033[2m' \
        T_ITALIC='\033[3m' \
        T_UNDER='\033[4m' \
        T_RESET='\033[0m'

  [[ "${caller}" == "${prefix}"* ]] || {
    echo "Direct ${FUNCNAME[0]} call is not allowed." >&2
    return 1
  }

  # shellcheck disable=SC2001
  target="$(sed -e 's/^'"${prefix}"'//' <<< "${caller}")"

  if [[ "${2}" =~ ^-\?|-h|--help$ ]]; then
    sed -e 's/^\s\+//' -e 's/\s\+$//' -e '/^$/d' -e 's/^,//' <<< "
      Get a cheatsheet link for ${target}.
     ,
      USAGE:
      ~~~~~
      ${caller}
    "
    return
  fi

  echo -e "${T_DIM}Open:${T_RESET} ${1}" >&2
}
