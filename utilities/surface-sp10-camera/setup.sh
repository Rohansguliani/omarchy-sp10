# Sourced by install.sh after packages are installed. Uses its DRY, run, note,
# REBOOT and SKIP_CAMERA; $DIR is this utility's folder.

CAMERA_RELEASE=camera-7.0.5-sp10
CAMERA_SRC=$DIR/camera
CAMERA_DIST=$CAMERA_SRC/dist

# Routine Arch updates would otherwise replace the patched libcamera.
if grep -q '^IgnorePkg.*libcamera' /etc/pacman.conf; then
  note "patched libcamera already pinned (IgnorePkg)"
else
  run bash "$DIR/home/.config/omarchy/hooks/pre-refresh-pacman.d/surface-sp10-keep-libcamera"
fi

install_camera() {
  if pacman -Q linux-surface-sp10 &>/dev/null && [[ $(pacman -Q libcamera | awk '{print $2}') == 0.7.2-5 ]]; then
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
    (cd "$CAMERA_SRC/libcamera" && run makepkg -si --needed --noconfirm)
    (cd "$CAMERA_SRC/kernel" && run makepkg -s --noconfirm --skippgpcheck &&
      run sudo pacman -U --needed --noconfirm ./linux-surface-sp10-*.pkg.tar.zst)
  fi
  REBOOT=1
}

if ((SKIP_CAMERA)); then
  note "camera kernel skipped (--skip-camera)"
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
