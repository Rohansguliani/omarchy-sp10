#!/usr/bin/env bash
# One-command setup of a fresh Omarchy install, for one of the machines in
# machines/ (each lists the utilities it gets).
#
#   gh repo clone Rohansguliani/omarchy-sp10 ~/omarchy-sp10 && ~/omarchy-sp10/install.sh <machine>
#
# After the first run the machine name is remembered, so `install.sh` alone
# works. Safe to rerun: every step checks the current state first, and files
# that would be replaced are backed up. Flags:
#   --dry-run       print what would change, change nothing
#   --skip-camera   leave the kernel and libcamera alone (surface-sp10-camera)
#   --only a,b      install just these utilities (no base, no machine folder)
#   --force         also replace live files edited after the repo copy
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DRY=0
SKIP_CAMERA=0
FORCE=0
ONLY=
NAME=
while (($#)); do
  case $1 in
    --dry-run) DRY=1 ;;
    --skip-camera) SKIP_CAMERA=1 ;;
    --force) FORCE=1 ;;
    --only) ONLY=${2:?--only needs utility names}; shift ;;
    --only=*) ONLY=${1#--only=} ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) NAME=$1 ;;
  esac
  shift
done

# shellcheck source=lib/machine.sh
source "$REPO/lib/machine.sh"
if [[ -n $ONLY ]]; then
  resolve_only "$ONLY"
else
  resolve_machine "$NAME"
fi

BACKUP=~/.local/state/omarchy-setup/backup-$(date +%Y%m%d-%H%M%S)
REBOOT=0
SKIPPED=0

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }
run() {
  if ((DRY)); then printf '    + %s\n' "$*"; else "$@"; fi
}

[[ $EUID -ne 0 ]] || { echo "Run as your user, not root." >&2; exit 1; }
command -v omarchy >/dev/null || { echo "Install Omarchy first (https://omarchy.org)." >&2; exit 1; }
printf 'Machine: %s\n' "${MACHINE:-(only: $ONLY)}"
for part in "${PARTS[@]}"; do [[ $part == "$REPO" ]] && echo "  base" || echo "  ${part#"$REPO/"}"; done

if ((!DRY)); then
  # -n first: with a NOPASSWD rule, `sudo -v` would still ask (verifypw).
  sudo -n true 2>/dev/null || sudo -v
  while sleep 50; do sudo -n true; done 2>/dev/null &
  KEEPALIVE=$!
  # `|| true`: set -e applies inside traps too, and the loop may already be gone.
  trap 'kill "$KEEPALIVE" 2>/dev/null || true' EXIT
fi

# Copy one file into place unless it is already identical. Existing different
# files go to $BACKUP first. $1 = source, $2 = target, $3 = "sudo" or empty.
place() {
  local src=$1 dst=$2 sudo=${3:-} mode
  mode=$(stat -c %a "$src")
  if [[ -f $dst ]] && cmp -s "$src" "$dst"; then return; fi
  # A live file edited after the repo copy holds work capture.sh hasn't saved.
  if [[ -e $dst ]] && ((!FORCE)) && [[ $dst -nt $src ]]; then
    note "skip $dst: edited after the repo copy (run capture.sh, or --force)"
    SKIPPED=1
    return
  fi
  if [[ -e $dst ]]; then
    note "update $dst (old copy in $BACKUP)"
    run $sudo install -D -m 600 "$dst" "$BACKUP$dst"
  else
    note "add $dst"
  fi
  run $sudo install -D -m "$mode" "$src" "$dst"
}

# Each part (repo root, a utility, the machine folder) has its own home/
# (copied into ~) and system/ (copied into /).
step "Config files in ~"
for part in "${PARTS[@]}"; do
  [[ -d $part/home ]] || continue
  while IFS= read -r -d '' src; do
    place "$src" "$HOME/${src#"$part/home/"}"
  done < <(find "$part/home" -type f -print0)
done

# Utilities' Hyprland files load through a small loader in hyprland.lua. The
# base hyprland.lua has it; with --only on a stock config, append it.
has_hypr_utilities() {
  local part
  for part in "${PARTS[@]}"; do
    compgen -G "$part/home/.config/hypr/utilities/*.lua" >/dev/null && return 0
  done
  return 1
}
if has_hypr_utilities && ! grep -q '/.config/hypr/utilities/' ~/.config/hypr/hyprland.lua 2>/dev/null; then
  note "append the utility loader to ~/.config/hypr/hyprland.lua"
  ((DRY)) || cat "$REPO/lib/hypr-utilities-loader.lua" >>~/.config/hypr/hyprland.lua
fi

step "System files in /etc"
SYSTEM_CHANGED=0
BOOT_CHANGED=0
for part in "${PARTS[@]}"; do
  [[ -d $part/system ]] || continue
  while IFS= read -r -d '' src; do
    dst=/${src#"$part/system/"}
    if ! cmp -s "$src" "$dst" 2>/dev/null; then
      SYSTEM_CHANGED=1
      # Kernel command line and initramfs inputs need new boot images.
      [[ $dst == /etc/limine-entry-tool.d/* || $dst == /etc/default/limine* || $dst == /etc/mkinitcpio* || $dst == /etc/modprobe.d/* ]] && BOOT_CHANGED=1
    fi
    place "$src" "$dst" sudo
  done < <(find "$part/system" -type f -print0)
done
if ((SYSTEM_CHANGED)); then
  run sudo systemctl daemon-reload
  run sudo udevadm control --reload
  run sudo udevadm trigger --action=change
fi
((BOOT_CHANGED)) && REBOOT=1
# Each part's enable.txt: "system <unit>" or "user <unit>" per line.
run systemctl --user daemon-reload
while read -r scope unit; do
  [[ -z ${scope:-} || $scope == \#* ]] && continue
  if [[ $scope == user ]]; then
    systemctl --user is-enabled -q "$unit" 2>/dev/null || run systemctl --user enable --now "$unit"
  else
    systemctl is-enabled -q "$unit" 2>/dev/null || run sudo systemctl enable --now "$unit"
  fi
done < <(for part in "${PARTS[@]}"; do cat "$part/enable.txt" 2>/dev/null || true; done)

step "Omarchy channel: rc"
if [[ -n $ONLY ]]; then
  note "skipped (--only)"
elif [[ $(omarchy-channel-current 2>/dev/null) == rc ]]; then
  note "already on rc"
else
  run omarchy-channel-set rc
fi

step "Packages"
mapfile -t PACKAGES < <(for part in "${PARTS[@]}"; do cat "$part/packages.txt" 2>/dev/null || true; done | grep -vE '^\s*(#|$)')
mapfile -t MISSING < <(for p in "${PACKAGES[@]}"; do pacman -Q "$p" &>/dev/null || echo "$p"; done)
if ((${#MISSING[@]})); then
  run yay -S --needed --noconfirm "${MISSING[@]}"
else
  note "all installed"
fi

step "Locally patched packages (pkg/*/PKGBUILD)"
for pkgdir in $(for part in "${PARTS[@]}"; do compgen -G "$part/pkg/*/" || true; done); do
  [[ -f $pkgdir/PKGBUILD ]] || continue
  info=$(cd "$pkgdir" && makepkg --printsrcinfo)
  name=$(awk -F' = ' '/^pkgname/{print $2; exit}' <<<"$info")
  want=$(awk -F' = ' '/^\tepoch/{e=$2":"} /^\tpkgver/{v=$2} /^\tpkgrel/{r=$2} END{print e v "-" r}' <<<"$info")
  if [[ $(pacman -Q "$name" 2>/dev/null | cut -d' ' -f2) == "$want" ]]; then
    note "$name $want already installed"
  else
    (cd "$pkgdir" && run makepkg -si --noconfirm --needed)
  fi
done

# A part's setup.sh does what plain files can't (the SP10 camera kernel).
# Sourced here, so it can use run, note, DRY and REBOOT; $DIR is its folder.
for part in "${PARTS[@]}"; do
  [[ -f $part/setup.sh ]] || continue
  step "Setup: ${part#"$REPO/"}"
  DIR=$part
  # shellcheck source=/dev/null
  source "$part/setup.sh"
done
if ((BOOT_CHANGED)) && command -v limine-update >/dev/null; then
  run sudo limine-update
fi

step "Shell plugins"
PLUGINS=~/.config/omarchy/plugins
# Third-party plugins: each part's plugins.txt ("<id> <git url> <commit>").
while read -r id url commit; do
  [[ -z $id || $id == \#* ]] && continue
  dir=$PLUGINS/$id
  if [[ ! -d $dir/.git ]]; then
    run omarchy plugin add "$url" --yes
  fi
  if ((!DRY)) && [[ $(git -C "$dir" rev-parse HEAD) != "$commit" ]]; then
    git -C "$dir" stash -q 2>/dev/null || true
    git -C "$dir" fetch -q origin
    git -C "$dir" checkout -q "$commit"
  fi
  patch=$REPO/patches/$id.patch
  if [[ -f $patch ]]; then
    if git -C "$dir" apply -R --check "$patch" 2>/dev/null; then
      note "$id: local patch already applied"
    else
      run git -C "$dir" apply "$patch"
    fi
  fi
done < <(for part in "${PARTS[@]}"; do cat "$part/plugins.txt" 2>/dev/null || true; done)
# Make sure every plugin a part ships or pins is enabled, so a utility
# installed on its own (--only) works without the base shell.json. Bar widgets
# count as enabled once placed in the bar, which `omarchy plugin list` reports.
enabled=$(omarchy plugin list --json 2>/dev/null | jq -r '(if type == "array" then . else .plugins end)[] | select(.enabled) | .id' 2>/dev/null || true)
for part in "${PARTS[@]}"; do
  {
    if [[ -d $part/home/.config/omarchy/plugins ]]; then
      find "$part/home/.config/omarchy/plugins" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
    fi
    if [[ -f $part/plugins.txt ]]; then
      awk '!/^[[:space:]]*(#|$)/{print $1}' "$part/plugins.txt"
    fi
  } | while read -r id; do
    grep -qxF "$id" <<<"$enabled" || run omarchy plugin enable "$id"
  done
done

step "Desktop settings"
if [[ -n $ONLY ]]; then
  note "skipped (--only)"
else
if [[ $(omarchy theme current 2>/dev/null) != "Obsidian Black" ]]; then
  run omarchy theme set obsidian-black
fi
if [[ $(gsettings get org.gnome.desktop.wm.preferences button-layout) != "':minimize,maximize,close'" ]]; then
  run gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
fi
if [[ $(omarchy-hyprland-workspace-layout-default 2>/dev/null) != floating ]]; then
  run omarchy-hyprland-workspace-layout-default floating
fi
fi

step "Reload the desktop"
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  run hyprctl reload
  if ! run omarchy restart shell; then
    note "shell not restarted (locked?): run 'omarchy restart shell' after unlocking"
  fi
else
  note "not in a Hyprland session; changes apply at next login"
fi

if ((!DRY)) && [[ -n $MACHINE ]]; then
  mkdir -p "$(dirname "$MACHINE_FILE")"
  echo "$MACHINE" >"$MACHINE_FILE"
fi

step "Done"
((DRY)) && note "dry run: nothing was changed"
[[ -d $BACKUP ]] && note "replaced files were backed up to $BACKUP"
((REBOOT)) && note "reboot to load new kernels, boot options and system services: omarchy system reboot"
((SKIPPED)) && note "some live files were newer than the repo and were left alone (see 'skip' lines)"
exit 0
