#!/usr/bin/env bash

# shellcheck disable=SC2016,SC2092,SC2317,SC2001,SC1090,SC2002

remote_proj_conf() {
  `# In downstream project change SELF_TGZ_URL to the downstream one`
  `# {{ BRANCH }} placeholder to support branches`
  SELF_TGZ_URL='https://github.com/spaghetti-coder/ansible-bookshelf/archive/{{ BRANCH }}.tar.gz'
  SELF_DEFAULT_BRANCH=master `# <- Change to 'main' if you prefer it this way`
  UPSTREAM_TGZ_URL=''
}

remote_proj() (
  local SELF_CONF=remote_proj_conf
  local SELF="${FUNCNAME[0]}"

  print_help() {
    local the_script=remote-proj.sh
    head -c 2 "${0}" 2>/dev/null | grep -q '^#!' && {
      the_script="$(basename -- "${0}" 2>/dev/null)"
    }

    # shellcheck disable=SC2317
    sed -e 's/^\s*//' -e '/^\s*$/d' -e 's/^,//' <<< "
      USAGE:
      =====
      # Given PROJ_DIR doesn't exist or is an empty directory, create a new ansible
      # project based on the current one, see 'SELF_TGZ_URL' in the top of the script
      ${the_script} install PROJ_DIR [BRANCH=${SELF_DEFAULT_BRANCH}]
     ,
      # Given ${the_script} is in its default location in a project created with
      # 'install', pull upstream dependencies
      ${the_script} pull-upstream
    "
  }

  self_install() {
    [ -n "${SELF_TGZ_URL}" ] || {
      printf -- '%s\n' \
        'SELF_TGZ_URL is not configured in the top of the current script.' \
        'Probably, the project does not support inheritance.' \
      >&2
      return 1
    }

    [ -n "${1}" ] || { echo "PROJ_DIR required" >&2; return 1; }

    local PROJ_DIR="${1}"
    local BRANCH="${2-${SELF_DEFAULT_BRANCH}}"

    if true \
      && [ -d "$(realpath -- "${PROJ_DIR}" 2>/dev/null)" ] \
      && (ls -1A -- "${PROJ_DIR}" | grep -q '.') \
    ; then
      echo "The directory must be empty: '${PROJ_DIR}'" >&2; return 1
    fi

    if [ -e "${PROJ_DIR}" ] && ! [ -d "$(realpath -- "${PROJ_DIR}" 2>/dev/null)" ]; then
      echo "Not a directory: ${PROJ_DIR}" >&2; return 1
    fi

    local url; url="$(sed -e 's/{{\s*BRANCH\s*}}/'"${BRANCH}"'/g' <<< "${SELF_TGZ_URL}")"
    local tmp_dir; tmp_dir="$(set -x; mktemp -d)" || return
    dl_tool "${url}" | (set -x; tar --strip-components 1 -xzf - -C "${tmp_dir}") || return

    #
    # Preprocessing
    #
    (
      local UPSTREAM_URL; UPSTREAM_URL="$(sed -e 's/{{\s*BRANCH\s*}}/'"${SELF_DEFAULT_BRANCH}"'/g' <<< "${SELF_TGZ_URL}")"
      local script="${tmp_dir}/.dev/remote-proj.sh"
      local script_txt; script_txt="$(cat -- "${script}")" || exit
      . <(printf -- '%s\n' "${script_txt}")

      {
        declare -f "${SELF_CONF}" | sed  -e 's/\(SELF_TGZ_URL=\)[^;]*/\1'\'\''/' \
                                    -e 's#\(UPSTREAM_TGZ_URL=\)[^;]*#\1'"'${UPSTREAM_URL}'"'#'
        declare -f "${SELF}"
      } | wrap_script_funcs | (set -x; tee -- "${script}" >/dev/null)
    ) || return

    local loc_text; loc_text="$(make_lock_txt "${tmp_dir}" | grep '[^\s]')" && {
      (
        set -x
        tee -- "${tmp_dir}/.lock" <<< "${loc_text}" >/dev/null
      ) || return
    }
    (set -x; cp -- "${tmp_dir}/playbook.yaml" "${tmp_dir}/requirements.yaml" "${tmp_dir}/ansible.cfg" "${tmp_dir}/sample/") || return

    #
    # Install
    #
    (set -x; mkdir -p -- "${PROJ_DIR}") || return
    (set -x; cp -r -- "${tmp_dir}/." "${PROJ_DIR}") || return
    (set -x; rm -rf "${tmp_dir:?}")
  }

  pull_upstream() {
    head -c 2 "${0}" 2>/dev/null | grep -q '^#!' || {
      echo "The script must be executed directly as a bin script." >&2
      return 1
    }

    [ -n "${UPSTREAM_TGZ_URL}" ] || {
      printf -- '%s\n' \
        'UPSTREAM_TGZ_URL is not configured. Probably, the project is not inherited.' \
      >&2
      return 1
    }

    local PROJ_DIR; PROJ_DIR="$(realpath -- "$(dirname -- "${0}")/.." 2>/dev/null)"

    if ! (cd -- "${PROJ_DIR}" &>/dev/null && [ -f .dev/remote-proj.sh ]); then
      echo "remote-proj.sh script must be run from within ansible project directory" >&2
      return 1
    fi

    declare conf_func_text; conf_func_text="$(declare -f "${SELF_CONF}")"
    local tmp_dir; tmp_dir="$(set -x; mktemp -d)" || return
    dl_tool "${UPSTREAM_TGZ_URL}" | (set -x; tar --strip-components 1 -xzf - -C "${tmp_dir}") || return

    #
    # Preprocessing
    #
    ( # Create replace for remote-proj.sh script
      local script="${tmp_dir}/.dev/remote-proj.sh"
      local script_txt; script_txt="$(cat -- "${script}")" || exit
      . <(printf -- '%s\n' "${script_txt}")

      {
        printf -- '%s\n' "${conf_func_text}"
        declare -f "${SELF}"
      } | wrap_script_funcs | (set -x; tee -- "${script}" >/dev/null)
    ) || return

    ( # Create replace for sample-vars.sh script
      local conf_func; conf_func="$(
        local text; text="$(cat "${PROJ_DIR}/.dev/sample-vars.sh")" || exit
        . <(printf -- '%s\n' "${text}")
        declare -f sample_vars_conf
      )" || exit

      local script="${tmp_dir}/.dev/sample-vars.sh"
      local script_txt; script_txt="$(cat -- "${script}")" || exit
      . <(printf -- '%s\n' "${script_txt}")

      {
        printf -- '%s\n' "${conf_func}"
        declare -f sample_vars
      } | SELF=sample_vars wrap_script_funcs | (set -x; tee -- "${script}" >/dev/null)
    ) || return

    local lock_text; lock_text="$(make_lock_txt "${tmp_dir}" | grep '[^\s]')" && {
      (
        set -x
        tee -- "${tmp_dir}/.lock" <<< "${lock_text}" >/dev/null
      ) || return
    }

    cd -- "${PROJ_DIR}" || return

    # Cleanup the project
    cat .lock 2>/dev/null | while read -r f; do
      [ -n "${f}" ] || continue
      [[ "${f}" == *".."* ]] && continue
      (set -x; rm -rf -- "${f:?}")
    done

    # Install updates
    (
      cd -- "${tmp_dir}" || exit
      local -a sample_files=(playbook.yaml requirements.yaml ansible.cfg)
      [ -f changelog.md ] && sample_files+=(changelog.md)

      set -x
      cp "${sample_files[@]}" "${PROJ_DIR}/sample"
      cp -rf .dev .lock bin roles "${PROJ_DIR}"
    ) || return

    "${PROJ_DIR}/.dev/sample-vars.sh" || return

    (set -x; rm -rf "${tmp_dir:?}")
  }

  dl_tool() {
    local url="${1}"

    curl --version &>/dev/null && {
      (set -x; curl -fsSL -- "${url}"); return
    }

    (set -x; wget -q -O - -- "${url}")
  }

  wrap_script_funcs() {
    printf -- '%s\n' \
      '#!/usr/bin/env bash' '' \
      '# shellcheck disable=SC2016,SC2092,SC2317,SC2001,SC1090,SC2002' '' \
      "$(cat)" \
      '' '(return 2>/dev/null) || { '"${SELF}"' "${@}"; exit; }'
  }

  make_lock_txt() {
    local dir="${1}"
    ( set -o pipefail; {
      cd -- "${dir}" || exit
      [ -d .dev ]   && find ./.dev -type f
      [ -d bin ]    && find ./bin -type f
      [ -d roles ]  && find ./roles -mindepth 2 -maxdepth 2 -type d
    } | LC_ALL=C sort -n )
  }

  main() {
    "${SELF_CONF}"

    declare -A FUNC_MAP=(
      [install]=self_install
      [pull-upstream]=pull_upstream
    )

    [[ "${1}" =~ ^(-\?|-h|--help)$ ]] && { print_help; return; }

    { [ -n "${FUNC_MAP[${1}]}" ]; } 2>/dev/null || {
      echo "Unsupported command: '${1}'" >&2; return 1
    }

    "${FUNC_MAP[${1}]}" "${@:2}"
  }

  main "${@}"
)

(return 2>/dev/null) || { remote_proj "${@}"; exit; }
