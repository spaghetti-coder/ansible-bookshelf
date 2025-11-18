#!/usr/bin/env bash

# shellcheck disable=SC2016
deploy_ve_config() {
  #
  # NOTES:
  # * In this demo all the passwords and passphrases are 'changeme'
  #

  # More config:
  # * deploy_ve.main   # <- Deployment flow + customizations

  PVE_HOST=pve.local          # <- Only REQUIRED for remote deployment
  REMOTE_EXPORTS+=()          # <- Functions to be exported to remote PVE

  # Best match from available templates: http://download.proxmox.com/images/system
  VE_TEMPLATE=alpine-3
  VE_ID=6101                  # <- Make sure >= 100
  # VE_ID="$(pvesh get /cluster/nextid 2>/dev/null)"  # <- Not recommended, not idempotent

  CREATE_FLAGS=(              # <- Create LXC flags, '--password' is autoappended with value from EXTRAS[root_pass]
    --unprivileged=1          # <- '0' if using bind mounts, or use boring workarounds for ownership
    --features='nesting=1,keyctl=1'   # <- ',keyctl=1' Not needed with privileged
    --net0="name=eth0,bridge=vmbr0,ip=dhcp"
    # --net0="name=eth0,bridge=vmbr0,ip=192.168.0.20/24,gw=192.168.0.1"   # <- Alternatively configure IP
    --storage=local-lvm       # <- Select your storage
    --hostname=test.home      # <- Ensure corrent hostname
    --rootfs=10
    --timezone=host
    --onboot=1
    --memory=1024             # <- In MB
    --swap=512
    --cores=1
    --tags='test.home;testing'
  )

  EXTRAS=(
    # Linux user password encryption:
    #   openssl passwd -6 -stdin < PASSWORD_FILE
    # Or generate random pass and login via ssh (use `--ssh-public-keys FILE` create option)
    #   tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20 | openssl passwd -6 -stdin
    [root_pass]='$6$Ayj0X9RVknuCsFPQ$PJjtQmanIN2F5nC/Eca4m.ZLAImxkiJGOwajIYVOyIxnOg5u9fv7IyjvkC5SB9HoMi5cpXuhjCfijizd.IbH70'
    # Used by custom provisioners
    [user1_name]=user1
    [user1_uid]=1000
    # Use chpasswd tool to set the password
    #   echo "${EXTRAS[user1_name]}:${EXTRAS[user1_pass]}" | chpasswd -e
    [user1_pass]='$6$iD2MkmDVv79CVg7m$H6tKPEPF77SusBOaXiKai9ZOCPJssx.TjcB.lkE2msqTDP/1yVH9QOfsDT7G/cEcGv7EA.cv33LMJVTFQlG6u0'
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
    profile_vaapi false || return
    profile_vpn_ready false || return

    # Provisioning
    start_ve || return
      fix_locale || return
      install_ansible_prereqs || return

      # Custom provisioning
      create_lxc_user "${EXTRAS[user1_name]}" "${EXTRAS[user1_uid]}" "${EXTRAS[user1_pass]}" || return
    stop_ve || return     # <- To ensure changes applied on the next start

    # (set -x; pct snapshot "${VE_ID}" Init1 >/dev/null) || return    # <- Create snapshot
    start_ve || return    # <- To start the VE immediately
  }

  create_lxc_user() {
    # Demo provisioner
    #
    # * $VE_ID - LXC ID

    local name="${1}" uid="${2}" pass="${3}"
    log_info "${FUNCNAME[0]} ..."
      cat <<< "${name}:${pass}" | lxc-attach -n "${VE_ID}" -- /bin/sh -c "
        set -x
        apk add -q --update --no-cache shadow sudo \
        && groupadd -g '${uid}' '${name}' \
        && useradd -g '${uid}' -G wheel -u '${uid}' -m '${name}' \
        && { echo '%wheel ALL=(ALL) ALL' | tee /etc/sudoers.d/wheel >/dev/null; } \
        && chpasswd -e
      " || return
    log_info "${FUNCNAME[0]} DONE"
  }

  main
)


# ==================== END OF CONFIGURATION ZONE ====================


# shellcheck disable=SC2317,SC2329
deploy_ve_core() (
  local SELF_SCRIPT=pve-deploy-lxc.sh
  grep -q '.\+' -- "${0}" 2>/dev/null && SELF_SCRIPT="$(basename -- "${0}" 2>/dev/null)"

  local PVE_HOST VE_ID VE_TEMPLATE
  declare -A EXTRAS
  declare -a CREATE_FLAGS REMOTE_EXPORTS
  declare -i START_DELAY=15

  declare -A CMD_MAP=(
    [local]=deploy_local
    [remote]='<DUMMY>' # Handled by trap_remote
    # Primitives
    [-?]=print_demo
    [-h]=print_demo
    [--help]=print_demo
  )

  # https://stackoverflow.com/a/42449998
  # shellcheck disable=SC2034
  local T_BOLD='\033[1m' \
        T_DIM='\033[2m' \
        T_ITALIC='\033[3m' \
        T_UNDER='\033[4m' \
        T_RED='\033[31m' \
        T_GREEN='\033[32m' \
        T_RESET='\033[0m'

  #
  # CORE
  #

  start_ve() {
    # Set OS warmup delay, Alpine boots faster
    local delay="${START_DELAY}"
    get_ve_option ostype | grep -qix 'alpine' && delay=5

    START_DELAY=5   # <- Don't need next delay to be so long
    (set -x; pct start "${VE_ID}" && sleep -- "${delay}") || return
  }

  stop_ve() (set -x; pct stop "${VE_ID}" || return)

  # shellcheck disable=SC2317
  create_ve() {
    local template; template="$(get_template_file "${VE_TEMPLATE}")" || return
    local pass="${EXTRAS[root_pass]}"

    local -a THE_CMD=(
      pct create "${VE_ID}" "${template}"
        "${CREATE_FLAGS[@]}"
        --password "${pass}"      # <- Must be in the very end
    )

    ( set -o pipefail
      (set -x; "${THE_CMD[@]}" >/dev/null) 3>&1 1>&2 2>&3 \
      | sed -e 's/\(--password[= ]\)[^ ]\+/\1*****/g'
    ) 3>&1 1>&2 2>&3 || return
  }

  get_template_file() {
    local template_rex; template_rex="$(sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1}")"
    local templates_url=http://download.proxmox.com/images/system
    local templates_home=/var/lib/vz/template/cache

    # Get last template version filename
    local template; template="$( set -o pipefail
      curl -fsSL "${templates_url}" | grep -o 'href="[^"]\+\.tar\..\+"' \
      | sed -e 's/^href="\(.\+\)"/\1/' | sort -V | grep -- "^${template_rex}" | tail -n 1
    )" || return

    # Download last template if not found locally
    [ -f "${templates_home}/${template}" ] || (
      set -x; cd "${templates_home}" && curl -fsSL -O "${templates_url}/${template}"
    ) || return

    echo "${templates_home}/${template}"
  }

  get_ve_option() {
    # USAGE:
    #   ostype="$(get_ve_option ostype)" || `# Process setting not found`
    #   echo "${ostype}"  # Sample output: alpine

    local opt="${1}"
    local opt_rex; opt_rex="$(sed -e 's/[]\/$*.^[]/\\&/g' <<< "${opt}")"

    ( set -o pipefail
      grep -m 1 '^\s*'"${opt_rex}"'\s*[:=]\s*' "/etc/pve/lxc/${VE_ID}.conf" \
      | sed -e 's/^[^:=]\+[:=]\s*\(.*\)/\1/' -e 's/\s*$//'
    )
  }

  is_privileged() {
    # USAGE:
    #   is_privileged && `# Do for privileged` || `# Do for unprivileged`

    local unprivileged_opt; unprivileged_opt="$(get_ve_option unprivileged || echo 0)"
    [ "${unprivileged_opt}" -eq 0 ]
  }

  # ~~~~~ PROFILES ~~~~~

  profile_attach_hookscripts() {
    # USAGE:
    #   profile_attach_hookscripts CALLBACK_FNC
    # DEMO:
    #   test() { local CT_ID="${1}" PHASE="${2}"; echo "${CT_ID} ${PHASE}" >&2; }
    #   profile_attach_hookscripts test
    # -----
    # NOTE: Overrides VE_ID.hook.sh snippet if exists

    [ $# -lt 1 ] && return

    local dest_file="/var/lib/vz/snippets/${VE_ID}.hook.sh"
    local dest_fname; dest_fname="$(basename -- "${dest_file}")"

    log_info "${FUNCNAME[0]} ..."
      local -a func_names func_bodies

      local cbk; for cbk in "${@}"; do
        # shellcheck disable=SC2016
        func_names+=("${cbk}"' "${@}"')
        func_bodies+=("$(declare -f "${cbk}")") || return
      done

      # shellcheck disable=SC2016
      printf -- '%s\n' '#!/usr/bin/env bash' \
        '' '_managed_hookstack() {' "${func_names[@]}" '} # _managed_hookstack' \
        '' "${func_bodies[@]}" \
        '' '_managed_hookstack "${@}"' \
      | (
        set -x
        tee -- "${dest_file}" >/dev/null \
        && chmod +x "${dest_file}" \
        && pct set "${VE_ID}" --hookscript "local:snippets/${dest_fname}"
      ) || return
    log_info "${FUNCNAME[0]} DONE"
  }

  profile_vpn_ready() {
    # USAGE:
    #   profile_vpn_ready [true|false]  # <- Defaults to false

    ${1-false} || return 0

    log_info "${FUNCNAME[0]} ..."
      local cap_drop_entry=''

      (set -o pipefail; get_ve_option 'lxc.cap.drop' | grep -qx '\s*') \
      || cap_drop_entry='lxc.cap.drop:'   # <- Seems to be needed only for GP client

      echo "
        lxc.mount.entry: /dev/net dev/net none bind,create=dir 0 0
        lxc.cgroup2.devices.allow: c 10:200 rwm
        ${cap_drop_entry}
      " | (
        set -o pipefail
        sed -e 's/^\s*//' -e '/^\s*$/d' | (set -x; tee -a "/etc/pve/lxc/${VE_ID}.conf" >/dev/null)
      ) || return
    log_info "${FUNCNAME[0]} DONE"
  }

  profile_docker_ready() {
    # USAGE:
    #   profile_docker_ready [true|false]  # <- Defaults to false

    ${1-false} || return 0

    log_info "${FUNCNAME[0]} ..."
      if is_privileged; then
        (set -o pipefail; get_ve_option 'lxc.cap.drop' | grep -qx '\s*') \
        || {
          echo 'lxc.cap.drop:' \
            | (set -x; tee -a "/etc/pve/lxc/${VE_ID}.conf" >/dev/null) \
          || return
        }
      fi
    log_info "${FUNCNAME[0]} DONE"
  }

  profile_vaapi() {
    # USAGE:
    #   profile_vaapi [true|false]   # <- Defaults to false

    ${1-false} || return 0

    log_info "${FUNCNAME[0]} ..."
      declare drm_dev=/dev/dri/renderD128

      if ! [[ -e "${drm_dev}" ]]; then
        echo -e "${T_BOLD}WARN${T_RESET}: ${drm_dev} not found" >&2
        return
      else
        if is_privileged; then
          echo "
            lxc.cgroup2.devices.allow: c 226:0 rwm
            lxc.cgroup2.devices.allow: c 226:128 rwm
            lxc.cgroup2.devices.allow: c 29:0 rwm
            lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file
            lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
            lxc.mount.entry: ${drm_dev} ${drm_dev#/*} none bind,optional,create=file
          "
        else
          echo "dev0: ${drm_dev},gid=104"

          if [[ -e /dev/dri/card1 ]]; then
            echo 'dev1: /dev/dri/card1,gid=44'
          else
            echo 'dev1: /dev/dri/card0,gid=44'
          fi
        fi | (
          set -o pipefail
          sed -e 's/^\s*//' -e '/^\s*$/d' | (set -x; tee -a "/etc/pve/lxc/${VE_ID}.conf" >/dev/null)
        ) || return
      fi
    log_info "${FUNCNAME[0]} DONE"
  }

  profile_disable_apparmor() {
    # USAGE:
    #   profile_disable_apparmor [true|false]  # <- Defaults to false

    ${1-false} || return 0

    local -a entries=("lxc.apparmor.profile: unconfined")
    get_ve_option ostype | grep -qix 'ubuntu' && {
      entries+=("lxc.mount.entry: /dev/null sys/module/apparmor/parameters/enabled none bind 0 0")
    }

    log_info "${FUNCNAME[0]} ..."
      printf -- '%s\n' "${entries[@]}" | (
        set -x; tee -a "/etc/pve/lxc/${VE_ID}.conf" >/dev/null
      ) || return
    log_info "${FUNCNAME[0]} DONE"
  }

  # ~~~~~ PROVISIONERS ~~~~~

  user_bind_mounts() {
    # USAGE:
    #   user_bind_mounts VE_USER HOST_DIR:VE_MOUNT_MOUNT...
    # DEMO:
    #   user_bind_mounts root /mnt/share:/root/share /mnt/conf:/root/conf
    # -----
    # NOTE: Requires VE running

    local owner="${1}"

    log_info "${FUNCNAME[0]} ..."
      declare src dest
      local kv; for kv in "${@:2}"; do
        src="${kv%%:*}" dest="${kv#*:}"

        lxc-attach -n "${VE_ID}" -- /bin/su -l "${owner}" -s \
          /bin/sh -c "set -x; mkdir -p '${dest}'" || return

        dest="$(sed 's/^\///' <<< "${dest}")"
        echo "lxc.mount.entry: ${src} ${dest} none bind,create=dir 0 0" \
        | (set -x; tee -a "/etc/pve/lxc/${VE_ID}.conf" >/dev/null)
      done
    log_info "${FUNCNAME[0]} DONE"
  }

  fix_locale() {
    log_info "${FUNCNAME[0]} ..."
      if get_ve_option ostype | grep -qix '\(ubuntu\|debian\)'; then
        lxc-attach -n "${VE_ID}" -- /bin/sh -c "
          set -x
          sed -i '"'s/^\s*#\s*\(en_US\.UTF-8\)/\1/'"' /etc/locale.gen && locale-gen >/dev/null
        " || return
      fi
    log_info "${FUNCNAME[0]} DONE"
  }

  install_ansible_prereqs() {
    # Supported platforms:
    # * alpine
    # * centos-like
    # * debian-like

    local cmds="
      apk add -q --update --no-cache openssh-server python3 sudo \
      && rc-update add sshd >/dev/null \
      && rc-service sshd start >/dev/null
    "

    if get_ve_option ostype | grep -qix '\(ubuntu\|debian\)'; then
      cmds="
        apt-get update -q >/dev/null \
        && DEBIAN_FRONTEND=noninteractive apt-get install -q -y openssh-server python3 sudo >/dev/null \
        && systemctl enable -q --now ssh
      "
    elif get_ve_option ostype | grep -qix 'centos'; then
      cmds="
        dnf install -qy openssh-server python3 sudo >/dev/null \
        && systemctl enable -q --now sshd
      "
    fi

    log_info "${FUNCNAME[0]} ..."
      lxc-attach -n "${VE_ID}" -- /bin/sh -c "set -x; ${cmds}" || return
    log_info "${FUNCNAME[0]} DONE"
  }

  # ~~~~~ HELPERS ~~~~~

  check_pve_host() {
    pveversion &>/dev/null && return
    log_fatal "Not PVE host"
    return 1
  }

  validate_command() {
    { [ -n "${CMD_MAP[${1}]}" ]; } &>/dev/null && return
    log_fatal "Invalid command: '${1}'"
    echo >&2
    print_demo
    return 1
  }

  # ~~~~~ LIB ~~~~~

  log_info()  { echo -e "${T_BOLD}${T_GREEN}INFO: ${T_RESET}${1}" >&2; }
  log_fatal() { echo -e "${T_RED}${T_BOLD}FATAL: ${T_RESET}${T_RED}${1}${T_RESET}" >&2; }

  # shellcheck disable=SC2001,SC2120
  escape_single_quote() { sed 's/'\''/'\''\\&'\''/g' <<< "${1-$(cat)}"; }
  # shellcheck disable=SC2001,SC2120
  escape_double_quote() { sed 's/"/"\\&"/g' <<< "${1-$(cat)}"; }

  # ~~~~~ COMMANDS ~~~~~

  trap_remote() {
    ! [ "${1}" = remote ] && return

    [ -n "${PVE_HOST:+x}" ] || {
      log_fatal "PVE_HOST is not configured"
      exit 1
    }

    log_info "Remote deployment to ${PVE_HOST}"

    local -a copy_func=(deploy_ve_core deploy_ve deploy_ve_config "${REMOTE_EXPORTS[@]}")
    ssh -- "${PVE_HOST}" "/bin/bash -c '
      $(
        set -o pipefail
        (set -x; declare -f -- "${copy_func[@]}") | escape_single_quote
      ) || exit
      deploy_ve_core local
    '"
    exit
  }

  print_demo() {
    echo "
      DEMO:
      ~~~~~
      # Deployment target must be PVE
      ${SELF_SCRIPT} local      # <- Targets current machine
      ${SELF_SCRIPT} remote     # <- Targets \$PVE_HOST machine via SSH
    " | sed -e 's/^\s*//' -e 's/\s*$//' -e '/^$/d' -e 's/^,//'
  }

  deploy_local() {
    if qm config "${VE_ID}" &>/dev/null \
      || pct config "${VE_ID}" &>/dev/null \
    ; then
      log_fatal "VE #${VE_ID} exists"
      return 1
    fi

    deploy_ve || return
  }

  main() {
    validate_command "${@}" || exit

    local -a deployment=(local remote)
    if ! printf -- '%s\n' "${deployment[@]}" \
      | grep -qFx -- "${1}" \
    ; then
      "${CMD_MAP[${1}]}" "${@:2}"; return
    fi

    deploy_ve_config
    trap_remote "${@}"  # || exit # <- It handles all exits
    check_pve_host || exit
    "${CMD_MAP[${1}]}" "${@:2}" || exit
  }

  main "${@}"
)

(return 2>/dev/null) || { deploy_ve_core "${@}"; exit; }
return    # <- If this line is hit, the file is sourced. Makes code that follows unreachable
