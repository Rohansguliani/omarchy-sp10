#!/usr/bin/env bash
# Copy this machine's live config back into the repo, then show what changed.
# Run it after you tweak anything, review `git diff`, and commit.
#
# Only the parts this machine uses are refreshed (base, the utilities in
# machines/<machine>/utilities.txt, and machines/<machine>/), and only files
# the repo already tracks. To track a new file, copy it once by hand into the
# part it belongs to: machines/<machine>/home/ for this machine only,
# utilities/<name>/home/ for one utility, home/ for every machine, e.g.
#   install -D ~/.config/foo/bar.conf ~/omarchy-sp10/home/.config/foo/bar.conf
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/machine.sh
source "$REPO/lib/machine.sh"
resolve_machine "${1:-}"

sync_tree() {
  local tree=$1 root=$2 src live
  [[ -d $tree ]] || return 0
  while IFS= read -r -d '' src; do
    live=$root/${src#"$tree/"}
    if [[ ! -e $live ]]; then
      echo "gone from this machine: $live (delete $src if intended)"
    elif ! cmp -s "$live" "$src"; then
      cp -p -- "$live" "$src"
    fi
  done < <(find "$tree" -type f -print0)
}

for part in "${PARTS[@]}"; do
  sync_tree "$part/home" "$HOME"
  sync_tree "$part/system" ""
done

# Repin third-party plugins to their current commits and re-export local edits,
# in every plugins.txt of the parts this machine uses.
for part in "${PARTS[@]}"; do
  plugins=$part/plugins.txt
  [[ -f $plugins ]] || continue
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
  chmod 644 "$tmp" # mktemp makes it 600
  mv -- "$tmp" "$plugins"
done

git -C "$REPO" status --short
