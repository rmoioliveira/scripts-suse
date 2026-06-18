#!/usr/bin/env bash

declare TRACE
[[ "${TRACE}" == 1 ]] && set -o xtrace
set -o errexit
set -o nounset
set -o pipefail
set -o noclobber
shopt -s inherit_errexit

clean-tempdir() {
  rm -rf "${TMP_DIR}"
}

mktempdir() {
  if ! TMP_DIR=$(mktemp -d -t scripts-XXXXXXXXXX); then
    printf 1>&2 "Couldn't create %s\n" "${TMP_DIR}"
    exit 1
  fi
}

trap clean-tempdir EXIT

index() {
  mktempdir

  paste -d "" \
    <(
      <README.md grep -E '^#{1,} [A-Z]' |
        sed 's/^ {1,}//g' |
        sed -E 's/(^#{1,}) (.+)/\1\[\2]/g' |
        sed 's/#/  /g' |
        sed -E 's/\[/- [/g'
    ) \
    <(
      <README.md grep -E '^#{1,} [A-Z]' |
        sed 's/#//g' |
        sed -E 's/^ {1,}//g' |
        # https://www.gnu.org/software/grep/manual/html_node/Character-Classes-and-Bracket-Expressions.html
        sed -E "s1[][!#$%&'()*+,./:;<=>?@\\^_\`{|}~]11g" |
        sed -E 's/"//g' |
        sed 's/[A-Z]/\L&/g' |
        sed 's/ /-/g' |
        sed -E 's@(.+)@(#\1)@g'
    ) >"${TMP_DIR}/index.md"

  index_text=$(
    sed -E ':a;N;$!ba;s/\n/\\n/g;' "${TMP_DIR}/index.md" |
      sed -E 's@\[@\\[@g' |
      sed -E 's@\]@\\]@g' |
      sed -E 's@\(@\\(@g' |
      sed -E 's@\)@\\)@g'
  )
  sed -i -E "s/INDEX/${index_text}/g" README.md
}

backlink() {
  sed -i -E '/^#{1,} [A-Z]/a\\n\[back^\](#index)' README.md
}

doc-readme() {
  cat <<EOF >|README.md
# scripts

# index

INDEX

# Utilities
$(
    git ls-files |
      xargs grep -rE CMD_NAME -l |
      grep doc-readme -v |
      grep README -v |
      sort |
      xargs -I{} bash -c '
      echo {} |
        xargs basename |
        sed "s@.sh@@g" |
        sed -E "s@(.+)@\n## Command: \1\n@g";
        echo \`\`\`;
        {} 2>&1 --help;
        echo \`\`\`;'
  )

# Make Recipes

\`\`\`
$(make help)
\`\`\`

# How to Release

$(cat RELEASE.md)
EOF

  sed -i -E '/^make\[[0-9]/d' README.md
  backlink
  dprint fmt README.md CHANGELOG.md
}

main() {
  doc-readme
  index
  dprint fmt README.md CHANGELOG.md
}

main
