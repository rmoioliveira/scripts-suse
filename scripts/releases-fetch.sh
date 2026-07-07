#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o noclobber
set -o pipefail
shopt -s inherit_errexit

CMD_NAME="releases-fetch"
CMD_DESCRIPTION_SHORT="Fetch all release data from Rancher repos."
CMD_DESCRIPTION_LONG=$(
  cat <<EOF
Fetch all release data from Rancher repos.

  releases-fetch will use the gh utility under the hood to fetch the release
  info from all Rancher-owned repositories and create a duckdb database
  containing all release versions' data. The script will use the following
  directory and files:

    RELEASES_DIR="\${HOME}/.releases"
    RELEASES_DIR_DATA="\${RELEASES_DIR}/data"
    RELEASES_DIR_REPOS="\${RELEASES_DIR_DATA}/repos"
    RELEASES_DIR_RELEASES="\${RELEASES_DIR_DATA}/releases"
    RELEASES_FILE_DB="\${RELEASES_DIR_DATA}/releases.db"

  After fetching, use the releases-query command to query the data.
EOF
)

RELEASES_DIR="${HOME}/.releases"
RELEASES_DIR_DATA="${RELEASES_DIR}/data"
RELEASES_DIR_REPOS="${RELEASES_DIR_DATA}/repos"
RELEASES_DIR_RELEASES="${RELEASES_DIR_DATA}/releases"
RELEASES_FILE_DB="${RELEASES_DIR_DATA}/releases.db"

deps-validate() {
  cat <<EOF | deps-check
duckdb
getopt
gh
jq
mkdir
parallel
EOF
}

usage-short() {
  local help_text

  help_text=$(
    cat <<EOF
DESCRIPTION: ${CMD_DESCRIPTION_SHORT}
USAGE: ${CMD_NAME} [OPTIONS]
OPTIONS:
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
  -h, --help
          Print help information (use '-h' for a summary)

EXAMPLES:
  ${CMD_NAME}
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

db-create-macros() {
  duckdb "${RELEASES_FILE_DB}" -c "
CREATE OR REPLACE MACRO vsort(version) AS list_transform(
  regexp_extract_all(
    IF(regexp_matches(version, '-'), version, concat(version, '-~')),
    '(\D+\d*|\d+)'
  ),
  lambda x: { 's': regexp_extract(x, '(\D*)(\d*)', 1),
  'i': CASE
    WHEN regexp_extract(x, '(\D*)(\d*)', 2) = '' THEN -1
    ELSE CAST(regexp_extract(x, '(\D*)(\d*)', 2) AS BIGINT)
  END }
);"
}

db-create-tables() {
  duckdb "${RELEASES_FILE_DB}" -c "
CREATE
OR REPLACE TABLE releases AS (
  SELECT
    repository,
    createdAt,
    isDraft,
    isImmutable,
    isLatest,
    isPrerelease,
    name,
    publishedAt,
    tagName,
    row_number() OVER (
      PARTITION BY
        repository
      ORDER BY
        vsort(tagName) DESC
    ) AS version_rank
  FROM
    '${RELEASES_DIR_RELEASES}/*.json'
  ORDER BY
    repository,
    version_rank
);

CREATE
OR REPLACE TABLE repositories AS (
  SELECT
    *
  FROM
    '${RELEASES_DIR_REPOS}/*.json'
);
"

  printf 1>&2 "releases db saved in file %s\n" "${RELEASES_FILE_DB}"
}

releases-create-dir-if-missing() {
  if [[ ! -d "${RELEASES_DIR_REPOS}" ]]; then
    printf 1>&2 "creating %s dir\n" "${RELEASES_DIR_REPOS}"
    if ! mkdir -p "${RELEASES_DIR_REPOS}"; then
      printf 1>&2 "couldn't create %s\n" "${RELEASES_DIR_REPOS}"
      exit 1
    fi
  fi

  if [[ ! -d "${RELEASES_DIR_RELEASES}" ]]; then
    printf 1>&2 "creating %s dir\n" "${RELEASES_DIR_RELEASES}"
    if ! mkdir -p "${RELEASES_DIR_RELEASES}"; then
      printf 1>&2 "couldn't create %s\n" "${RELEASES_DIR_RELEASES}"
      exit 1
    fi
  fi

  db-create-macros
}

repository-list() {
  printf 1>&2 "processing repository-list ...\n"

  gh search repos \
    --owner rancher,rancherlabs \
    --archived=false \
    --include-forks=true \
    --limit 1000 \
    --json createdAt,defaultBranch,description,forksCount,fullName,hasDownloads,hasIssues,hasPages,hasProjects,hasWiki,homepage,id,isArchived,isDisabled,isFork,isPrivate,language,name,openIssuesCount,pushedAt,size,stargazersCount,updatedAt,url,visibility,watchersCount >|"${RELEASES_DIR_REPOS}/all.json"
}

releases-fetch() {
  local repo="$1"
  local repo_file="${repo//\//@}.json"

  printf 1>&2 "processing %s ...\n" "${repo}"
  gh release list \
    --repo "${repo}" \
    --limit 1000000 \
    --json createdAt,isDraft,isImmutable,isLatest,isPrerelease,name,publishedAt,tagName |
    jq --arg REPO "${repo}" '.[].repository=$REPO' >|"${RELEASES_DIR_RELEASES}/${repo_file}"
}

gh-auth-status() {
  if ! is_logged=$(gh auth status); then
    printf 1>&2 "%s" "${is_logged}"
    exit 1
  fi
}

export RELEASES_DIR
export RELEASES_DIR_DATA
export RELEASES_DIR_REPOS
export RELEASES_DIR_RELEASES
export RELEASES_FILE_DB
export -f releases-fetch

run() {
  releases-create-dir-if-missing
  gh-auth-status
  repository-list
  <"${RELEASES_DIR_REPOS}/all.json" jq '.[].fullName' -r |
    parallel releases-fetch
  db-create-tables
}

main() {
  deps-validate
  args-parse "$@"
  run
}

main "$@"
