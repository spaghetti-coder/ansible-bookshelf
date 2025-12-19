#!/usr/bin/env bash
# shellcheck disable=SC1091

_log_sth() {
  local style1="T_${1^^}"
  local style2="T_${2^^}"
  local text_styled_both="${3}"
  local text_styled2="${4}"
  local text_unstyled="${5}"

  # shellcheck disable=SC2034
  local \
    T_BOLD='\033[1m' \
    T_DIM='\033[2m' \
    T_ITALIC='\033[3m' \
    T_UNDER='\033[4m' \
    T_RED='\033[31m' \
    T_GREEN='\033[32m' \
    T_YELLOW='\033[33m' \
    T_RESET='\033[0m'
  local \
    t_style1="${!style1}" \
    t_style2="${!style2}"

  printf -- "${t_style1}${t_style2}%s${T_RESET}${t_style2}%s${T_RESET}%s\n" \
    "${text_styled_both}" \
    "${text_styled2}" \
    "${text_unstyled}" >&2
}
log_info()    { _log_sth bold yellow "INFO: " "" "${1}"; }
log_warn()    { _log_sth bold yellow "WARN: " "" "${1}"; }
log_fatal()   { _log_sth bold red "FATAL: " "${1}" ""; }
log_comment() { _log_sth dim italic "${1}" "" ""; }
log_doing()   { _log_sth bold yellow "DOING: " "" "${1}"; }
log_done()    { _log_sth bold green "DONE: " "" "${1}"; }
crash()       { log_fatal "${1}"; exit; }


# shellcheck disable=SC2120
print_help() {
  local self="${1:-ubuntu-init-setup.sh}"

  cat -- "${0}" 2>/dev/null \
    | grep -qF -e "${FUNCNAME[0]}" -e "${self}" \
  && self="$(basename -- "${0}" 2>/dev/null)"

  sed -e 's/^\s\+//' -e '/^$/d' -e 's/^,//' <<< "
    Install ansible prereqs.
   ,
    DEMO
    ~~~~
    ${self} ctl           # <- Install control machine prereqs
    ${self} target        # <- Install target machine prereqs
    ${self} ctl target    # <- Install prereqs for both
    ssh -- host.local 'sudo /bin/bash -s -- target' < ${self}
  "
}


check_env() {
  (unset UBUNTU_CODENAME 2>/dev/null; . /etc/os-release; [ -n "${UBUNTU_CODENAME}" ]) || {
    log_fatal "Must be run on an Ubuntu flavour"
    return 1
  }
  [ "$(id -u)" -lt 1 ] || { log_fatal "Root privileges required"; return 1; }
}


do_pm_update() {
  ${DONE_PM_UPDATE:-false} && return
  (set -x; apt-get -q update >/dev/null) || return
  DONE_PM_UPDATE=true
}


do_install_curl() {
  ${DONE_INSTALL_CURL:-false} && return
  do_pm_update && (set -x; apt-get install -qy curl >/dev/null)
  DONE_INSTALL_CURL=true
}


do_provision_target() {
  local do_provision="${1:-true}"

  ${do_provision} || {
    log_info "Skipping ansible target machine prereqs install due to no 'target'"
    return
  }

  log_doing "Install ansible target machine prereqs ..."

  do_pm_update \
  && (
    set -x
    apt-get install -qy python3 openssh-server >/dev/null
  ) || return

  log_done "Install ansible target machine prereqs ..."
}


do_provision_ctl() {
  local do_provision="${1:-true}"

  ${do_provision} || {
    log_info "Skipping ansible control machine prereqs install due to no 'ctl'"
    return
  }

  log_doing "Install ansible control machine prereqs ..."

  local keyring_url='https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x6125e2a8c77f2818fb7bd15b93c4a3fd7bb9c367'
  local keyring_file=/etc/apt/keyrings/ansible.asc
  local codename; codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME}")" || return
  local list_file=/etc/apt/sources.list.d/ansible.list
  local -a sources=(
    "deb [signed-by=${keyring_file}] https://ppa.launchpadcontent.net/ansible/ansible/ubuntu ${codename} main"
    "deb-src [signed-by=${keyring_file}] https://ppa.launchpadcontent.net/ansible/ansible/ubuntu ${codename} main"
  )

  # Setup ansible repo
  do_pm_update \
  && do_install_curl \
  && printf -- '%s\n' "${sources[@]}" | (
    set -x
    apt-get install -qy openssh-client >/dev/null \
    && curl -fsSLo "${keyring_file}" -- "${keyring_url}" \
    && tee -- "${list_file}" >/dev/null
  ) || return

  # Install ansible and ansible-lint
  { DONE_PM_UPDATE=false do_pm_update; } \
  && (
    set -x
    apt-get install -qy ansible >/dev/null \
    && apt-get install -qy pipx >/dev/null
  ) \
  && (
    set -x
    export PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin
    pipx install -q ansible-lint >/dev/null \
    && pipx upgrade -q ansible-lint >/dev/null
  ) || return

  log_done "Install ansible control machine prereqs"
}


do_ansible_prereqs() {
  # Defaults
  local CTL=false
  local TARGET=false

  if [[ "${1}" =~ ^(-\?|-h|--help|help)$ ]]; then
    print_help; exit
  fi

  [ $# -gt 0 ] || { crash "Command required"; }

  # Parse args
  local -a invals=()
  for opt in "${@}"; do
    case "${opt}" in
      ctl     ) CTL=true ;;
      target  ) TARGET=true ;;
      *       ) invals+=("${opt}")
    esac
  done
  [ ${#invals[@]} -lt 1 ] || {
    log_fatal "Invalid args"
    printf -- '  %s\n' "${invals[@]}"
    exit 1
  }

  check_env || exit

  do_provision_target "${TARGET}"   || exit
  do_provision_ctl "${CTL}"         || exit
}





# Return if sourced as a lib or continue
# execution if running as a script
(return 2>/dev/null) && return

do_ansible_prereqs "${@}"
