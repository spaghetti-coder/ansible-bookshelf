#!/usr/bin/env bash
# shellcheck disable=SC2092

conf_ensure_host_mounts() {
  MOUNT_POINTS=(/mnt/data)
  INTERVAL=30     `# <- Next attempt interval (in seconds, defaults to 10)`
}

conf_lxc_ensure_users() {
  USERS=(test)
  WARMUP_TIME=10  `# <- Container warmup delay (in seconds, defaults to 20)`
}

run_hooks() {
  `# Place the script to /var/lib/vz/snippets, chmod +x and add to virt env hooks`
  `# =====`
  `# More on PVE hooks:`
  `#   https://codingpackets.com/blog/proxmox-hook-script-port-mirror/#hook-scripts`

  ensure_host_mounts "${@}"
  `# lxc_ensure_users "${@}"  # <- Creates a user, commented for the demo`
}

ensure_host_mounts() {
  `# Ensure ${MOUNT_POINTS[@]} are mounted in PVE host before virt env starts`
  `# to avoid writes to PVE filesystem instead of external drive.`

  declare -a MOUNT_POINTS
  declare -i INTERVAL=10
  conf_ensure_host_mounts   `# <- Load settings`

  # shellcheck disable=SC2034
  local -r VE_ID="${1}"   `# <- VM or container ID, unused in this script`
  local -r PHASE="${2}"   `# Execution phase: ['pre-start', 'post-start', 'pre-stop', 'post-stop']`

  ! [[ ' pre-start ' == *" ${PHASE} "* ]] && return

  declare -a mounted
  local mp
  while true; do
    mounted=()

    for mp in "${MOUNT_POINTS[@]}"; do
      if ! mountpoint -q -- "${mp}" 2> /dev/null; then
        `# Not mounted. Attempt to mount`

        echo "[${FUNCNAME[0]}] ${mp} mount KO" 1>&2
        (set -x; mount -- "${mp}" &> /dev/null)
      fi

      if mountpoint -q -- "${mp}" 2> /dev/null; then
        mounted+=("${mp}")
        echo "[${FUNCNAME[0]}] ${mp} mount OK" 1>&2
      fi
    done

    [[ ${#mounted[@]} -eq ${#MOUNT_POINTS[@]} ]] && break

    (set -x; sleep -- "${INTERVAL}")
  done
}

lxc_ensure_users() {
  `# LXC environment specific. Ensure ${USER} user in the LXC container.`

  declare -a USERS
  declare -i WARMUP_TIME=20
  conf_lxc_ensure_users

  local -r VE_ID="${1}"
  local -r PHASE="${2}"

  ! [[ ' post-start ' == *" ${PHASE} "* ]] && return

  local up_time
  declare -i ctr max_wait=20
  while true; do
    (( ctr++ ))

    up_time="$(lxc-attach -n "${VE_ID}" -- /bin/sh -c "
      grep -o '^[0-9]\+' /proc/uptime
    " 2>/dev/null)" && break

    [ ${ctr} -gt ${max_wait} ] && {
      echo "(${FUNCNAME[0]}) Max attempts failuer" >&2
      return 1
    }

    sleep 1
  done

  local -i interval; interval="$((WARMUP_TIME - "${up_time}"))"
  [ ${interval} -gt 0 ] && sleep -- "${interval}"

  local user
  for user in "${USERS[@]}"; do
    if  lxc-attach -n "${VE_ID}" -- /bin/sh -c "
      id -- '${user}' >/dev/null 2>&1 || useradd -m -- '${user}'
    "; then
      echo "(${FUNCNAME[0]}) User exists or created: ${user}" >&2
      continue
    fi

    echo "(${FUNCNAME[0]}) Can't create user: ${user}" >&2
  done
}

(return 2>/dev/null) || run_hooks "${@}"
