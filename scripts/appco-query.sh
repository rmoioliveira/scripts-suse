#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o noclobber
set -o pipefail
shopt -s inherit_errexit

CMD_NAME="appco-query"
CMD_DESCRIPTION_SHORT="A wrapper for duckdb to query appco versions data."
CMD_DESCRIPTION_LONG=$(
  cat <<EOF
A wrapper for duckdb to query appco versions data.

  appco-query uses duckdb query engine to query data fetched from the command
  appco-fetch. Check out duckdb documentation at https://duckdb.org/docs/current/
EOF
)

APPCO_DIR="${HOME}/.appco"
APPCO_DIR_DATA="${APPCO_DIR}/data"
APPCO_FILE_DB="${APPCO_DIR_DATA}/appco.db"

deps-validate() {
  cat <<EOF | deps-check
duckdb
EOF
}

usage-short() {
  local help_text

  help_text=$(
    cat <<EOF
DESCRIPTION: ${CMD_DESCRIPTION_SHORT}
USAGE: ${CMD_NAME} [OPTIONS]
OPTIONS:
  -h, --help          Print appco-query help information (use '--help' for more detail)
  --help-duckdb       Print duckdb help information
EOF
  )

  printf 1>&2 "%s\n" "${help_text}"
}

usage-long() {
  local help_text

  help_text=$(
    cat <<EOF
DESCRIPTION:
  ${CMD_DESCRIPTION_LONG}

USAGE:
  ${CMD_NAME} <QUERY> [OPTIONS]

OPTIONS:
  -h, --help
          Print appco-query help information (use '-h' for a summary)

  --help-duckdb
          Print duckdb help information

EXAMPLES:
  ${CMD_NAME} "SHOW TABLES;"
  ${CMD_NAME} "SELECT * FROM appco WHERE version_rank = 1"
  ${CMD_NAME} "SELECT * FROM appco WHERE app = 'containers/grafana-image-renderer' AND vsort(version_app) >= vsort('5.8.8')" -csv -noheader
EOF
  )

  printf 1>&2 "%s\n" "${help_text}"
}

run() {
  exec duckdb "${APPCO_FILE_DB}" "$@"
}

main() {
  if [[ -z "${*}" ]]; then
    usage-long
    exit 0
  fi

  if [[ "${*}" == "-h" ]]; then
    usage-short
    exit 0
  fi

  if [[ "${*}" == "--help" ]]; then
    usage-long
    exit 0
  fi

  if [[ "${*}" == "--help-duckdb" ]]; then
    exec duckdb -h
  fi

  if [[ ! -f "${APPCO_FILE_DB}" ]]; then
    printf 1>&2 "error: missing appco database.\n"
    printf 1>&2 "run: \`appco-fetch\` first...\n"
    exit 1
  fi

  run "$@"
}

main "$@"
