# scripts suse

This repository contains day-to-day operations scripts.

To add these scripts to your `$PATH`, run `make scripts-symlink`. The
scripts will be added to `${HOME}/.local/bin/`. If this directory isn't
already in your `$PATH`, please add it.

To view all available recipes, use `make help`.

# index

- [Utilities](#utilities)
  - [Command: charts-fetch](#command-charts-fetch)
  - [Command: charts-query](#command-charts-query)
  - [Command: deps-check](#command-deps-check)
  - [Command: releases-fetch](#command-releases-fetch)
  - [Command: releases-query](#command-releases-query)
- [Make Recipes](#make-recipes)
- [How to Release](#how-to-release)

# Utilities

[back^](#index)

## Command: charts-fetch

[back^](#index)

```
DESCRIPTION:
  Fetch all chart versions data.

  charts-fetch will clone the rancher/charts repository to ${HOME}/.charts and
  create a duckdb database containing all chart versions' data. The script will
  use the following directory and files:

    CHARTS_DIR_CHARTS="${HOME}/.charts"
    CHARTS_DIR_REPO="${CHARTS_DIR_CHARTS}/repo"
    CHARTS_DIR_DATA="${CHARTS_DIR_CHARTS}/data"
    CHARTS_FILE_LIST="${CHARTS_DIR_DATA}/charts-list.csv"
    CHARTS_FILE_DB="${CHARTS_DIR_DATA}/charts.db"
    CHARTS_GIT_REMOTE="https://github.com/rancher/charts.git"

  After fetching, use the charts-query command to query the data.

USAGE:
  charts-fetch [OPTIONS]

OPTIONS:
  -h, --help
          Print help information (use '-h' for a summary)

EXAMPLES:
  charts-fetch
```

## Command: charts-query

[back^](#index)

```
DESCRIPTION:
  A wrapper for duckdb to query chart versions data.

  charts-query uses duckdb query engine to query data fetched from the command
  charts-fetch. Check out duckdb documentation at https://duckdb.org/docs/current/

USAGE:
  charts-query <QUERY> [OPTIONS]

OPTIONS:
  -h, --help
          Print charts-query help information (use '-h' for a summary)

  --help-duckdb
          Print duckdb help information

EXAMPLES:
  charts-query "SHOW TABLES;"
  charts-query "
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
    version_sort(version_rancher),
    version_sort(version_chart)
  "
```

## Command: deps-check

[back^](#index)

```
DESCRIPTION:
  Check if dependencies are installed.

USAGE:
  deps-check [OPTIONS]

OPTIONS:
  -h, --help
          Print help information (use '-h' for a summary)

EXAMPLES:
cat <<EOF | deps-check
iconv
kubectl
nmap
EOF
```

## Command: releases-fetch

[back^](#index)

```
DESCRIPTION:
  Fetch all release data from Rancher repos.

  releases-fetch will use the gh utility under the hood to fetch the release
  info from all Rancher-owned repositories and create a duckdb database
  containing all release versions' data. The script will use the following
  directory and files:

    RELEASES_DIR="${HOME}/.releases"
    RELEASES_DIR_DATA="${RELEASES_DIR}/data"
    RELEASES_DIR_REPOS="${RELEASES_DIR_DATA}/repos"
    RELEASES_DIR_RELEASES="${RELEASES_DIR_DATA}/releases"
    RELEASES_FILE_DB="${RELEASES_DIR_DATA}/releases.db"

  After fetching, use the releases-query command to query the data.

USAGE:
  releases-fetch [OPTIONS]

OPTIONS:
  -h, --help
          Print help information (use '-h' for a summary)

EXAMPLES:
  releases-fetch
```

## Command: releases-query

[back^](#index)

```
DESCRIPTION:
  A wrapper for duckdb to query releases versions data.

  releases-query uses duckdb query engine to query data fetched from the command
  releases-fetch. Check out duckdb documentation at https://duckdb.org/docs/current/

USAGE:
  releases-query <QUERY> [OPTIONS]

OPTIONS:
  -h, --help
          Print releases-query help information (use '-h' for a summary)

  --help-duckdb
          Print duckdb help information

EXAMPLES:
  releases-query "SHOW TABLES;"
  releases-query "SELECT repository, tagName FROM releases WHERE isLatest"
  releases-query "SELECT name, * FROM repositories ORDER BY stargazersCount DESC"
```

# Make Recipes

[back^](#index)

```
bash-all               Run all bash tests
bash-check             Check format bash code
bash-deps              Install bash dependencies
bash-fmt               Format bash code
bash-lint              Check lint bash code
doc-changelog          Write CHANGELOG.md
doc-readme             Write README.md
dprint-check           Dprint check
dprint-fmt             Dprint format
help                   Display this help screen
makefile-descriptions  Check if all Makefile rules have descriptions
scripts-symlink        Symlink scripts to local folder in PATH
scripts-unsymlink      Unsymlink scripts from local folder in PATH
typos                  Check typos
typos-fix              Fix typos
```

# How to Release

[back^](#index)

To generate a new version, you need to follow these steps:

1. Run the command `git tag -a <your.new.version> -m "version <your.new.version>"`.
2. Run the command `make doc-changelog doc-readme`.
3. Run the command `git add -A && git commit -m "release: <your.new.version>"`.
4. Run `git push` to `main`.
