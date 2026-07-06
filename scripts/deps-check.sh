#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o noclobber
set -o pipefail
shopt -s inherit_errexit

CMD_NAME="deps-check"
CMD_DESCRIPTION="Check if dependencies are installed."

usage-short() {
  local help_text

  help_text=$(
    cat <<EOF
DESCRIPTION: ${CMD_DESCRIPTION}
USAGE: ${CMD_NAME} [OPTIONS]
OPTIONS:
  -h, --help  Print help information (use '--help' for more detail)
EOF
  )

  printf 1>&2 "%s\n" "${help_text}"
}

usage-long() {
  local help_text
  local eof="EOF"

  help_text=$(
    cat <<EOF
DESCRIPTION:
  ${CMD_DESCRIPTION}

USAGE:
  ${CMD_NAME} [OPTIONS]

OPTIONS:
  -h, --help
          Print help information (use '-h' for a summary)

EXAMPLES:
cat <<${eof} | ${CMD_NAME}
iconv
kubectl
nmap
${eof}
EOF
  )

  printf 1>&2 "%s\n" "${help_text}"
}

args-parse() {
  local args

  if ! args=$(
    getopt -a \
      -n "${CMD_NAME}" \
      -o h \
      --long help \
      -- "$@"
  ); then
    printf 1>&2 "\nFor more information try '--help'\n"
    exit 1
  fi
  eval set -- "${args}"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
    -h)
      usage-short
      exit 0
      ;;
    --help)
      usage-long
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *) usage-long ;;
    esac
    shift
  done
}

deps-check() {
  summary=()
  is_valid=true

  while IFS= read -r line; do deps+=("${line}"); done
  for dep in "${deps[@]}"; do
    if ! command -v "${dep}" >/dev/null; then
      summary+=("[deps] Fail ${dep}")
      is_valid=false

      set +o errexit
      cnf=$(/usr/lib/command-not-found "${dep}")
      echo "${cnf}"
      set -o errexit
    else
      summary+=("[deps] OK   ${dep}")
    fi
  done

  if [[ "${is_valid}" == false ]]; then
    printf 1>&2 "%s\n" "${summary[@]}"
    exit 1
  fi
}

main() {
  args-parse "$@"
  deps-check "$@"
}

main "$@"
