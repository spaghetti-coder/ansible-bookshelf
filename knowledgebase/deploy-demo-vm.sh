#!/usr/bin/env bash

#
# NOTE:
#   To add multiple profiles support rename deploy_ve_config function to
#   for example deploy_ve_config_foo and create deploy_ve_config_bar with
#   different configuration. This way the script will be able to handle
#   both profiles.
#   deploy_ve_config      <- correct
#   deploy_ve_config_foo  <- correct
#   deploy_ve_config_     <- will be ignored
#

# Default demo profile
deploy_ve_config() {
  PVE_HOST=pve.local        # <- Only REQUIRED for remote deployment
  REMOTE_EXPORTS+=()        # <- Functions to be exported to remote PVE

  VE_ID=6001                # <- Make sure >= 100
  # VE_ID="$(pvesh get /cluster/nextid 2>/dev/null)"  # <- Not recommended, not idempotent
  VE_NAME=ubuntu2404-demo1
  IMAGE_URL=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
  STORAGE=local-lvm

  # ~~~~~ HARDWARE CONFIGURATION ~~~~~
  CPU_TYPE=x86-64-v2-AES    # <- Works better than 'host'
  CORES=1
  DISK_SIZE=10G
  MEMORY=1024         # <- In MB
  NET_BRIDGE=vmbr0
  NET_IP=dhcp         # 192.168.0.10/24,gw=192.168.0.1    # <- For static IP
  AUTOSTART=0         # <- 0 or 1

  # ~~~~~ RUNTIME CONFIGURATION (optional) ~~~~~
  SSH_PUB_KEY=''
  CLOUD_USER=user1    # <- Both user and password required for account creation
  # Generate password hash:
  #   openssl passwd -6 -stdin < PASSWORD_FILE
  #   openssl passwd -6 -stdin <<< PASSWORD_TEXT
  # Generate random password hash:
  #   tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20 | openssl passwd -6 -stdin
  CLOUD_PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20 | openssl passwd -6 -stdin)"

  CUSTOMIZE_ARGS=(      # <- https://libguestfs.org/virt-customize.1.html
    # Guest agent + ansible target prereqs
    --update --install "qemu-guest-agent,openssh-server,python3,sudo"
    # Disable passwordless sudo for ${CLOUD_USER}
    --firstboot-command 'rm -f /etc/sudoers.d/*-cloud-init-*'
    # Fix $CLOUD_USER HOME ownership (probably due to Virtiofs directories creation)
    --firstboot-command "chown ${CLOUD_USER}:${CLOUD_USER} /home/${CLOUD_USER}"
  )

  # Mappings must be created in advance:
  #   Datacenter -> Directory Mappings
  VIRTIOFS=(            # Format: 'MAPPING_ID:IN_VM_MOUNT_POINT'
    # 'my-mapping-id:/home/user/share'    # <- /home/user/share will be auto created
  )

  ON_CREATED+=(         # Functions to be executed when the VM is created
    mk_snapshot
  )
}

# One more demo profile
deploy_ve_config_demo_2() {
  deploy_ve_config

  REMOTE_EXPORTS+=(
    # Current profile depends on the default one => export default to remote PVE
    deploy_ve_config
  )

  # Default profile overrides
  VE_ID=6002
  VE_NAME=ubuntu2404-demo2
}

mk_snapshot() {
  (set -x; qm snapshot "${VE_ID}" Init1 --description "Initial snapshot" >/dev/null)
}


# ==================== END OF CONFIGURATION ZONE ====================


#
# References:
#   * https://thiagodsantos.com/create-a-vm-template-with-proxmox-cloud-init-in-no-time/
#   * https://forum.proxmox.com/threads/cloud-init-template-creation-script.127015/
#

# shellcheck disable=SC2317,SC2329
deploy_ve_core() (
  local SELF_SCRIPT=pve-deploy-vm.sh
  grep -q '.\+' -- "${0}" 2>/dev/null && SELF_SCRIPT="$(basename -- "${0}" 2>/dev/null)"

  local PVE_HOST
  local VE_ID \
        VE_NAME \
        IMAGE_URL \
        STORAGE \
        CPU_TYPE \
        CORES \
        DISK_SIZE \
        MEMORY \
        NET_BRIDGE \
        NET_IP \
        AUTOSTART \
        CLOUD_USER \
        CLOUD_PASSWORD \
        SSH_PUB_KEY
  local -a  CUSTOMIZE_ARGS \
            VIRTIOFS \
            REMOTE_EXPORTS \
            ON_CREATED

  # https://stackoverflow.com/a/42449998
  # shellcheck disable=SC2034
  local T_BOLD='\033[1m' \
        T_DIM='\033[2m' \
        T_ITALIC='\033[3m' \
        T_UNDER='\033[4m' \
        T_RED='\033[31m' \
        T_GREEN='\033[32m' \
        T_RESET='\033[0m'

  local TMP_FILE="/tmp/pve-deploy-vm.img"

  declare -A CMD_MAP=(
    [local]=deploy_local
    [remote]='<DUMMY>' # Handled by trap_remote
    # Primitives
    [profile]=show_profile
    [profiles]=list_profiles
    [--usage]=print_usage
    [--demo]=print_demo
    [-?]=print_help
    [-h]=print_help
    [--help]=print_help
  )

  # ~~~~~ HELPERS ~~~~~

  profile_name_to_func() {
    local profile="${1}"
    local prefix=deploy_ve_config

    head -n 1 -- <<< "${profile}" | grep -qFxf <(list_profiles | sed -e 's/^*\s*//') || {
      log_fatal "Profile not defined: '${profile}'"
      return 1
    }

    local profile_func="${prefix}"
    if [ -n "${profile}" ]; then
      profile_func="$(
        printf -- '%s\n' "${profile}" \
        | sed -e 's/-/_/g' -e 's/^/'"${prefix}_"'/'
      )"
    fi

    declare -F -- "${profile_func}"
  }

  check_pve_host() {
    pveversion &>/dev/null && return
    log_fatal "Not PVE host"
    return 1
  }

  validate_command() {
    { [ -n "${CMD_MAP[${1}]}" ]; } &>/dev/null && return
    log_fatal "Invalid command: '${1}'"
    echo >&2
    print_usage
    return 1
  }

  # ~~~~~ LIB ~~~~~

  log_info()  { echo -e "${T_BOLD}${T_GREEN}INFO: ${T_RESET}${1}" >&2; }
  log_fatal() { echo -e "${T_RED}${T_BOLD}FATAL: ${T_RESET}${T_RED}${1}${T_RESET}" >&2; }

  # shellcheck disable=SC2001,SC2120
  escape_single_quote() { sed 's/'\''/'\''\\&'\''/g' <<< "${1-$(cat)}"; }
  # shellcheck disable=SC2001,SC2120,SC2329,SC2317
  escape_double_quote() { sed 's/"/"\\&"/g' <<< "${1-$(cat)}"; }

  # ~~~~~ COMMANDS ~~~~~

  trap_remote() {
    ! [ "${1}" = remote ] && return

    [ -n "${PVE_HOST:+x}" ] || {
      log_fatal "PVE_HOST is not configured"
      exit 1
    }

    local profile="${2}"
    local profile_func; profile_func="$(profile_name_to_func "${profile}")" || return

    log_info "Remote deployment to ${PVE_HOST}"

    local -a copy_func=(deploy_ve_core "${profile_func}" "${REMOTE_EXPORTS[@]}" "${ON_CREATED[@]}")
    ssh -- "${PVE_HOST}" "/bin/bash -c '
      $(
        set -o pipefail
        (set -x; declare -f -- "${copy_func[@]}") | escape_single_quote
      ) || exit
      deploy_ve_core local $(escape_single_quote "${profile}")
    '"
    exit
  }

  deploy_local() {
    if qm config "${VE_ID}" &>/dev/null \
      || pct config "${VE_ID}" &>/dev/null \
    ; then
      log_fatal "VE #${VE_ID} exists"
      return 1
    fi

    log_info "Installing prereqs on PVE host"
    ( set -x
      apt-get update -q >/dev/null \
      && apt-get install -qy libguestfs-tools dhcpcd-base >/dev/null
    ) || return

    log_info "Getting cloud image"
    (set -x; curl -fsSL -o "${TMP_FILE}" "${IMAGE_URL}") || return

    log_info "Customizing the image"
    (
      local -a extra_args
      local ctr=0
      local entry; for entry in "${VIRTIOFS[@]}"; do
        extra_args+=(--run-command 'mkdir -p '"${entry#*:}")
        if [ "${ctr}" -lt 1 ]; then
          extra_args+=(--run-command 'echo >> /etc/fstab')
          extra_args+=(--run-command 'echo "# ~~~~~ Virtiofs ~~~~~" >> /etc/fstab')
        fi
        extra_args+=(--run-command 'echo "'"${entry%%:*}"' '"${entry#*:}"' virtiofs defaults 0 0" >> /etc/fstab')
        (( ctr++ ))
      done

      set -x
      virt-customize -q -a "${TMP_FILE}" \
        --run-command 'systemd-machine-id-setup' \
        --run-command 'echo -n > /etc/machine-id' \
        --run-command 'ln -s -f /etc/machine-id /var/lib/dbus/machine-id' \
        "${extra_args[@]}" \
        "${CUSTOMIZE_ARGS[@]}" \
      >/dev/null
    ) || return

    log_info "Creating the VM"
    (set -x; qm create "${VE_ID}") || return

    # Import the cloud image as a disk
    (set -x; qm importdisk "${VE_ID}" "${TMP_FILE}" "${STORAGE}" >/dev/null) || return

    log_info "Configuring the VM"
    (
      local -a extra_args

      local entry
      local ix; for ix in "${!VIRTIOFS[@]}"; do
        entry="${VIRTIOFS[${ix}]}"
        extra_args+=("--virtiofs${ix}" "${entry%%:*},direct-io=1,expose-xattr=1" )
      done

      if [ -n "${CLOUD_USER}" ] && [ -n "${CLOUD_PASSWORD}" ]; then
        # --cipassword must be last in the row, to mask it properly
        extra_args+=(--ciuser "${CLOUD_USER}" --cipassword "${CLOUD_PASSWORD}")
      fi

      local -a the_cmd=(
        qm set "${VE_ID}" --scsihw virtio-scsi-single
          --name "${VE_NAME}"
          --net0 "virtio,bridge=${NET_BRIDGE}"
          --ostype l26 --cpu cputype="${CPU_TYPE}" --cores "${CORES}" --memory "${MEMORY}"
          --scsi0 "${STORAGE}:vm-${VE_ID}-disk-0,cache=writethrough,discard=on,iothread=1,ssd=1"
          --efidisk0 "${STORAGE}:0,efitype=4m,,pre-enrolled-keys=1,size=1M"
          --scsi1 "${STORAGE}:cloudinit"
          --agent 1
          --rng0 source=/dev/urandom
          --boot order=scsi0
          --tablet 0
          --ipconfig0 ip="${NET_IP}"
          --onboot="${AUTOSTART}"
          "${extra_args[@]}"
      )
      ( set -o pipefail
        (set -x; "${the_cmd[@]}" >/dev/null) 3>&1 1>&2 2>&3 \
        | sed -e 's/\(--cipassword[= ]\).\+/\1*****/g'
      ) 3>&1 1>&2 2>&3 || return

      ( set -x
        qm cloudinit update "${VE_ID}" >/dev/null \
        && qm resize "${VE_ID}" scsi0 "${DISK_SIZE}" >/dev/null
      ) || return
    ) || return

    if [ -n "${SSH_PUB_KEY}" ]; then
      printf -- '%s\n' "${SSH_PUB_KEY}" | (set -x; qm set "${VE_ID}" --sshkeys <(cat) >/dev/null) || return
    fi

    local hook; for hook in "${ON_CREATED[@]}"; do
      log_info "Executing ${hook} hook"
      "${hook}" || exit
    done

    log_info "Cleanup"
    (set -x; rm -f "${TMP_FILE}")

    if [ "${AUTOSTART}" -eq 1 ]; then
      (set -x; qm start "${VE_ID}" >/dev/null) || return
    fi
  }

  list_profiles() {
    declare -F | rev | cut -d ' ' -f1 | rev       `# <- Get funcs names` \
    | sed -e 's/$/_/' | grep '^deploy_ve_config_' `# <- Get profilish ones` \
    | sed -e 's/^deploy_ve_config_//' -e '/^_$/d' \
          -e 's/_$//' -e 's/_/-/g'                `# <- Get profile names` \
    | sort \
    | sed -e 's/^/* /'
  }

  show_profile() {
    local profile="${1}"
    local func; func="$(profile_name_to_func "${profile}")" || return
    declare -f "${func}"
  }

  print_usage() {
    echo "
      USAGE:
      ~~~~~~
      ${SELF_SCRIPT} local|remote [PROFILE]   # <- Deploy PVE VM
      ${SELF_SCRIPT} profiles                 # <- List all profiles
      ${SELF_SCRIPT} profile [PROFILE]        # <- View profile
    " | sed -e 's/^\s*//' -e 's/\s*$//' -e '/^$/d' -e 's/^,//'
  }

  print_demo() {
    echo "
      DEMO:
      ~~~~~
      # Deployment target must be PVE
      # Assuming 2 config functions present:
      #   deploy_ve_config() { \`# Default profile\`; }
      #   deploy_ve_config_nas_server() { \`# NAS server profile\`; }
      ${SELF_SCRIPT} local      # <- Default profile targets current machine
      ${SELF_SCRIPT} local ''   # <- Same as previous
      ${SELF_SCRIPT} remote     # <- Same, but targets \$PVE_HOST machine via SSH
      ${SELF_SCRIPT} local nas-server   # <- NAS server profile. NOTE: '_' -> '-'
     ,
      # View profile:
      ${SELF_SCRIPT} profile              # <- View default profile
      ${SELF_SCRIPT} profile nas-server   # <- View NAS server profile
    " | sed -e 's/^\s*//' -e 's/\s*$//' -e '/^$/d' -e 's/^,//'
  }

  print_help() {
    print_usage
    echo
    print_demo
  }

  main() {
    validate_command "${@}" || exit

    local -a deployment=(local remote)
    if ! printf -- '%s\n' "${deployment[@]}" \
      | grep -qFx -- "${1}" \
    ; then
      "${CMD_MAP[${1}]}" "${@:2}"; return
    fi

    local profile_func; profile_func="$(profile_name_to_func "${@:2}")" || exit
    "${profile_func}"
    trap_remote "${@}"  # || exit # <- It handles all exits
    check_pve_host || exit
    "${CMD_MAP[${1}]}" "${@:2}" || exit
  }

  main "${@}"
)

(return 2>/dev/null) || { deploy_ve_core "${@}"; exit; }
return    # <- If this line is hit, the file is sourced. Makes code that follows unreachable
