#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o noclobber
set -o pipefail
shopt -s inherit_errexit

CMD_NAME="appco-fetch"
CMD_DESCRIPTION="Fetch all appco release information."
CMD_DESCRIPTION_LONG=$(
  cat <<EOF
Fetch all appco release information.

  appco-fetch will use the curl utility under the hood to fetch the release info
  from all appco registry and create a duckdb database containing all release
  versions' data. The script will use the following directory and files:

    APPCO_DIR="\${HOME}/.appco"
    APPCO_DIR_DATA="\${APPCO_DIR}/data"
    APPCO_LIST="\${APPCO_DIR_DATA}/appco-list.json"
    APPCO_OBJECT="\${APPCO_DIR_DATA}/appco-object.json"
    APPCO_FILE_DB="\${APPCO_DIR_DATA}/appco.db"

  After fetching, use the appco-query command to query the data.
EOF
)

APPCO_DIR="${HOME}/.appco"
APPCO_DIR_DATA="${APPCO_DIR}/data"
APPCO_LIST="${APPCO_DIR_DATA}/appco-list.json"
APPCO_OBJECT="${APPCO_DIR_DATA}/appco-object.json"
APPCO_FILE_DB="${APPCO_DIR_DATA}/appco.db"

deps-validate() {
  cat <<EOF | deps-check
cat
curl
getopt
jq
mkdir
parallel
sed
EOF
}

usage-short() {
  local help_text

  help_text=$(
    cat <<EOF
DESCRIPTION: ${CMD_DESCRIPTION}
USAGE: ${CMD_NAME} [OPTIONS]
OPTIONS:
      --token <TOKEN> Auth token to login in appco
  -h, --help          Print help information (use '--help' for more detail)
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
  ${CMD_NAME} [OPTIONS]

OPTIONS:
      --token <TOKEN>
          Auth token to login in appco
          Token format: "<your-username-or-sa-username>:<access-token-or-sa-secret>"
          See more info: https://docs.apps.rancher.io/get-started/authentication

  -h, --help
          Print help information (use '-h' for a summary)

EXAMPLES:
  ${CMD_NAME} --token \$(pass work/suse/appco-registry-token | base64 -d)
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
      --long help,token: \
      -- "$@"
  ); then
    printf 1>&2 "\nFor more information try '--help'\n"
    exit 1
  fi
  eval set -- "${args}"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
    --token)
      shift
      TOKEN="$1"
      ;;
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

db-create-macros() {
  duckdb "${APPCO_FILE_DB}" -c "
CREATE OR REPLACE MACRO vsort(version) AS list_transform(
  regexp_extract_all(
    IF(regexp_matches(version, '-'), concat(version, '-~'), version),
    '(\D+\d*|\d+)'
  ),
  lambda x: { 's': regexp_extract(x, '(\D*)(\d*)', 1),
  'i': CASE
    WHEN regexp_extract(x, '(\D*)(\d*)', 2) = '' THEN -1
    ELSE CAST(regexp_extract(x, '(\D*)(\d*)', 2) AS INTEGER)
  END }
);"
}

db-create-tables() {
  duckdb "${APPCO_FILE_DB}" -c "
DROP TABLE IF EXISTS table_appco;
CREATE TABLE table_appco AS (
  SELECT
    name AS app,
    UNNEST(tags) AS version_app
  FROM
   '${APPCO_OBJECT}'
);
CREATE
OR REPLACE TABLE appco AS (
  SELECT
    app,
    version_app,
    row_number() OVER (
      PARTITION BY
        app
      ORDER BY
        vsort(version_app) DESC
    ) AS version_rank
  FROM
    table_appco
  ORDER BY
    app,
    version_rank
);
DROP TABLE table_appco;
"

  printf 1>&2 "appco db saved in file %s\n" "${APPCO_FILE_DB}"
}

appco-create-dir-if-missing() {
  if [[ ! -d "${APPCO_DIR_DATA}" ]]; then
    printf 1>&2 "creating %s dir\n" "${APPCO_DIR_DATA}"
    if ! mkdir -p "${APPCO_DIR_DATA}"; then
      printf 1>&2 "couldn't create %s\n" "${APPCO_DIR_DATA}"
      exit 1
    fi
  fi

  db-create-macros
}

args-validate() {
  if [[ -z "${TOKEN}" ]]; then
    printf 1>&2 "error: invalid value '%s' for '--token <TOKEN>'\n" "${TOKEN}"
    printf 1>&2 "\nFor more information try '--help'\n"
    exit 1
  fi
}

curl-appco-repos() {
  printf 1>&2 "processing appco repos ...\n"
  curl -u "${TOKEN}" 'https://dp.apps.rancher.io/v2/_catalog' --no-progress-meter |
    jq '.repositories[]' -r |
    sed -E 's@(.+)@https://dp.apps.rancher.io/v2/\1/tags/list@g'
}

curl-appco-apps() {
  local url="$1"
  printf 1>&2 "processing %s ...\n" "${url}"
  curl -u "${TOKEN}" "${url}" --no-progress-meter
}

export -f curl-appco-repos
export -f curl-appco-apps
export TOKEN

appco-fetch() {
  curl-appco-repos |
    parallel curl-appco-apps |
    jq -s >|"${APPCO_LIST}"
  2>&1 printf "saving list to %s\n" "${APPCO_LIST}"

  <"${APPCO_LIST}" jq '[.[] | del(.child) | .tags=([.tags[] | select(. | contains("sha256") | not)])]' >|"${APPCO_OBJECT}"
  2>&1 printf "saving object to %s\n" "${APPCO_OBJECT}"
}

run() {
  appco-create-dir-if-missing
  appco-fetch
  db-create-tables
}

main() {
  deps-validate
  args-parse "$@"
  args-validate
  run
}

main "$@"
