#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o noclobber
set -o pipefail
shopt -s inherit_errexit

CMD_NAME="charts-fetch"
CMD_DESCRIPTION_SHORT="Fetch all chart versions data."
CMD_DESCRIPTION_LONG=$(
  cat <<EOF
Fetch all chart versions data.

  charts-fetch will clone the rancher/charts repository to \${HOME}/.charts and
  create a duckdb database containing all chart versions data. The script will
  use the following directory and files:

    CHARTS_DIR_CHARTS="\${HOME}/.charts"
    CHARTS_DIR_REPO="\${CHARTS_DIR_CHARTS}/repo"
    CHARTS_DIR_DATA="\${CHARTS_DIR_CHARTS}/data"
    CHARTS_FILE_LIST="\${CHARTS_DIR_DATA}/charts-list.csv"
    CHARTS_FILE_DB="\${CHARTS_DIR_DATA}/charts.db"
    CHARTS_GIT_REMOTE="https://github.com/rancher/charts.git"

  After fetching, use the charts-query command to query the data.
EOF
)

CHARTS_DIR_CHARTS="${HOME}/.charts"
CHARTS_DIR_REPO="${CHARTS_DIR_CHARTS}/repo"
CHARTS_DIR_DATA="${CHARTS_DIR_CHARTS}/data"
CHARTS_FILE_LIST="${CHARTS_DIR_DATA}/charts-list.csv"
CHARTS_FILE_DB="${CHARTS_DIR_DATA}/charts.db"
CHARTS_GIT_REMOTE="https://github.com/rancher/charts.git"

deps-validate() {
  cat <<EOF | deps-check
awk
duckdb
getopt
git
grep
mkdir
parallel
sed
sort
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
      -- "${@}"
  ); then
    printf 1>&2 "\nFor more information try '--help'\n"
    exit 1
  fi
  eval set -- "${args}"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
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
  duckdb "${CHARTS_FILE_DB}" -c "
CREATE OR REPLACE MACRO version_sort(version) AS list_transform(
  regexp_extract_all(
    IF(regexp_matches(version, '-rc'), version, concat(version, '-z')),
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
  duckdb "${CHARTS_FILE_DB}" -c "
DROP TABLE IF EXISTS table_rc;
DROP TABLE IF EXISTS table_join;
DROP TABLE IF EXISTS team_charts;
CREATE TABLE team_charts (team VARCHAR, chart VARCHAR);
INSERT INTO
  team_charts
VALUES
  (NULL, 'epinio'),
  (NULL, 'epinio-crd'),
  (NULL, 'rancher-external-ip-webhook'),
  (NULL, 'ui-plugin-operator-crd'),
  (NULL, 'rancher-windows-gmsa'),
  (NULL, 'rancher-pushprox'),
  (NULL, 'rancher-prometheus-adapter'),
  (NULL, 'rancher-gatekeeper-crd'),
  (NULL, 'rancher-node-exporter'),
  (NULL, 'rancher-sachet'),
  (NULL, 'ui-plugin-operator'),
  (NULL, 'rancher-kiali-server-crd'),
  (NULL, 'rancher-windows-gmsa-crd'),
  (NULL, 'rancher-cis-benchmark'),
  (NULL, 'rancher-grafana'),
  (NULL, 'suse-observability-agent'),
  (NULL, 'rancher-vsphere-csi'),
  (NULL, 'rio'),
  (NULL, 'rancher-tracing'),
  (NULL, 'rancher-prom2teams'),
  (NULL, 'rancher-gatekeeper'),
  (NULL, 'rancher-kube-state-metrics'),
  (NULL, 'rancher-vsphere-cpi'),
  (NULL, 'rancher-istio'),
  (NULL, 'rancher-wins-upgrader'),
  (NULL, 'rancher-cis-benchmark-crd'),
  (NULL, 'rancher-project-monitoring'),
  (NULL, 'rancher-windows-exporter'),
  (NULL, 'rancher-kiali-server'),
  ('@rancher/elemental', 'elemental-crd'),
  ('@rancher/elemental', 'elemental'),
  ('@rancher/fleet', 'fleet-agent'),
  ('@rancher/fleet', 'fleet-crd'),
  ('@rancher/fleet', 'fleet'),
  ('@rancher/harvester', 'harvester-cloud-provider'),
  ('@rancher/harvester', 'harvester-csi-driver'),
  ('@rancher/harvester', 'harvester-rbac'),
  ('@rancher/highlander', 'rancher-turtles'),
  ('@rancher/infracloud-team', 'rancher-aks-operator-crd'),
  ('@rancher/infracloud-team', 'rancher-eks-operator'),
  ('@rancher/infracloud-team', 'rancher-gke-operator-crd'),
  ('@rancher/infracloud-team', 'rancher-compliance'),
  ('@rancher/infracloud-team', 'rancher-gke-operator'),
  ('@rancher/infracloud-team', 'rancher-aks-operator'),
  ('@rancher/infracloud-team', 'rancher-eks-operator-crd'),
  ('@rancher/infracloud-team', 'rancher-compliance-crd'),
  ('@rancher/k3s', 'sriov'),
  ('@rancher/k3s', 'sriov-crd'),
  ('@rancher/longhorn', 'longhorn-crd'),
  ('@rancher/longhorn', 'longhorn'),
  ('@rancher/neuvector', 'neuvector-monitor'),
  ('@rancher/neuvector', 'neuvector'),
  ('@rancher/neuvector', 'neuvector-crd'),
  ('@rancher/observation-backup', 'prometheus-federator'),
  ('@rancher/observation-backup', 'rancher-backup'),
  ('@rancher/observation-backup', 'rancher-logging-crd'),
  ('@rancher/observation-backup', 'rancher-backup-crd'),
  ('@rancher/observation-backup', 'rancher-alerting-drivers'),
  ('@rancher/observation-backup', 'rancher-monitoring'),
  ('@rancher/observation-backup', 'rancher-logging'),
  ('@rancher/observation-backup', 'rancher-monitoring-crd'),
  ('@rancher/rancher-release-team', 'rancher-webhook'),
  ('@rancher/rancher-release-team', 'remotedialer-proxy'),
  ('@rancher/rancher-team-2-hostbusters-dev', 'system-upgrade-controller'),
  ('@rancher/rancher-team-2-hostbusters-dev', 'rancher-provisioning-capi'),
  ('@rancher/socket', 'rancher-csp-adapter'),
  ('@rancher/support-team', 'rancher-supportability-review-crd'),
  ('@rancher/support-team', 'rancher-supportability-review');
CREATE TABLE table_rc AS (
  SELECT
    *,
    regexp_extract(branch, 'dev-(v[0-9.]+)$', 1) AS version_rancher,
    regexp_matches(version_chart, '-rc') AS rc
  FROM
    '${CHARTS_FILE_LIST}'
);
CREATE TABLE table_join AS (
  SELECT
    *
  FROM
    table_rc NATURAL
    JOIN team_charts
);
CREATE
OR REPLACE TABLE charts AS (
  SELECT
    branch,
    version_rancher,
    team,
    chart,
    version_chart,
    row_number() OVER (
      PARTITION BY
        version_rancher,
        chart
      ORDER BY
        version_sort(version_chart) DESC
    ) AS version_rank,
    rc
  FROM
    table_join
  ORDER BY
    version_sort(version_rancher),
    chart,
    version_rank
);
DROP TABLE table_rc;
DROP TABLE table_join;
DROP TABLE team_charts;
"

  printf 1>&2 "charts db saved in file %s\n" "${CHARTS_FILE_DB}"
}

charts-create-dir-if-missing() {
  if [[ ! -d "${CHARTS_DIR_DATA}" ]]; then
    printf 1>&2 "creating %s dir\n" "${CHARTS_DIR_DATA}"
    if ! mkdir -p "${CHARTS_DIR_DATA}"; then
      printf 1>&2 "couldn't create %s\n" "${CHARTS_DIR_DATA}"
      exit 1
    fi
  fi

  if [[ ! -d "${CHARTS_DIR_REPO}" ]]; then
    printf 1>&2 "cloning repo %s into %s\n" "${CHARTS_GIT_REMOTE}" "${CHARTS_DIR_REPO}"
    if ! git clone "${CHARTS_GIT_REMOTE}" "${CHARTS_DIR_REPO}"; then
      printf 1>&2 "couldn't clone repo %s into %s\n" "${CHARTS_GIT_REMOTE}" "${CHARTS_DIR_REPO}"
      exit 1
    fi
  fi

  db-create-macros
}

git-fetch-all() {
  printf 1>&2 "fetching all branches from remote\n"
  1>&2 git -C "${CHARTS_DIR_REPO}" fetch --all
}

git-branch-remotes() {
  git -C "${CHARTS_DIR_REPO}" -P branch --remotes |
    grep "origin/dev-v2" |
    sort -u |
    grep -E '[0-9]$' |
    grep HEAD -v |
    sort -V |
    sed 's@[[:space:]]@@g'
}

git-ls-tree() {
  local branch="$1"

  git -C "${CHARTS_DIR_REPO}" ls-tree -r -d "${branch}" --name-only |
    grep ^charts |
    awk -F/ -v branch="${branch}" 'BEGIN { OFS=","} {print branch,$2,$3}' |
    grep -E '[0-9]$' |
    sort --field-separator=, -u -k1,1 -k2,2 -rVk3,3
}

export CHARTS_DIR_CHARTS
export CHARTS_DIR_REPO
export CHARTS_DIR_DATA
export CHARTS_FILE_LIST
export CHARTS_FILE_DB
export -f git-ls-tree

run() {
  charts-create-dir-if-missing
  git-fetch-all
  git-branch-remotes |
    parallel git-ls-tree |
    sed '1i branch,chart,version_chart' >|"${CHARTS_FILE_LIST}"
  printf 1>&2 "charts list saved in file %s\n" "${CHARTS_FILE_LIST}"

  db-create-tables
}

main() {
  deps-validate
  args-parse "${@}"
  run
}

main "${@}"
