#!/usr/bin/env bash

# shellcheck disable=SC2092

sample_vars_conf() {
  `# Relative to the project directory paths to roles`
  ROLES_PATHS=(./roles/base ./roles/service ./roles/desktop)
}

sample_vars() (
  local DEST_FILE=./sample/group_vars/all.yaml
  local PROJ_DIR; PROJ_DIR="$(dirname -- "${BASH_SOURCE[0]}")/.."

  declare -A ARGS=(
    [is_help]=false
  )

  parse_args() {
    while [ ${#} -gt 0 ]; do
      case "${1}" in
        -\?|-h|--help     ) ARGS[is_help]=true ;;
      esac

      shift
    done
  }

  trap_help() {
    ${ARGS[is_help]} || return

    local the_script; the_script=sample-vars.sh
    grep -q '.\+' -- "${0}" && the_script="$(basename -- "${0}")"

    _text_fmt "
      Build sample vars file based on defaults in available roles.

      Usage:
      =====
      ${the_script}
    "
  }

  _get_default_files() {
    local append result
    local dir; for dir in "${@}"; do
      append="$(
        find -- "${dir}" -mindepth 3 -maxdepth 3 \
          -type f -path '*/defaults/main.yaml' \
        | LC_ALL=C sort -n | grep '.\+'
      )" || continue

      result+="${result:+$'\n'}${append}"
    done

    [[ -z "${result}" ]] || printf -- '%s\n' "${result}"
  }

  _get_vars() {
    local append result
    local section section_prev section_len
    local role_name role_len
    local file; for file in "${@}"; do
      append="$(
        sed -e '/^[^- ]/,$!d' -- "${file}" \
        | sed -e '/^\s*#\s*{{\s*NOAPP\s*}}\s*$/,$d'
      )"

      # Drop the file if there is no non-empty lines there
      ! grep -vq '^\s*$' <<< "${append}" && continue

      role_name="$(rev <<< "${file}" | cut -d'/' -f3 | rev)"

      section="$(rev <<< "${file}" | cut -d'/' -f4 | rev)"
      ! [ "${section}" = "${section_prev}" ] && {
        section_prev="${section}"
        section_len="${#section}"

        result+="${result:+$'\n\n\n\n'}$(
          printf '%*s\n' "$(( section_len + 20 ))" | tr ' ' '#'
          printf "###       %s       ###\n" "${section^^}"
          printf '%*s\n' "$(( section_len + 20 ))" | tr ' ' '#'
        )"
      }

      role_len="${#role_name}"
      result+="${result:+$'\n\n'}"
      result+="$(
        printf '# '; printf '%*s\n' "$(( role_len + 12 ))" | tr ' ' '='
        printf "#       %s\n" "${role_name^^}"
        printf '# '; printf '%*s\n' "$(( role_len + 12 ))" | tr ' ' '='
      )"

      result+=$'\n'"${append}"
    done

    [[ -z "${result}" ]] || printf -- '%s\n' "${result}"
  }

  _patch_dest_file() {
    local vars_text="${1}"
    vars_text+="${vars_text:+$'\n'}"

    local head; head="$(
      sed '1,/^\s*#\+\s*{{\s*ROLES_CONF_TS4LE64m91\s*}}\s*\(#.*\)\?$/!d' -- "${DEST_FILE}" 2>/dev/null
    )" && head+=$'\n\n\n\n'

    local dest_dir; dest_dir="$(dirname -- "${DEST_FILE}")"
    {
      printf -- '%s' "${head}" "${vars_text}"
    } | (
      set -x
      mkdir -p -- "${dest_dir}" \
      && tee -- "${DEST_FILE}" >/dev/null
    )
  }

  _text_fmt() {
    local content; content="$(
      sed '/[^ ]/,$!d' <<< "${1-"$(cat)"}" | tac | sed '/[^ ]/,$!d' | tac
    )"
    local offset; offset="$(grep -o -m1 '^\s*' <<< "${content}")"
    sed -e 's/^\s\{0,'${#offset}'\}//' -e 's/\s\+$//' <<< "${content}"
  }

  main() {
    sample_vars_conf

    parse_args "${@}" || return
    trap_help && return

    cd -- "${PROJ_DIR}" || return

    declare -a default_files tmp_list
    local tmp; tmp="$(_get_default_files "${ROLES_PATHS[@]}")"

    [ -n "${tmp}" ] && mapfile -t tmp_list <<< "${tmp}"
    default_files+=("${tmp_list[@]}")

    local vars_text
    vars_text="$(_get_vars "${default_files[@]}")"

    _patch_dest_file "${vars_text}" || return
  }

  main "${@}"
)

(return 2>/dev/null) || sample_vars "${@}"
