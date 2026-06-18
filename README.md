# scripts

# index

- [Utilities](#utilities)
  - [Command: charts-fetch](#command-charts-fetch)
  - [Command: charts-query](#command-charts-query)
  - [Command: deps-check](#command-deps-check)
- [Make Recipes](#make-recipes)
- [How to Release](#how-to-release)

# Utilities

[back^](#index)

## Command: charts-fetch

[back^](#index)

```
DESCRIPTION:
  Fetch all charts release data.

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
  An wrapper for duckdb to query charts release data.

USAGE:
  charts-query <QUERY> [OPTIONS]

OPTIONS:
  -h
          Print duckdb help information
  --help
          Print charts-query help information

EXAMPLES:
  charts-query "SHOW TABLES;"
  charts-query "SELECT * FROM charts WHERE version_rancher = 'v2.15' AND rc AND version_rank = 1" -markdown
  charts-query "SELECT * FROM charts WHERE regexp_matches(version_rancher, 'v2.1[1-5]') AND rc AND version_rank = 1" -csv
  charts-query "SELECT * FROM charts WHERE regexp_matches(version_rancher, 'v2.1[1-5]') AND rc AND version_rank = 1 AND team = '@rancher/observation-backup'" -jsonlines
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
