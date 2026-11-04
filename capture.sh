#!/usr/bin/env bash
# Copy this machine's live config back into the repo, then show what changed.
# Run it after you tweak anything, review `git diff`, and commit.
#
# It only refreshes files the repo already tracks. To start tracking a new
# file, copy it under home/ (or system/) once by hand, e.g.
#   install -D ~/.config/foo/bar.conf ~/omarchy-sp10/home/.config/foo/bar.conf
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

sync_tree() {
  local tree=$1 root=$2 src live
  while IFS= read -r -d '' src; do
    live=$root/${src#"$REPO/$tree/"}
    if [[ ! -e $live ]]; then
      echo "gone from this machine: $live (delete $src if intended)"
    elif ! cmp -s "$live" "$src"; then
      cp -p -- "$live" "$src"
    fi
  done < <(find "$REPO/$tree" -type f -print0)
}

sync_tree home "$HOME"
sync_tree system ""

# Repin third-party plugins to their current commits and re-export local edits.
plugins=$REPO/plugins.txt
tmp=$(mktemp)
while IFS= read -r line; do
  read -r id url _ <<<"$line"
  dir=~/.config/omarchy/plugins/$id
  if [[ -z $id || $id == \#* || ! -d $dir/.git ]]; then
    echo "$line"
    continue
  fi
  echo "$id $url $(git -C "$dir" rev-parse HEAD)"
  patch=$REPO/patches/$id.patch
  if [[ -n $(git -C "$dir" status --porcelain) ]]; then
    git -C "$dir" -c diff.mnemonicPrefix=false diff --src-prefix=a/ --dst-prefix=b/ >"$patch"
  else
    rm -f -- "$patch"
  fi
done <"$plugins" >"$tmp"
mv -- "$tmp" "$plugins"

git -C "$REPO" status --short
