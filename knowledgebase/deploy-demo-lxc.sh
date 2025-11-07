#!/usr/bin/env bash

#
# REQUIREMENTS:
# * PVE host must have age installed
# * For remote deployment execution host must have SSH access to PVE_HOST and
#   age installed
#

deploy_ve_config() {
  #
  # NOTES:
  # * In this demo all the passwords and passphrases are 'changeme'
  #

  # More config:
  # * deploy_ve.main   # <- Deployment flow + customizations

  # Generate with:
  #   THE_SCRIPT gen-age  # <- Prompts for passphrase
  # Internally in the script decrypt encrypted by this AGE_KEY secrets with:
  #   echo PLAIN_SECRET | THE_SCRIPT encrypt-secret `# => AGE_ENCRYPTED_SECRET` | decrypt_secret `# => PLAIN_SECRET`
  AGE_KEY='YWdlMWw4N2Y2NXRqcjM3ZGd2cTlhZzZxN3d6ZWF2MjhheXN0c2FkMGp4NmU0NnY2NjgybmVheHN1cHJ5dWMKWVdkbExXVnVZM0o1Y0hScGIyNHViM0puTDNZeENpMCtJSE5qY25sd2RDQXJUWGRIY2t4WFpIUlJSRGRFTlhaS05tRldNVE5CSURFNENsWlNaMVJIZFVZNU9HWlhaVnBTV2l0VWQyd3dXV0p5V0RsWVMwVktaMHRGV214Uk1URlphVlYwTVc4S0xTMHRJSFI1YjNsUVYxaDJiMU5vTUVsSWRrWlpabU00Y2sxRVMwMDBVRU5vUjA1MU9XVXhSQzgzUkhadWRUQUs2dDVJUE1KS1RKZWtidnVzS0VlVUF2QXhjd29oc3N0U05ramlaNEpKUWhLZTZ6blFiKzVPRVE0a3BJb09NeGlGOHBsNUlnUmplSDNJeERXRnlJNWIxVytwVlQ2b1ZVbkxyRm9McUhiZmwybHJaUEI5Y2h5TUlOUlE2SHQyRkpNTU1vV0ZrZFovTTh6YmFZRGl6eXIwUmVZSFhIRlFPVGJETk9aSEJmYTB6eGpteDFFMjE0YTBuOXkzbC9xbW9RYnczanlJamZZYk05ZGpMdVdiZkpHbmNxQ3Z0NzJlZlhhWEpuNWlHTzMybmMxd1NpZkExaG1RWndUMWFualBUV01MVDNPVm9JYVEvejZqam5xRnRnYkltSDdiaFhVS2dJNU5uWlBhc3lFPQo='

  PVE_HOST=pve.home           # <- Remote PVE ssh host for deploy-remote command

  # Best match from available templates: http://download.proxmox.com/images/system
  VE_TEMPLATE=alpine-3
  VE_ID=1085                  # <- Make sure >= 100
  # VE_ID="$(pvesh get /cluster/nextid 2>/dev/null)"  # <- Not recommended, not idempotent

  CREATE_FLAGS=(              # <- Create LXC flags, '--password' is autoappended with value from EXTRAS[root_pass]
    --unprivileged=1          # <- '0' if using bind mounts, or use boring workarounds for ownership
    --features='nesting=1,keyctl=1'   # <- ',keyctl=1' Not needed with privileged
    --net0="name=eth0,bridge=vmbr0,ip=dhcp"
    # --net0="name=eth0,bridge=vmbr0,ip=192.168.0.20/24,gw=192.168.0.1"   # <- Alternatively configure IP
    --storage=local-lvm       # <- Select your storage
    --hostname=test.home      # <- Ensure corrent hostname
    --rootfs=20
    --timezone=host
    --onboot=1
    --memory=1024
    --swap=512
    --cores=1
    --tags='test.home;testing'
  )

  EXTRAS=(
    # Linux user password encryption:
    #   openssl passwd -6 -stdin < PASSWORD_FILE | THE_SCRIPT encrypt-secret
    [root_pass]='YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBHRjdzODdQOE4rRTdoRzJxdTRsQXpjNUhuVlFBWGkvYXY4YTVSNEo3RXlvClN4NkREVExQVjVwVmpuWjYwKzlrWkhFZkppcXp2cE9YSS96NEpZbEJueWsKLS0tIEhuUGFRRjNHUGtHc1YyY1oyNEF3cWZ0dlg2dUF1NDRTQ2V1eGMvRkpnMzAKKFh2HclcGuFZDTjrOGtZ3em3pGvfvTcPLqPFMsPhQQPSW/bELPK2/a/yKxPLjJRIeDhESyhxk4A5G0nv0Q5Lwps4l/rZcoyd+p42pMQ6pU6n9uZjvVFg9H2Yq1kEb7yy5sgZmwrvvIWcoVMqaQ5DX2ZLmMdOX3aunnpMNuIr2mxNMwAoIoRgEolkEA=='
    # Used by custom provisioners
    [user1_name]=user1
    [user1_uid]=1000
    # Use chpasswd tool to set the password
    #   echo "${EXTRAS[user1_name]}:${EXTRAS[user1_pass]}" | chpasswd -e
    [user1_pass]='YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBPMnRmQ3dPOFh2MUdlYVlBOXplUFUwc0R5Nm4vN1VIbmw5R1QwaXhJd0JNCjhad2JsNUlmZ0ZaQzZBWVBVV3ZSbHRsRTV3VHhhaDNKYWhET2pRcnp5d28KLS0tIHBDYllLVnhzVDJQQ1Q0dWZzd3VtcUFhMXpGcmZUMXAwbSt2SEd1VzhOY1EKJwl23NNALO0ilgEI42K442jOs92RykmDNCFwbc6QlEA0Kxsdy+L4e0S6t399dXs/596andORxAh9eCOVqEqeSOy5RNgrSYO27TNTWJeyF9nNOlvlyqoYrZOjF9SMEbIIZDqm/r1AzwOzgA6Df9vvMc+LdIwtv+B/pKc1ErQvNOTrA0i1IL3JIFfqYA=='
  )

  # In case of remote deployment, the script copies only functions from the
  # current script to PVE_HOST and executes them. In case you need to export
  # more functions to use them here, add them to this array
  PVE_COPY_FUNC=()
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
    profile_vaapi false || return
    profile_vpn_ready false || return

    # Provisioning
    start_ve || return
      fix_locale || return
      install_ansible_prereqs || return

      # Custom provisioning
      create_lxc_user || return
    stop_ve || return   # <- To ensure changes applied on the next start

    # To start VE immediately
    start_ve || return
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
        apk add -q --update --no-cache shadow sudo \
        && groupadd -g '${EXTRAS[user1_uid]}' '${name}' \
        && useradd -g '${EXTRAS[user1_uid]}' -G wheel -u '${EXTRAS[user1_uid]}' -m '${name}' \
        && { echo '%wheel ALL=(ALL) ALL' | tee /etc/sudoers.d/wheel >/dev/null; } \
        && chpasswd -e
      " || return
    echo "Done provision: ${FUNCNAME[0]}" >&2
  }

  main
)


# ==================== END OF CONFIGURATION ZONE ====================


# shellcheck disable=SC2317,SC2329
deploy_ve_core() (
  local PVE_HOST VE_ID VE_TEMPLATE AGE_KEY
  declare -A EXTRAS
  declare -a CREATE_FLAGS PVE_COPY_FUNC
  declare -i START_DELAY=15
  local AGE_SECRET

  local SELF_SCRIPT=pve-deploy-ve.sh
  grep -q '.\+' -- "${0}" 2>/dev/null && SELF_SCRIPT="$(basename -- "${0}" 2>/dev/null)"

  # https://stackoverflow.com/a/42449998
  # shellcheck disable=SC2034
  local T_BOLD='\033[1m' \
        T_DIM='\033[2m' \
        T_ITALIC='\033[3m' \
        T_UNDER='\033[4m' \
        T_RESET='\033[0m'

  main() {
    local command; command="$(get_command "${@:1:1}")" || return

    deploy_ve_config || return    # <- Populate configuration

    "${command}" "${@:2}"
  }

  get_command() {
    [ -n "${1+x}" ] || {
      echo -e "${T_BOLD}FATAL${T_RESET}: Command required. Try --help" >&2
      return 1
    }

    declare CMD="${1}"

    # Check if help
    case "${CMD}" in
      -\?|-h|--help ) echo print_help; return ;;
      --short       ) echo print_help_short; return ;;
      --usage       ) echo print_help_usage; return ;;
    esac

    # Check if one of map commands
    declare -A commands_map=(
      [deploy]=deploy_any
      [deploy-local]=deploy_local
      [deploy-remote]=deploy_remote
      [gen-age]=gen_age
      [encrypt-secret]=encrypt_secret
      [age-pub]=get_age_pub
      [age-secret]=get_age_secret
      [decrypt-secret]=decrypt_secret
    )
    declare commands_rex
    commands_rex="$(printf -- '%s\|' "${!commands_map[@]}" | sed 's/\\|$//')"
    grep -qx "\(${commands_rex}\)" <<< "${CMD}" && { echo "${commands_map[${CMD}]}"; return; }

    echo -e "${T_BOLD}FATAL${T_RESET}: Invalid command: '${CMD}'. Try --help" >&2
    return 1
  }

  #
  # COMMANDS
  #

  print_help_short() {
    print_nice "
      COMMANDS:
      ========
      gen-age         # Generate passphrase protected age key to stdout
      encrypt-secret  # Encrypt something with age key
      deploy          # deploy-local if current machine is PVE, otherwise deploy-remote
      deploy-local    # Deploy VE on the current machine assuming it's PVE
      deploy-remote   # Deploy to host configured in PVE_HOST
      # For private and development needs mostly:
      age-pub         # Print age public key
      age-secret      # Print age secret key. Wants passphrase
      decrypt-secret  # Decrypt a secret encrypted with 'encrypt-secret' from stdin
    "
  }

  print_help_usage() {
    print_nice "
      USAGE:
      =====
      # For insecure scenario, place root pass to EXTRAS[root_pass] in plain, add
      # other configuration as you need, make sure AGE_KEY empty. And just run:
      ${SELF_SCRIPT} deploy
     ,
      #
      # Secure scenario (adviced)
      #
     ,
      # Generate passphrase encrypted age public / secret key bundle and put it
      # to AGE_KEY in the config section of the current script
      ${SELF_SCRIPT} gen-age
     ,
      # Encrypt desired root pass and put it to EXTRAS[root_pass] in the config
      # section of the current script. Same command can be used to encrypt other
      # sensitive data, for decryption see config section of the current script
      echo PASSWORD | ${SELF_SCRIPT} encrypt-secret    # <- From stdin
      ${SELF_SCRIPT} encrypt-secret ./PASSWORD_FILE    # <- From file
     ,
      # Edit the rest of config section of the current script and deploy the VE
      # with the following command. Prompts for AGE_KEY passphrase
      ${SELF_SCRIPT} deploy
    "
  }

  print_help() {
    print_nice "
      --short     Print only commands
      --usage     Print only usage section
    "; echo

    print_help_short; echo
    print_help_usage
  }

  deploy_any() {
    pveversion &>/dev/null && { deploy_local; return; }

    echo -e "${T_BOLD}INFO${T_RESET}: Not PVE host, attempting remote" >&2
    deploy_remote
  }

  deploy_local() {
    pveversion &>/dev/null || {
      echo -e "${T_BOLD}ERR${T_RESET}: Not PVE host" >&2
      return 1
    }

    pct config "${VE_ID}" --current &>/dev/null && {
      echo -e "${T_BOLD}INFO${T_RESET}: VE #${VE_ID} exists. Skipping" >&2
      return
    }

    [ -z "${AGE_KEY}" ] && { echo -e "${T_BOLD}WARN${T_RESET}: AGE_KEY not set. Insecure deployment" >&2; }
    propagate_age_secret || return

    deploy_ve || return
  }

  deploy_remote() {
    [ -n "${PVE_HOST:+x}" ] || {
      echo -e "${T_BOLD}ERR${T_RESET}: PVE_HOST is not configured" >&2
      return 1
    }

    echo -e "${T_BOLD}INFO${T_RESET}: Remote deployment to ${PVE_HOST}" >&2

    local -a copy_func=(deploy_ve_core deploy_ve deploy_ve_config)
    if declare -p PVE_COPY_FUNC 2>/dev/null | grep -q '^declare -a'; then
      copy_func+=("${PVE_COPY_FUNC[@]}")
    fi

    ssh -t -t -- "${PVE_HOST}" "/bin/bash -c '
      $(declare -f "${copy_func[@]}" | escape_single_quote)
      deploy_ve_core deploy-local
    '"
  }

  gen_age() {
    local pub_key_rex='public\s\+key\s*:'
    local age_secret; age_secret="$( (
      # shellcheck disable=SC2092
      `# https://stackoverflow.com/a/16126777`
      set -o pipefail; (age-keygen 3>&2 2>&1 1>&3) | sed -e '1!b' -e '/^\s*'"${pub_key_rex}"'/Id'
    ) 3>&2 2>&1 1>&3 )" || return
    local age_public; age_public="$(
      grep -i '^#\s*'"${pub_key_rex}" <<< "${age_secret}" | sed -e 's/^[^:]\+:\s*//'
    )" || return

    # By lines:
    # 1. Age public plain
    # 2. Age secret       | age-password-encode       | base64-single-line-encode
    # And all thes lines  | base64-single-line-encode

    local lines="${age_public}" \
      && lines+=$'\n'"$(set -o pipefail; age -e -p <<< "${age_secret}" | base64 --wrap=0)" \
    || return

    base64 --wrap=0 <<< "${lines}" || return
    echo
  }

  get_age_pub() (set -o pipefail; get_age_lines | sed -n '1p')

  get_age_secret() {
    [ -n "${AGE_SECRET}" ] && { cat <<< "${AGE_SECRET}"; return; }
    local line; line="$(set -o pipefail; get_age_lines | sed -n '2p')" || return
    [ -z "${line}" ] && return
    (set -o pipefail; base64 -d <<< "${line}" | age -d) || return
  }

  encrypt_secret() {
    local pub_key; pub_key="$(get_age_pub)" || return
    [ -z "${pub_key}" ] && { cat -- "${@:1:1}"; return; }
    (set -o pipefail; age -e -r "${pub_key}" "${@:1:1}" | base64 --wrap=0) || return
    echo
  }

  decrypt_secret() {
    # USAGE:
    #   echo SECRET | decrypt_secret

    local secret; secret="$(get_age_secret)"
    [ -z "${secret}" ] && { cat; return; }
    base64 -d | age -d -i <(cat <<< "${secret}") || return
  }

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
    local pass; pass="$(decrypt_secret <<< "${EXTRAS[root_pass]}")" || return

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

  get_age_lines() {
    [ -z "${AGE_KEY}" ] && return
    base64 -d <<< "${AGE_KEY}"
  }

  propagate_age_secret() {
    [ -n "${AGE_SECRET+x}" ] && return
    AGE_SECRET="$(get_age_secret)" || return
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

  print_nice() { sed -e 's/^\s*$//' -e '/^$/d' -e 's/^\s*//' -e 's/^,//' <<< "${1-$(cat)}"; }

  # shellcheck disable=SC2001,SC2120
  escape_single_quote() { sed 's/'\''/'\''\\&'\''/g' <<< "${1-$(cat)}"; }
  # shellcheck disable=SC2001,SC2120
  escape_double_quote() { sed 's/"/"\\&"/g' <<< "${1-$(cat)}"; }

  #
  # PROFILES
  #

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

    echo "Do profile: ${FUNCNAME[0]} ..." >&2
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
    echo "Done profile: ${FUNCNAME[0]}" >&2
  }

  profile_vpn_ready() {
    # USAGE:
    #   profile_vpn_ready [true|false]  # <- Defaults to false

    ${1-false} || return 0

    echo "Do profile: ${FUNCNAME[0]} ..." >&2
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
    echo "Done profile: ${FUNCNAME[0]}" >&2
  }

  profile_docker_ready() {
    # USAGE:
    #   profile_docker_ready [true|false]  # <- Defaults to false

    ${1-false} || return 0

    echo "Do profile: ${FUNCNAME[0]} ..." >&2
      if is_privileged; then
        (set -o pipefail; get_ve_option 'lxc.cap.drop' | grep -qx '\s*') \
        || {
          echo 'lxc.cap.drop:' \
            | (set -x; tee -a "/etc/pve/lxc/${VE_ID}.conf" >/dev/null) \
          || return
        }
      fi
    echo "Done profile: ${FUNCNAME[0]}" >&2
  }

  profile_vaapi() {
    # USAGE:
    #   profile_vaapi [true|false]   # <- Defaults to false

    ${1-false} || return 0

    echo "Do profile: ${FUNCNAME[0]} ..." >&2
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
    echo "Done profile: ${FUNCNAME[0]}" >&2
  }

  profile_disable_apparmor() {
    # USAGE:
    #   profile_disable_apparmor [true|false]  # <- Defaults to false

    ${1-false} || return 0

    local -a entries=("lxc.apparmor.profile: unconfined")
    get_ve_option ostype | grep -qix 'ubuntu' && {
      entries+=("lxc.mount.entry: /dev/null sys/module/apparmor/parameters/enabled none bind 0 0")
    }

    echo "Do profile: ${FUNCNAME[0]} ..." >&2
      printf -- '%s\n' "${entries[@]}" | (
        set -x; tee -a "/etc/pve/lxc/${VE_ID}.conf" >/dev/null
      ) || return
    echo "Done profile: ${FUNCNAME[0]}" >&2
  }

  #
  # PROVISIONERS
  #

  user_bind_mounts() {
    # USAGE:
    #   user_bind_mounts VE_USER HOST_DIR:VE_MOUNT_MOUNT...
    # DEMO:
    #   user_bind_mounts root /mnt/share:/root/share /mnt/conf:/root/conf
    # -----
    # NOTE: Requires VE running

    local owner="${1}"

    echo "Do provision: ${FUNCNAME[0]} ..." >&2
      declare src dest
      local kv; for kv in "${@:2}"; do
        src="${kv%%:*}" dest="${kv#*:}"

        lxc-attach -n "${VE_ID}" -- /bin/su -l "${owner}" -s \
          /bin/sh -c "set -x; mkdir -p '${dest}'" || return

        dest="$(sed 's/^\///' <<< "${dest}")"
        echo "lxc.mount.entry: ${src} ${dest} none bind,create=dir 0 0" \
        | (set -x; tee -a "/etc/pve/lxc/${VE_ID}.conf" >/dev/null)
      done
    echo "Done provision: ${FUNCNAME[0]}" >&2
  }

  fix_locale() {
    echo "Do provision: ${FUNCNAME[0]} ..." >&2
      if get_ve_option ostype | grep -qix '\(ubuntu\|debian\)'; then
        lxc-attach -n "${VE_ID}" -- /bin/sh -c "
          set -x
          sed -i '"'s/^\s*#\s*\(en_US\.UTF-8\)/\1/'"' /etc/locale.gen && locale-gen
        " || return
      fi
    echo "Done provision: ${FUNCNAME[0]}" >&2
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
        && apt-get install -q -y openssh-server python3 sudo >/dev/null \
        && systemctl enable -q --now ssh
      "
    elif get_ve_option ostype | grep -qix 'centos'; then
      cmds="
        dnf install -qy openssh-server python3 sudo >/dev/null \
        && systemctl enable -q --now sshd
      "
    fi

    echo "Do provision: ${FUNCNAME[0]} ..." >&2
      lxc-attach -n "${VE_ID}" -- /bin/sh -c "set -x; ${cmds}" || return
    echo "Done provision: ${FUNCNAME[0]}" >&2
  }

  #
  # HELPERS
  #

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

  main "${@}"   # <- Passthrough all input params
)

(return 2>/dev/null) || { deploy_ve_core "${@}"; exit; }
return    # <- If this line is hit, the file is sourced. Makes code that follows unreachable
