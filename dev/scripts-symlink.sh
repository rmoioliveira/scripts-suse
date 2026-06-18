#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o nounset
set -o pipefail
set -o noclobber

scripts-symlink-echo() {
  paste -d " " \
    <(find scripts -type f -name "*.sh" -print0 | xargs -0 realpath) \
    <(find scripts -type f -name "*.sh" -print0 | xargs -0 realpath | awk -F/ '{print $NF}' | sed -E 's@(.+)\.sh$@${HOME}/.local/bin/\1@g' | envsubst) |
    xargs -r -n2 echo ln -s
}

scripts-symlink() {
  paste -d " " \
    <(find scripts -type f -name "*.sh" -print0 | xargs -0 realpath) \
    <(find scripts -type f -name "*.sh" -print0 | xargs -0 realpath | awk -F/ '{print $NF}' | sed -E 's@(.+)\.sh$@${HOME}/.local/bin/\1@g' | envsubst) |
    xargs -r -n2 ln -s
}

main() {
  printf 1>&2 "The following commands will run:\n"
  scripts-symlink-echo
  # shellcheck disable=SC2162
  read -p "Do you want to proceed? (y/N)" yn
  case "${yn}" in
  [Yy])
    scripts-symlink
    printf 1>&2 "Done.\n"
    ;;
  *)
    printf 1>&2 "No op.\n"
    exit
    ;;
  esac
}

main
