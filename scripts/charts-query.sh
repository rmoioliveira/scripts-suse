#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o noclobber
set -o pipefail
shopt -s inherit_errexit

CMD_NAME="charts-query"
CMD_DESCRIPTION="An wrapper for duckdb to query charts release data."

CHARTS_DIR_CHARTS="${HOME}/.charts"
CHARTS_DIR_DATA="${CHARTS_DIR_CHARTS}/data"
CHARTS_FILE_DB="${CHARTS_DIR_DATA}/charts.db"

deps-validate() {
  cat <<EOF | deps-check
cat
duckdb
getopt
EOF
}

usage-long() {
  local help_text

  help_text=$(
    cat <<EOF
DESCRIPTION:
  ${CMD_DESCRIPTION}

USAGE:
  ${CMD_NAME} <QUERY> [OPTIONS]

OPTIONS:
  -h
          Print duckdb help information
  --help
          Print charts-query help information

EXAMPLES:
  ${CMD_NAME} "SHOW TABLES;"
  ${CMD_NAME} "SELECT * FROM charts WHERE version_rancher = 'v2.15' AND rc AND version_rank = 1" -markdown
  ${CMD_NAME} "SELECT * FROM charts WHERE regexp_matches(version_rancher, 'v2.1[1-5]') AND rc AND version_rank = 1" -csv
  ${CMD_NAME} "SELECT * FROM charts WHERE regexp_matches(version_rancher, 'v2.1[1-5]') AND rc AND version_rank = 1 AND team = '@rancher/observation-backup'" -jsonlines
EOF
  )

  printf 1>&2 "%s\n" "${help_text}"
}

run() {
  exec duckdb "${CHARTS_FILE_DB}" "${@}"
}

main() {
  if [[ -z "${*}" ]]; then
    usage-long
    exit 0
  fi

  if [[ "${*}" == "--help" ]]; then
    usage-long
    exit 0
  fi

  run "${@}"
}

main "${@}"
