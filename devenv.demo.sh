#!/usr/bin/env bash

# Copy to devenv.sh, change config values and source to the current
# shell for dev environment. Best to use with envar tool:
#   envar ./devenv.sh

_devenv_config() {
  # Settings for ansible hosts file and `devenv ssh` shortcut.
  # See hosts.yaml and group_vars/all.yaml
  export ANSIBLE_HOST_ALMA=192.168.1.11
  export ANSIBLE_HOST_ALPINE=192.168.1.12
  export ANSIBLE_HOST_DEBIAN=192.168.1.13
  export ANSIBLE_HOST_UBUNTU=192.168.1.14
  # To keep it simple, test env user and password to be the same for all envs,
  export ANSIBLE_USER=demo-ssh-user
  export ANSIBLE_USER_PASS=demo-ssh-user-pass
  # Alternatively append host name for individual hosts
  # export ANSIBLE_USER_ALMA=bug2
  # export ANSIBLE_USER_PASS_ALMA=changeme2

  # Settings for `devenv reset`
  PVE_HOST=pve.home   # <- PVE ssh-host
  declare -ag PVE_ENV_SNAPSHOTS=(
    # [VE_HOST_ALIAS]='VE_ID=SNAPSHOT'  # <- Alias is not related with the defined for ansible
    [alma]='100=Ansible1'   # <- Given 'Ansible1' is an existing snapshot on VE #100
    [debian]='101=Ansible1'
    [ubuntu]='102=Ansible1'
    [alpine]='103=Ansible1'
  )

  # Alias to 'devenv' command. Leave blank to not have an alias
  DEVENV_ALIAS=de
}


# ==================== END OF CONFIGURATION ZONE ====================


# shellcheck disable=SC2317,SC2092
devenv() (
  local SELF="${FUNCNAME[0]}"
  declare -A CMD_MAP=(
    [reset]=do_reset
    [reset-all]=do_reset_all
    [ssh]=do_ssh
    [gen-init]=do_gen_init    # <- Removed from completion list
  )

  _devenv_config

  # shellcheck disable=SC2234
  do_ssh() {
    [ ${#} -gt 0 ] || { echo "Host required" >&2; return 1; }

    local host="${1}"
    local -a ssh_args=("${@:2}")

    local hosts; hosts="$(_ssh_hosts | grep '.')" || {
      echo 'Hosts are not configured'; return 1
    }

    local rex_file; rex_file="$(sed -e 's/^/^/' -e 's/$/$/' <<< "${hosts}")"
    grep -qf <(cat <<< "${rex_file}") <<< "${host}" || {
      echo "Invalid host: ${host}" >&2; return 1
    }

    local ssh_host
    local user_var="ANSIBLE_USER_${host^^}"
    ( [ -n "${!user_var}" ] ) 2>/dev/null || user_var="ANSIBLE_USER"
    ( [ -n "${!user_var}" ] ) 2>/dev/null && ssh_host="${!user_var}@"

    local host_var="ANSIBLE_HOST_${host^^}"
    ssh_host+="${!host_var}"

    # Pass in HOST_ALIAS to handle password variable
    HOST_ALIAS="${host}" _ssh "${ssh_host}" "${ssh_args[@]}"
  }

  do_reset() {
    [ ${#} -gt 0 ] || { echo "Host required" >&2; return 1; }

    local host="${1}"

    local rex_file; rex_file="$(_reset_hosts | sed -e 's/^/^/' -e 's/$/$/')"
    grep -qf <(cat <<< "${rex_file}") <<< "${host}" || {
      echo "Invalid host: ${host}" >&2; return 1
    }

    local settings="${PVE_ENV_SNAPSHOTS[${host}]}"
    local ve_id="${settings%%=*}"
    local snapshot="${settings#*=}"
    local -a reset_cmd=(pct rollback "${ve_id}" "${snapshot}" --start)
    # shellcheck disable=SC2029
    (set -x; ssh "${PVE_HOST}" "${reset_cmd[*]} >/dev/null") || return
  }

  do_reset_all() {
    local alias; for alias in "${!PVE_ENV_SNAPSHOTS[@]}"; do
      do_reset "${alias}"
    done
  }

  do_gen_init() {
    # Required for ansible
    echo '_devenv_config'

    gen_alias
    gen_completion
  }

  # shellcheck disable=SC2120
  gen_alias() {
    `# {{ GEN_START }}`; {
      [ -z "${DEVENV_ALIAS}" ] && return

      local alias_repl; alias_repl="$(sed_escape_replace "${DEVENV_ALIAS}")"

      declare -f "${FUNCNAME[0]}" | sed \
        -e '1 s/'"${FUNCNAME[0]}"'/'"${alias_repl}"'/' \
        -e '/#\s*{{\s*GEN_START\s*}}/,/#\s*{{\s*GEN_END\s*}}/d'

      return
    }; `# {{ GEN_END }}`

    devenv "${@}"
  }

  gen_completion() {
    local comp_func="_${SELF}_completion"

    `# {{ GEN_START }}`; {
      local -a commands ssh_hosts reset_hosts
      mapfile -t commands <<< "$(printf -- '%s\n' "${!CMD_MAP[@]}" | sed '/^gen-init$/d' | sort -n)"
      mapfile -t ssh_hosts <<< "$(_ssh_hosts | sort -n)"
      mapfile -t reset_hosts <<< "$(_reset_hosts | sort -n)"

      local commands_repl ssh_hosts_repl reset_hosts_repl
      commands_repl="$(declare -p commands | sed_escape_replace)"
      ssh_hosts_repl="$(declare -p ssh_hosts | sed_escape_replace)"
      reset_hosts_repl="$(declare -p reset_hosts | sed_escape_replace)"

      declare -f "${FUNCNAME[0]}" | sed \
        -e '1 s/'"${FUNCNAME[0]}"'/'"${comp_func}"'/' \
        -e '/#\s*{{\s*GEN_START\s*}}/,/#\s*{{\s*GEN_END\s*}}/d' \
        -e 's/^\(\s*\).*{{ COMMANDS_LIST }}.*/\1'"${commands_repl}"'/' \
        -e 's/^\(\s*\).*{{ SSH_HOSTS_LIST }}.*/\1'"${ssh_hosts_repl}"'/' \
        -e 's/^\(\s*\).*{{ RESET_HOSTS_LIST }}.*/\1'"${reset_hosts_repl}"'/'

      local -a completties=("${SELF}")
      [ -n "${DEVENV_ALIAS}" ] && completties+=("${DEVENV_ALIAS}")

      echo "complete -o nosort -o default -F ${comp_func} ${completties[*]} 2>/dev/null"
      return
    }; `# {{ GEN_END }}`

    local current="${COMP_WORDS[COMP_CWORD]}"
    local previous="${COMP_WORDS[COMP_CWORD-1]}"

    `# Completion hints:`
    `# {{ COMMANDS_LIST }}`     # <- Will expand to 'commands' variable
    `# {{ SSH_HOSTS_LIST }}`    # <- Will expand to 'ssh_hosts' variable
    `# {{ RESET_HOSTS_LIST }}`  # <- Will expand to 'reset_hosts' variable

    # shellcheck disable=SC2207
    if [ "${COMP_CWORD}" -eq 1 ]; then
      COMPREPLY=($(compgen -W "${commands[*]}" -- "${current}"))
    elif [ "${COMP_CWORD}" -eq 2 ]; then
      if [ "${previous}" == 'ssh' ]; then
        COMPREPLY=($(compgen -W "${ssh_hosts[*]}" -- "${current}"))
      elif [ "${previous}" == 'reset' ]; then
        COMPREPLY=($(compgen -W "${reset_hosts[*]}" -- "${current}"))
      fi
    fi
  }

  print_help() {
    print_nice "
      COMMANDS:
      ========
      ${SELF} reset       # Reset an environment to configured snapshot
      ${SELF} reset-all   # Reset all environments
      ${SELF} ssh         # SSH to environment (passwordless with sshpass installed)
     ,
      DEMO:
      ====
      # SSH to VE from ANSIBLE_HOST_ALPINE, where VE name is taken from
      # the last segment of ANSIBLE_HOST_* variable (lower case)
      ${SELF} ssh alpine                  # <- SSH to VE
      ${SELF} ssh alma 'hostname -f'      # <- Command over SSH
     ,
      # Reset environment configured with PVE_ENV_SNAPSHOTS[alma]
      ${SELF} reset alma
     ,
      # Reset all environments configured in PVE_ENV_SNAPSHOTS
      ${SELF} reset-all
     ,
      # Geven hosts.yaml and group_vars/all.yaml are using environment variables
      # configured in the config zone, run playbook
      ./bin/play.sh [ARGS]
    "
  }

  main() {
    [ ${#} -gt 0 ] || { echo "Command required" >&2; return 1; }

    [[ "${1}" =~ ^(-\?|-h|--help)$ ]] && { print_help; return; }

    [ -n "${CMD_MAP["${1}"]+x}" ] || { echo "Invalid command" >&2; return 1; }
    "${CMD_MAP["${1}"]}" "${@:2}" || return
  }

  _ssh_hosts() {
    printenv | grep '^ANSIBLE_HOST_' | cut -d '=' -f1 \
    | sed 's/^ANSIBLE_HOST_//' | tr '[:upper:]' '[:lower:]' \
    | sort -n
  }

  _reset_hosts() {
    printf -- '%s\n' "${!PVE_ENV_SNAPSHOTS[@]}" | sort -n
  }

  # shellcheck disable=SC2234
  _ssh() {
    local -a _ssh_cmd=(ssh -o StrictHostKeyChecking=no "${@}")

    local pass_var="ANSIBLE_USER_PASS_${HOST_ALIAS^^}"
    ( [ -n "${!pass_var}" ] ) 2>/dev/null || pass_var="ANSIBLE_USER_PASS"

    if \
      ( [ -n "${!pass_var}" ] ) 2>/dev/null \
      && sshpass -V &>/dev/null \
    ; then
      sshpass -p"${!pass_var}" "${_ssh_cmd[@]}"; return
    fi

    "${_ssh_cmd[@]}"; return
  }

  # shellcheck disable=SC2120
  print_nice() { sed -e 's/^\s*$//' -e '/^$/d' -e 's/^\s*//' -e 's/^,//' <<< "${1-$(cat)}"; }

  # https://gist.github.com/varlogerr/2c058af053921f1e9a0ddc39ab854577#file-sed-quote
  # shellcheck disable=SC2120
  sed_escape_pattern() { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
  # shellcheck disable=SC2120
  sed_escape_replace() { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

  main "${@}"
)

# Propagate initialize config and propagate completion
# devenv gen-init
eval "$(devenv gen-init)"
