#!/usr/bin/env sh

# USAGE:
#   SCRIPT http://127.0.0.1:1111  # Depending on port

cmd='wget --output-document -'
wget --help >/dev/null 2>&1 || cmd='curl -f'

${cmd} "${1}"
