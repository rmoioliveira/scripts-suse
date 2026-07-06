#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o nounset
set -o pipefail
set -o noclobber

scripts-unsymlink-echo() {
  find scripts -type f -name "*.sh" -print0 |
    xargs -r -0 realpath |
    awk -F/ '{print $NF}' |
    sed -E 's@(.+)\.sh$@${HOME}/.local/bin/\1@g' |
    envsubst |
    xargs -r -n1 echo rm
}

scripts-unsymlink() {
  find scripts -type f -name "*.sh" -print0 |
    xargs -r -0 realpath |
    awk -F/ '{print $NF}' |
    sed -E 's@(.+)\.sh$@${HOME}/.local/bin/\1@g' |
    envsubst |
    xargs -r -n1 rm
}

main() {
  printf 1>&2 "The following commands will run:\n"
  scripts-unsymlink-echo

  # shellcheck disable=SC2162
  read -p "Do you want to proceed? (y/N)" yn
  case "${yn}" in
  [Yy])
    scripts-unsymlink
    printf 1>&2 "Done.\n"
    ;;
  *)
    printf 1>&2 "No op.\n"
    exit
    ;;
  esac
}

main
