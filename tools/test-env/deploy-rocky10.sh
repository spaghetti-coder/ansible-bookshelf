#!/usr/bin/env bash

# shellcheck disable=SC2317,SC1090,SC1091,SC2034

#
# NOTE:
#   * requires devenv with the following vars exported in the _devenv_config:
#     * DEPLOY_VE_PVE_HOST
#     * DEPLOY_VE_ROCKY_ID   # <- VE ID
#     * DEPLOY_VE_ROCKY_IP   # <- Ex.: 192.168.0.20/24
#     * DEPLOY_VE_GW        # <- Ex.: 192.168.0.1
#     * DEPLOY_VE_STORAGE   # <- Ex.: local-lvm
#     * DEPLOY_VE_SNAPSHOT  # <- Ex.: Ansible1
#   * _devenv_config function itself must be exported
#

. "$(dirname -- "${BASH_SOURCE[0]}")/../../knowledgebase/deploy-demo-lxc.sh"

deploy_ve_config() {
  _devenv_config || return

  # More config:
  # * deploy_ve.main   # <- Deployment flow + customizations

  PVE_HOST="${DEPLOY_VE_PVE_HOST}"  # <- Only REQUIRED for remote deployment
  REMOTE_EXPORTS+=(                 # <- Functions to be exported to remote PVE
    _devenv_config
  )

  # Best match from available templates: http://download.proxmox.com/images/system
  VE_TEMPLATE=rockylinux-10
  VE_ID="${DEPLOY_VE_ROCKY_ID}"

  CREATE_FLAGS=(              # <- Create LXC flags, '--password' is autoappended with value from EXTRAS[root_pass]
    --unprivileged=1          # <- '0' if using bind mounts, or use boring workarounds for ownership
    --features='nesting=1,keyctl=1'   # <- ',keyctl=1' Not needed with privileged
    --net0="name=eth0,bridge=vmbr0,ip=${DEPLOY_VE_ROCKY_IP},gw=${DEPLOY_VE_GW}"
    --storage="${DEPLOY_VE_STORAGE}"
    --hostname=ansible-rocky10.test.home
    --rootfs=20
    --timezone=host
    --onboot=0
    --memory=1024             # <- Due to huge number of services to test
    --swap=512
    --cores=1
    --tags='ansible;test.home'
  )

  # User passwords ara in plain text, hash them with openssl
  EXTRAS=(
    [root_pass]="$(openssl passwd -6 -stdin <<< "${ANSIBLE_USER_PASS}")"
    # Used by custom provisioners
    [user1_name]="${ANSIBLE_USER}"
    [user1_uid]=1000
    [user1_pass]="$(openssl passwd -6 -stdin <<< "${ANSIBLE_USER_PASS}")"
    [user2_name]=bug2
    [user2_uid]=1001
    [user2_pass]="$(openssl passwd -6 -stdin <<< "${ANSIBLE_USER_PASS}")"
    [snapshot]="${DEPLOY_VE_SNAPSHOT}"
  )
}

deploy_ve() (
  #
  # TODO:
  #   * check all customizations values
  #

  main() {
    create_ve || return   # <- Create the VE

    # Configure VE (toggle with true / false)
    # profile_disable_apparmor false || return  # <- Fix docker: https://github.com/opencontainers/runc/issues/4968
    profile_docker_ready true || return
    profile_vaapi true || return
    profile_vpn_ready true || return

    # Provisioning
    start_ve || return
      fix_locale || return
      install_ansible_prereqs || return

      # Custom provisioning
      create_lxc_user "${EXTRAS[user1_name]}" "${EXTRAS[user1_uid]}" "${EXTRAS[user1_pass]}" || return
      create_lxc_user "${EXTRAS[user2_name]}" "${EXTRAS[user2_uid]}" "${EXTRAS[user2_pass]}" || return
    stop_ve || return     # <- To ensure changes applied on the next start

    (set -x; pct snapshot "${VE_ID}" "${EXTRAS[snapshot]}" >/dev/null) || return
    # start_ve || return    # <- To start the VE immediately
  }

  create_lxc_user() {
    local name="${1}" uid="${2}" pass="${3}"
    log_info "${FUNCNAME[0]} (${name}) ..."
      cat <<< "${name}:${pass}" | lxc-attach -n "${VE_ID}" -- /bin/sh -c "
        set -x
        groupadd -g '${uid}' '${name}' \
        && useradd -g '${uid}' -G wheel -u '${uid}' -m '${name}' \
        && chpasswd -e
      " || return
    log_info "${FUNCNAME[0]} DONE"
  }

  main
)


# ==================== END OF CONFIGURATION ZONE ====================


(return 2>/dev/null) || { deploy_ve_core "${@}"; exit; }
return    # <- If this line is hit, the file is sourced. Makes code that follows unreachable
