#!/usr/bin/env bash

# shellcheck disable=SC2317
build() (
  sample_vars() {
    local dest_file="${1}"

    declare -a default_files
    declare tmp; tmp="$(_get_default_files "${@:2}")" || return 0
    local tmp_list; mapfile -t tmp_list <<< "${tmp}"
    default_files+=("${tmp_list[@]}")

    local vars_text
    vars_text="$(_get_vars "${default_files[@]}")" || return 0

    _patch_vars_file "${dest_file}" "${vars_text}"
  }

  _get_default_files() {
    local append result
    local dir; for dir in "${@}"; do
      append="$(
        find "${dir}/roles"/*/defaults \
          -type f -name 'main.yaml' \
        | sort -n | grep '.\+'
      )" || continue

      result+="${result:+$'\n'}${append}"
    done

    [[ -n "${result}" ]] && printf -- '%s\n' "${result}"
  }

  _get_vars() {
    local append result
    local role_name
    local file; for file in "${@}"; do
      append="$(
        sed -e '/^[^- ]/,$!d' -- "${file}" \
        | sed -e '/^\s*#\s*{{\s*NOAPP\s*}}\s*$/,$d'
      )"

      # Drop the file if there is no non-empty lines there
      ! grep -vq '^\s*$' <<< "${append}" && continue

      role_name="$(rev <<< "${file}" | cut -d'/' -f3 | rev)"

      # Skip demo-app role
      [ "${role_name}" == 'demo-app' ] && continue

      result+="${result:+$'\n\n'}"
      result+=$'###\n### '"${role_name^^}"
      result+=$'\n###\n'

      result+="${append}"
    done

    [[ -n "${result}" ]] && printf -- '%s\n' "${result}"
  }

  _patch_vars_file() {
    local dest_file="${1}"
    local vars_text="${2}"

    local dest_file_text; dest_file_text="$(
      sed '1,/^\s*#\s*{{\s*CONFIGURAION\s*}}\s*$/!d' -- "${dest_file}"
    )"
    dest_file_text+=$'\n\n'"${vars_text}"

    (set -x; tee -- "${dest_file}" <<< "${dest_file_text}" >/dev/null)
  }

  "${@}"
)

(return 2>/dev/null) || (
  declare proj_dir; proj_dir="$(dirname -- "${BASH_SOURCE[0]}")/.."
  cd -- "${proj_dir}" || exit

  build sample_vars sample/group_vars/all.yaml .
)
