#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o noclobber
set -o pipefail
shopt -s inherit_errexit

CMD_NAME="charts-query"
CMD_DESCRIPTION_SHORT="A wrapper for duckdb to query chart versions data."
CMD_DESCRIPTION_LONG=$(
  cat <<EOF
A wrapper for duckdb to query chart versions data.

  charts-query uses duckdb query engine to query data fetched from the command
  charts-fetch. Check out duckdb documentation at https://duckdb.org/docs/current/
EOF
)

CHARTS_DIR_CHARTS="${HOME}/.charts"
CHARTS_DIR_DATA="${CHARTS_DIR_CHARTS}/data"
CHARTS_FILE_DB="${CHARTS_DIR_DATA}/charts.db"

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
  -h, --help          Print charts-query help information (use '--help' for more detail)
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
          Print charts-query help information (use '-h' for a summary)

  --help-duckdb
          Print duckdb help information

EXAMPLES:
  ${CMD_NAME} "SHOW TABLES;"

  ${CMD_NAME} "
  SELECT
    version_rancher,
    version_chart,
    string_agg(chart)
  FROM
    charts
  WHERE
    team = '@rancher/observation-backup'
    AND version_rank = 1
    AND rc
  GROUP BY
    version_rancher,
    version_chart
  ORDER BY
    natural_sort(version_rancher),
    natural_sort(version_chart)"
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

  if [[ ! -f "${CHARTS_FILE_DB}" ]]; then
    printf 1>&2 "error: missing charts database.\n"
    printf 1>&2 "run: \`charts-fetch\` first...\n"
    exit 1
  fi

  run "${@}"
}

main "${@}"
