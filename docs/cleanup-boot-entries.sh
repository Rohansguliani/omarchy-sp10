#!/usr/bin/env bash
set -euo pipefail

# Historical only. This was prepared for the pre-camera-kernel boot layout and
# was never completed. Kernel packages, Limine entries, and firmware state have
# changed since then; reusing the hard-coded entry IDs could damage boot access.
echo "Refusing to run: this historical boot-cleanup script is obsolete. Read SYSTEM.md and INCIDENTS.md." >&2
exit 1

expected_esp_partuuid="64191194-a7a7-4b9c-831d-8def0a1c1c37"
expected_surface_kernel="6.19.8-arch1-3-surface"

if [[ $EUID -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

if [[ $(findmnt -nro PARTUUID /boot) != "$expected_esp_partuuid" ]]; then
  echo "Refusing to continue: /boot is not the expected EFI system partition." >&2
  exit 1
fi

if [[ $(uname -r) != "$expected_surface_kernel" ]]; then
  echo "Refusing to continue: the running kernel is not $expected_surface_kernel." >&2
  exit 1
fi

if ! pacman -Q linux-surface >/dev/null; then
  echo "Refusing to continue: linux-surface is not installed." >&2
  exit 1
fi

entry_line() {
  efibootmgr | grep -E "^Boot$1\\*? " || true
}

assert_entry() {
  local id=$1 label=$2
  if [[ $(entry_line "$id") != *"$label"* ]]; then
    echo "Refusing to continue: Boot$id is not the expected '$label' entry." >&2
    exit 1
  fi
}

assert_entry 0007 Limine
assert_entry 0006 Omarchy
assert_entry 0005 cachyos
assert_entry 0004 "Windows Boot Manager"
assert_entry 0003 MsTemp

# Make the working Limine loader primary before removing any obsolete entry.
efibootmgr -o 0007,0001,0000,0002

# Remove the generic Arch kernel. The Limine package hooks remove its generated
# UKI and menu entry while retaining linux-surface.
if pacman -Q linux >/dev/null 2>&1; then
  pacman -R --noconfirm linux
fi

if pacman -Q linux >/dev/null 2>&1; then
  echo "Generic linux package is still installed." >&2
  exit 1
fi
if [[ -e /boot/EFI/Linux/omarchy_linux.efi ]]; then
  echo "Generic kernel UKI was not removed; stopping before NVRAM cleanup." >&2
  exit 1
fi
if [[ ! -e /boot/EFI/Linux/omarchy_linux-surface.efi ]]; then
  echo "Surface kernel UKI is missing; stopping before NVRAM cleanup." >&2
  exit 1
fi
if grep -qE '^[[:space:]]*//linux$' /boot/limine.conf; then
  echo "Generic kernel remains in /boot/limine.conf; stopping before NVRAM cleanup." >&2
  exit 1
fi
if ! grep -qE '^[[:space:]]*//linux-surface$' /boot/limine.conf; then
  echo "Surface kernel is missing from /boot/limine.conf." >&2
  exit 1
fi

# Remove obsolete direct-generic, old CachyOS, old Windows, and installer entries.
for id in 0006 0005 0004 0003; do
  efibootmgr -b "$id" -B
done

efibootmgr -o 0007,0001,0000,0002

echo
echo "Cleanup complete. Remaining firmware entries:"
efibootmgr
echo
echo "Installed kernels:"
pacman -Q linux-surface
ls -1 /usr/lib/modules
