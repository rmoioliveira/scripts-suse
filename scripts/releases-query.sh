#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o noclobber
set -o pipefail
shopt -s inherit_errexit

CMD_NAME="releases-query"
CMD_DESCRIPTION_SHORT="A wrapper for duckdb to query releases versions data."
CMD_DESCRIPTION_LONG=$(
  cat <<EOF
A wrapper for duckdb to query releases versions data.

  releases-query uses duckdb query engine to query data fetched from the command
  releases-fetch. Check out duckdb documentation at https://duckdb.org/docs/current/
EOF
)

RELEASES_DIR="${HOME}/.releases"
RELEASES_DIR_DATA="${RELEASES_DIR}/data"
RELEASES_FILE_DB="${RELEASES_DIR_DATA}/releases.db"

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
  -h, --help          Print releases-query help information (use '--help' for more detail)
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
          Print releases-query help information (use '-h' for a summary)

  --help-duckdb
          Print duckdb help information

EXAMPLES:
  ${CMD_NAME} "SHOW TABLES;"
  ${CMD_NAME} "SELECT repository, tagName FROM releases WHERE isLatest"
  ${CMD_NAME} "SELECT name, * FROM repositories ORDER BY stargazersCount DESC"
EOF
  )

  printf 1>&2 "%s\n" "${help_text}"
}

run() {
  exec duckdb "${RELEASES_FILE_DB}" "$@"
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

  if [[ ! -f "${RELEASES_FILE_DB}" ]]; then
    printf 1>&2 "error: missing releases database.\n"
    printf 1>&2 "run: \`releases-fetch\` first...\n"
    exit 1
  fi

  run "$@"
}

main "$@"
