#!/usr/bin/env bash

# shellcheck disable=SC2317,SC1090,SC1091,SC2034

#
# NOTE:
#   * requires devenv with the following vars exported in the _devenv_config:
#     * DEPLOY_VE_PVE_HOST
#     * DEPLOY_VE_UBUNTU_ID # <- VE ID
#     * DEPLOY_VE_UBUNTU_IP # <- Ex.: 192.168.0.20/24
#     * DEPLOY_VE_GW        # <- Ex.: 192.168.0.1
#     * DEPLOY_VE_STORAGE   # <- Ex.: local-lvm
#     * DEPLOY_VE_SNAPSHOT  # <- Ex.: Ansible1
#   * _devenv_config function itself must be exported
#

#
# REQUIREMENTS:
# * PVE host must have age installed
# * For remote deployment execution host must have SSH access to PVE_HOST and
#   age installed
#

. "$(dirname -- "${BASH_SOURCE[0]}")/../../knowledgebase/deploy-demo-lxc.sh"

deploy_ve_config() {
  _devenv_config || return

  # More config:
  # * deploy_ve.main   # <- Deployment flow + customizations

  # Generate with:
  #   THE_SCRIPT gen-age  # <- Prompts for passphrase
  # Internally in the script decrypt encrypted by this AGE_KEY secrets with:
  #   echo PLAIN_SECRET | THE_SCRIPT encrypt-secret `# => AGE_ENCRYPTED_SECRET` | decrypt_secret `# => PLAIN_SECRET`
  AGE_KEY=""

  PVE_HOST="${DEPLOY_VE_PVE_HOST}"

  # Best match from available templates: http://download.proxmox.com/images/system
  VE_TEMPLATE=ubuntu-24.04
  VE_ID="${DEPLOY_VE_UBUNTU_ID}"

  CREATE_FLAGS=(              # <- Create LXC flags, '--password' is autoappended with value from EXTRAS[root_pass]
    --unprivileged=1          # <- '0' if using bind mounts, or use boring workarounds for ownership
    --features='nesting=1,keyctl=1'   # <- ',keyctl=1' Not needed with privileged
    --net0="name=eth0,bridge=vmbr0,ip=${DEPLOY_VE_UBUNTU_IP},gw=${DEPLOY_VE_GW}"
    --storage="${DEPLOY_VE_STORAGE}"
    --hostname=ansible-ubuntu.test.home
    --rootfs=20
    --timezone=host
    --onboot=0
    --memory=1024
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
    [snapshot]="${DEPLOY_VE_SNAPSHOT}"
  )

  # In case of remote deployment, the script copies only functions from the
  # current script to PVE_HOST and executes them. In case you need to export
  # more functions to use them here, add them to this array
  PVE_COPY_FUNC=(_devenv_config)
}

deploy_ve() (
  #
  # TODO:
  #   * check all customizations values
  #

  main() {
    create_ve || return   # <- Create the VE

    # Configure VE (toggle with true / false)
    profile_disable_apparmor true || return  # <- Fix docker: https://github.com/opencontainers/runc/issues/4968
    profile_docker_ready true || return
    profile_vaapi true || return
    profile_vpn_ready true || return

    # Provisioning
    start_ve || return
      fix_locale || return
      install_ansible_prereqs || return

      # Custom provisioning
      create_lxc_user || return
    stop_ve || return   # <- To ensure changes applied on the next start

    (set -x; pct snapshot "${VE_ID}" "${EXTRAS[snapshot]}") || return

    # # To start VE immediately
    # start_ve || return
  }

  create_lxc_user() {
    # Demo provisioner
    #
    # * $VE_ID - LXC IC

    local name="${EXTRAS[user1_name]}"
    local pass; pass="$(decrypt_secret <<< "${EXTRAS[user1_pass]}")" || return

    echo "Do provision: ${FUNCNAME[0]} ..." >&2
      cat <<< "${name}:${pass}" | lxc-attach -n "${VE_ID}" -- /bin/sh -c "
        set -x
        groupadd -g '${EXTRAS[user1_uid]}' '${name}' \
        && useradd -g '${EXTRAS[user1_uid]}' -G sudo -u '${EXTRAS[user1_uid]}' -m '${name}' \
        && chpasswd -e
      " || return
    echo "Done provision: ${FUNCNAME[0]}" >&2
  }

  main
)


# ==================== END OF CONFIGURATION ZONE ====================


(return 2>/dev/null) || { deploy_ve_core "${@}"; exit; }
return    # <- If this line is hit, the file is sourced. Makes code that follows unreachable
