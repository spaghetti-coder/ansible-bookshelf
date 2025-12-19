#!/usr/bin/env bash
# shellcheck disable=SC2001,SC2317,SC2329,SC1091


FZF_VERSION=0.67.0    # <- https://github.com/junegunn/fzf/releases


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
    Perform basic Ubuntu initial setup. Root privileges required. Features:
   ,  - System packages upgrade
   ,  - Install guest agent if the host is KVM
   ,  - Install brave browser if the host has DE
   ,  - Passwordless sudo (optional) for the target user
   ,  - Install envar for the target user
   ,  - Install git PS1 for the target user
   ,  - Install fzf with sane profile for the target user
   ,  - Install tmux with sane profile for the target user
   ,
    USAGE
    ~~~~~
    ${self}         # <- Initial ubuntu setup
    ${self} nopass  # <- Same + no-password sudo
   ,
    DEMO
    ~~~~
    # Target user is the one who runs 'sudo'
    sudo ${self}
    sudo ${self} nopass
    sudo bash -s -- nopass < ${self}
    ssh -- host.local 'sudo /bin/bash -s --' < ${self}
   ,
    # Target user is root
    sudo su -l root bash -c '${self}'
   ,
    # Use as library
    echo '. ${self}; do_upgrade' | sudo bash -s
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
  do_pm_update && (set -x; apt-get install -qy curl >/dev/null) || return
  DONE_INSTALL_CURL=true
}


do_install_tar() {
  ${DONE_INSTALL_TAR:-false} && return
  do_pm_update && (set -x; apt-get install -qy tar >/dev/null) || return
  DONE_INSTALL_TAR=true
}


do_upgrade() {
  log_doing "Upgrade ..."

  do_pm_update && (set -x; apt-get dist-upgrade -q -y >/dev/null) || return

  log_done "Upgrade"
}


do_install_guest_agent() {
  if ! systemd-detect-virt | grep -iqFx 'kvm'; then
    log_warn "Not KVM, skipping guest agent"
    return
  fi

  log_doing "Install guest agent ..."

  do_pm_update && (set -x; apt-get install -qy qemu-guest-agent >/dev/null) || return

  log_done "Install guest agent"
}


do_install_brave() {
  {
    # https://www.baeldung.com/linux/identify-window-manager-desktop-environment
    echo "${XDG_CURRENT_DESKTOP}"
    ls -1 /usr/share/xsessions/ 2>/dev/null
  } | grep -q '.\+' || {
    log_info "Can't detect Desktop Environment, skipping brave"
    return
  }

  log_doing "Install brave browser ..."

  local keyring_url='https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg'
  local keyring_file=/etc/apt/keyrings/brave-browser-archive-keyring.gpg

  do_install_curl \
  && sed -e 's/^\s\+//' -e '/^$/d' <<< "
    Types: deb
    URIs: https://brave-browser-apt-release.s3.brave.com
    Suites: stable
    Components: main
    Architectures: amd64 arm64
    Signed-By: ${keyring_file}
  " | (
    set -x
    curl -fsSL -o "${keyring_file}" -- "${keyring_url}" \
    && tee /etc/apt/sources.list.d/brave-browser-release.sources >/dev/null
  ) \
  && { DONE_PM_UPDATE=false; do_pm_update; } \
  && (set -x; apt-get install -qy brave-browser >/dev/null) \
  || return

  log_done "Install brave browser"
}


do_nopass_sudo() {
  # USAGE
  #   do_nopass_sudo [true|false]  # <- Defaults to true

  local nopass="${1:-true}"
  init_user_vals || return

  [ "${TARGET_UID}" -gt 0 ] || {
    log_info "Skipping no-pass sudo for ${TARGET_USER}, no need for root"
    return
  }
  ${nopass} || {
    log_info "Skipping no-pass sudo for ${TARGET_USER} due to no 'nopass'"
    return
  }

  log_doing "Configure no-pass sudo for ${TARGET_USER} ..."

  echo "${TARGET_USER} ALL=(ALL) NOPASSWD: ALL" | (
    set -x
    tee "/etc/sudoers.d/${TARGET_USER}" >/dev/null
  ) || return

  log_done "Configure no-pass sudo for ${TARGET_USER}"
}


do_setup_envar() {
  ${DONE_SETUP_ENVAR:-false} && return
  init_user_vals || return

  log_doing "Install envar and configure for ${TARGET_USER} ..."

  local script_url="https://github.com/spaghetti-coder/ansible-bookshelf/raw/master/roles/base/envar/files/envar.sh"

  do_install_curl \
  && (
    set -o pipefail
    (set -x; curl -fsSL -- "${script_url}") \
    | bash -s -- install >/dev/null \
    && /opt/varlog/envar/envar.sh setup "${TARGET_USER}" >/dev/null
  ) || return
  DONE_SETUP_ENVAR=true

  log_done "Install envar and configure for ${TARGET_USER}"
}


do_setup_ps1() {
  init_user_vals || return

  log_doing "Configure PS1 for ${TARGET_USER} ..."

  local profile_url="https://github.com/spaghetti-coder/ansible-bookshelf/raw/master/roles/base/ps1-git/files/ps1-git.sh"

  do_install_curl \
  && do_setup_envar \
  && (
    set -o pipefail; set -x
    curl -fsSL -- "${profile_url}" \
    | tee /etc/envar/ps1-git.sh >/dev/null \
    && ln -fs /etc/envar/ps1-git.sh "${TARGET_HOME}/.envar.d/500-ps1-git.sh"
  ) || return

  log_done "Configure PS1 for ${TARGET_USER}"
}


do_setup_fzf() {
  init_user_vals || return

  log_doing "Install fzf and configure for ${TARGET_USER} ..."

  local tgz_url="https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz"
  local profile_url="https://raw.githubusercontent.com/spaghetti-coder/ansible-bookshelf/master/roles/base/fzf/templates/fzf.bash.sh.j2"

  do_install_curl \
  && do_install_tar \
  && do_setup_envar \
  && (
    set -o pipefail; set -x
    mkdir -p /opt/junegunn/fzf \
    && curl -fsSL -- "${tgz_url}" | tar -xzf - -C /opt/junegunn/fzf \
    && ln -fs /opt/junegunn/fzf/fzf /usr/bin/fzf \
    && curl -fsSL -o /etc/envar/fzf.skip.sh -- "${profile_url}" \
    && ln -fs /etc/envar/fzf.skip.sh "${TARGET_HOME}/.envar.d/500-fzf.sh"
  ) || return

  log_done "Install fzf and configure for ${TARGET_USER}"
}


do_setup_tmux() {
  init_user_vals || return

  log_doing "Install tmux and configure for ${TARGET_USER} ..."

  local profile_url="https://raw.githubusercontent.com/spaghetti-coder/ansible-bookshelf/master/roles/base/tmux/files/default.conf"

  do_pm_update \
  && do_install_curl \
  && echo 'source-file /etc/tmux/default.conf' | (
    set -x
    apt-get install -qy tmux >/dev/null \
    && mkdir -p /etc/tmux \
    && curl -fsSL -o /etc/tmux/default.conf -- "${profile_url}" \
    && tee "${TARGET_HOME}/.tmux.conf" >/dev/null \
    && chown "${TARGET_UID}:${TARGET_GID}" "${TARGET_HOME}/.tmux.conf"
  ) || return

  log_done "Install tmux and configure for ${TARGET_USER}"
}


do_cleanup() {
  log_doing "Cleanup ..."

  (
    set -x
    apt-get clean -q -y >/dev/null \
    && apt-get autoremove -q -y >/dev/null
  ) || return

  log_done "Cleanup"
}


init_user_vals() {
  TARGET_USER="${SUDO_USER:-${USER}}"
  TARGET_UID="$(id -u "${TARGET_USER}")"        || return
  TARGET_GID="$(id -g "${TARGET_USER}")"        || return
  TARGET_HOME="$(eval echo "~${TARGET_USER}")"  || return
}


do_init_setup() {
  # Defaults
  local NOPASS=false

  if [[ "${1}" =~ ^(-\?|-h|--help|help)$ ]]; then
    print_help; exit
  fi

  # Parse args
  local -a invals=()
  for opt in "${@}"; do
    case "${opt}" in
      nopass  ) NOPASS=true ;;
      *       ) invals+=("${opt}")
    esac
  done
  [ ${#invals[@]} -lt 1 ] || {
    log_fatal "Invalid args"
    printf -- '  %s\n' "${invals[@]}"
    exit 1
  }

  check_env       || exit
  init_user_vals  || exit

  log_info "Target user: ${TARGET_USER}"
  do_upgrade                  || crash Error
  do_install_guest_agent      || crash Error
  do_install_brave            || crash Error
  do_nopass_sudo "${NOPASS}"  || crash Error
  do_setup_envar              || crash Error
  do_setup_ps1                || crash Error
  do_setup_fzf                || crash Error
  do_setup_tmux               || crash Error
  do_cleanup                  || crash Error

  echo >&2
  echo '~~~~~~~~~~~~~~~~~~~~' >&2
  log_info "Optional additional steps:"
  echo >&2
  log_comment "# Apply bash related changes:" >&2
  echo ". ~/.bashrc" >&2
  echo >&2
  log_comment "# Cleanup bash history:" >&2
  echo "rm ~/.bash_history 2>/dev/null" >&2
  echo "history -c 0" >&2
}





# Return if sourced as a lib or continue
# execution if running as a script
(return 2>/dev/null) && return

do_init_setup "${@}"
