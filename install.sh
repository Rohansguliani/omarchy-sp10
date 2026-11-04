#!/usr/bin/env bash
# One-command setup of a fresh Omarchy install on a Surface Pro 10 for Business.
#
#   gh repo clone Rohansguliani/omarchy-sp10 ~/omarchy-sp10 && ~/omarchy-sp10/install.sh
#
# Safe to rerun: every step checks the current state first, and files that
# would be replaced are backed up. Flags:
#   --dry-run       print what would change, change nothing
#   --skip-camera   leave the kernel and libcamera alone
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DRY=0
SKIP_CAMERA=0
for arg in "$@"; do
  case $arg in
    --dry-run) DRY=1 ;;
    --skip-camera) SKIP_CAMERA=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

BACKUP=~/.local/state/omarchy-sp10/backup-$(date +%Y%m%d-%H%M%S)
CAMERA_RELEASE=camera-7.0.5-sp10
CAMERA_DIST=$REPO/camera/dist
REBOOT=0

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }
run() {
  if ((DRY)); then printf '    + %s\n' "$*"; else "$@"; fi
}

[[ $EUID -ne 0 ]] || { echo "Run as your user, not root." >&2; exit 1; }
command -v omarchy >/dev/null || { echo "Install Omarchy first (https://omarchy.org)." >&2; exit 1; }

if ((!DRY)); then
  sudo -v
  while sleep 50; do sudo -n true; done 2>/dev/null &
  trap 'kill $! 2>/dev/null' EXIT
fi

# Copy one file into place unless it is already identical. Existing different
# files go to $BACKUP first. $1 = source, $2 = target, $3 = "sudo" or empty.
place() {
  local src=$1 dst=$2 sudo=${3:-} mode
  mode=$(stat -c %a "$src")
  if [[ -f $dst ]] && cmp -s "$src" "$dst"; then return; fi
  if [[ -e $dst ]]; then
    note "update $dst (old copy in $BACKUP)"
    run $sudo install -D -m 600 "$dst" "$BACKUP$dst"
  else
    note "add $dst"
  fi
  run $sudo install -D -m "$mode" "$src" "$dst"
}

step "Config files in ~"
while IFS= read -r -d '' src; do
  place "$src" "$HOME/${src#"$REPO/home/"}"
done < <(find "$REPO/home" -type f -print0)

step "System files in /etc"
SYSTEM_CHANGED=0
while IFS= read -r -d '' src; do
  dst=/${src#"$REPO/system/"}
  cmp -s "$src" "$dst" 2>/dev/null || SYSTEM_CHANGED=1
  place "$src" "$dst" sudo
done < <(find "$REPO/system" -type f -print0)
if ((SYSTEM_CHANGED)); then
  run sudo systemctl daemon-reload
  REBOOT=1
fi
for unit in surface-sp10-pl4.service surface-buttons.service; do
  systemctl is-enabled -q "$unit" 2>/dev/null || run sudo systemctl enable "$unit"
done

step "Pin patched libcamera (IgnorePkg)"
if grep -q '^IgnorePkg.*libcamera' /etc/pacman.conf; then
  note "already pinned"
else
  run bash "$REPO/home/.config/omarchy/hooks/pre-refresh-pacman.d/surface-sp10-keep-libcamera"
fi

step "Omarchy channel: rc"
if [[ $(omarchy-channel-current 2>/dev/null) == rc ]]; then
  note "already on rc"
else
  run omarchy-channel-set rc
fi

step "Packages"
mapfile -t PACKAGES < <(grep -vE '^\s*(#|$)' "$REPO/packages.txt")
mapfile -t MISSING < <(for p in "${PACKAGES[@]}"; do pacman -Q "$p" &>/dev/null || echo "$p"; done)
if ((${#MISSING[@]})); then
  run yay -S --needed --noconfirm "${MISSING[@]}"
else
  note "all installed"
fi

install_camera() {
  local want_kernel=linux-surface-sp10 want_lib=libcamera
  if pacman -Q "$want_kernel" &>/dev/null && [[ $(pacman -Q "$want_lib" | awk '{print $2}') == 0.7.2-5 ]]; then
    note "camera kernel and patched libcamera already installed"
    return
  fi

  # Fast path: prebuilt packages from the repo's GitHub release.
  if ! compgen -G "$CAMERA_DIST/*.pkg.tar.zst" >/dev/null; then
    run mkdir -p "$CAMERA_DIST"
    if ((!DRY)) && (cd "$REPO" && gh release download "$CAMERA_RELEASE" \
        --dir "$CAMERA_DIST" --pattern '*.pkg.tar.zst') 2>/dev/null; then
      note "downloaded prebuilt packages from release $CAMERA_RELEASE"
    fi
  fi

  if compgen -G "$CAMERA_DIST/*.pkg.tar.zst" >/dev/null; then
    run sudo pacman -U --needed --noconfirm "$CAMERA_DIST"/*.pkg.tar.zst
  else
    # Slow path: build from the pinned sources (about an hour for the kernel).
    note "no prebuilt packages; building from source"
    (cd "$REPO/camera/libcamera" && run makepkg -si --needed --noconfirm)
    (cd "$REPO/camera/kernel" && run makepkg -s --noconfirm --skippgpcheck &&
      run sudo pacman -U --needed --noconfirm ./linux-surface-sp10-*.pkg.tar.zst)
  fi
  REBOOT=1
}

step "Camera stack (custom kernel + patched libcamera)"
if ((SKIP_CAMERA)); then
  note "skipped (--skip-camera)"
else
  install_camera
  if grep -q '^default_entry: Omarchy/linux-surface-sp10$' /boot/limine.conf 2>/dev/null; then
    note "camera kernel is the boot default"
  elif sudo grep -q '^default_entry:' /boot/limine.conf; then
    run sudo sed -i 's|^default_entry:.*|default_entry: Omarchy/linux-surface-sp10|' /boot/limine.conf
  else
    run sudo sed -i '/^timeout:/a default_entry: Omarchy/linux-surface-sp10' /boot/limine.conf
  fi
fi
if ((SYSTEM_CHANGED)); then
  run sudo limine-update
fi

step "Shell plugins"
PLUGINS=~/.config/omarchy/plugins
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
done < "$REPO/plugins.txt"

step "Desktop settings"
if [[ $(omarchy theme current 2>/dev/null) != "Obsidian Black" ]]; then
  run omarchy theme set obsidian-black
fi
# Omarchy's browser color policy overrides Helium's black theme.
if [[ -e /etc/chromium/policies/managed/color.json ]]; then
  run sudo rm -f /etc/chromium/policies/managed/color.json
fi
if [[ $(gsettings get org.gnome.desktop.wm.preferences button-layout) != "':minimize,maximize,close'" ]]; then
  run gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
fi
if [[ $(omarchy-hyprland-workspace-layout-default 2>/dev/null) != floating ]]; then
  run omarchy-hyprland-workspace-layout-default floating
fi

step "Reload the desktop"
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  run hyprctl reload
  run omarchy restart shell
else
  note "not in a Hyprland session; changes apply at next login"
fi

step "Done"
((DRY)) && note "dry run: nothing was changed"
[[ -d $BACKUP ]] && note "replaced files were backed up to $BACKUP"
((REBOOT)) && note "reboot to load the kernel, boot options and power-limit service: omarchy system reboot"
exit 0
