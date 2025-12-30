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
    echo "${FUNCNAME[0]} can't be called directly." >&2
    return 1
  }

  # shellcheck disable=SC2001
  target="$(sed -e 's/^'"${prefix}"'//' <<< "${caller}")"

  if [[ "${2}" =~ ^-\?|-h|--help$ ]]; then
    sed -e 's/^\s\+//' -e 's/\s\+$//' -e '/^$/d' -e 's/^,//' <<< "
      Cheatsheet for ${target}.
      Open cheatsheet in a browser or hint a link to it if non-DE mode.
     ,
      Supported options:
     ,  -d, --dry       Dry run, i.e. print the link to console
    "
    return
  fi

  [[ "${2}" =~ ^-d|--dry$ ]] && { echo -e "${T_DIM}Open:${T_RESET} ${1}" >&2; return; }

  if \
    { [ -n "${SSH_TTY+x}" ] && [ -n "${SSH_CONNECTION+x}" ]; } \
    || ! xdg-open --version &>/dev/null \
  ; then              # <- Either remote machine or nothing to open with
    "${caller}" -d; return
  fi

  (set -x; xdg-open "${1}" &) >/dev/null
}
