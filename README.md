# omarchy-sp10

My Omarchy setup, for every machine I run it on. A fresh Omarchy install plus
one command gives a machine the shared desktop (window tools, Mission Control,
Alt+Tab, Displays page, screenshots, bar, theme) and only the hardware fixes
that machine needs. (The repo name is historical; it started on the Surface.)

## Layout

| Path | What | Who gets it |
|---|---|---|
| `home/`, `packages.txt`, `plugins.txt`, `patches/` | shared config, apps, shell plugins | every machine |
| `utilities/<name>/` | one self-contained feature (README, `home/`, `system/`, optional `packages.txt`, `enable.txt`, `pkg/*/PKGBUILD`, `setup.sh`) | machines that list it |
| `machines/<name>/` | `utilities.txt` (which utilities), `packages.txt` (drivers, firmware), `home/` (its `monitors.lua`, `input.lua`), `docs/` | that machine |
| `lib/machine.sh` | works out the machine and its parts, for both scripts | |

Machines: `sp10` (Surface Pro 10 for Business). Setting up a new one: see
[`AGENTS.md`](AGENTS.md).

## New machine

1. Install Omarchy from the ISO (https://omarchy.org). Use the same username,
   `rohansguliani`.
2. Run, with the machine's name:

   ```bash
   gh auth login && gh repo clone Rohansguliani/omarchy-sp10 ~/omarchy-sp10 && ~/omarchy-sp10/install.sh sp10
   ```

   A machine without a folder in `machines/` needs one first (`AGENTS.md`).
3. Reboot when it says so, and unlock the disk.

`install.sh` remembers the machine (`~/.local/state/omarchy-setup/machine`), so
later runs need no name. It is safe to rerun; any file it replaces is backed up
to `~/.local/state/omarchy-setup/backup-<time>/`. A live file edited after the
repo copy is left alone (run `capture.sh` first, or pass `--force`). Add
`--dry-run` to see what it would do, or `--skip-camera` to leave the SP10
camera kernel alone.

One utility on its own, on any fresh Omarchy (no machine folder, no shared
config):

```bash
~/omarchy-sp10/install.sh --only shot
~/omarchy-sp10/install.sh --only window-tools,settings --dry-run
```

That installs the utility's files, packages, services, plugins (and enables
them) and its `setup.sh`, and adds the Hyprland utility loader to
`hyprland.lua` if it's missing. The channel, theme and other shared settings
are skipped.

It applies the parts in order: shared, each listed utility, then the machine.

| Step | What |
|---|---|
| Config files | each part's `home/` into `~` |
| System files | each part's `system/` into `/`, then the services in each `enable.txt` |
| Channel | Omarchy `rc` channel |
| Packages | every part's `packages.txt` (repo and AUR) |
| Patched packages | builds each part's `pkg/*/PKGBUILD` that isn't installed at that version |
| Setup | each part's `setup.sh` (the SP10 camera kernel) |
| Plugins | each part's `plugins.txt` at its pinned commit, plus `patches/`; every plugin a part ships or pins is enabled |
| Settings | Obsidian Black theme, Helium window buttons, floating windows by default |

Not covered: Mux (installs itself), 1Password and browser sign-ins, the LUKS
password, Wi-Fi.

## Utilities

Hyprland settings for a utility go in `home/.config/hypr/utilities/<name>.lua`,
which `hyprland.lua` loads one by one (a broken one shows a notification; the
rest still load). A utility that isn't installed simply has no file there.

| Utility | What | Needs |
|---|---|---|
| `window-tools` | desktops, maximize/snap, Alt+Tab, Mission Control | any |
| `settings` | Settings window: Wi-Fi, Bluetooth, Sound, Displays, Devices (per-mouse/keyboard speed, scrolling, Alt/Super swap), Battery, About | any |
| `shot` | Alt+1 screenshot, Alt+2 OCR, Alt+` editor | any |
| `spotlight-search` | Spotlight settings, file-search ignores | any |
| `bluetooth-audio-switch` | sound moves to Bluetooth headphones/speakers when they connect | any |
| `helium-theme-guard` | keeps Omarchy's color policy from graying Helium | any |
| `lean-services` | masks Omarchy's crash watcher, CUPS only on demand | any |
| `lid-power-policy` | lid close: sleep, clamshell, or panel off on power | laptop |
| `battery-idle-suspend` | sleep after 10 min locked on battery | laptop |
| `touchpad-three-finger-drag` | patched libinput | touchpad |
| `logitech-mx-master` | gesture button → Mission Control, thumb wheel → desktops | that mouse, Unifying receiver |
| `displaylink` | drivers for DisplayLink docks (HP USB-C/A Universal Dock G2) | that dock |
| `kef-lsx-speaker` | keeps the KEF LSX II LT's USB stream from suspending | that speaker |
| `surface-sp10-hardware` | boot options (PSR off), button wake fixes | Surface Pro 10 only |
| `surface-sp10-camera` | custom kernel + patched libcamera for both cameras | Surface Pro 10 only |
| `surface-gpu-power-limit` | PL4 45 → 64 W so the iGPU isn't clock-clamped | Surface Pro 10 only |
| `surface-smart-charging` | Keeps Surface Smart Charging paused so the battery charges to 100% | Surface only |

## Keeping it up to date

After changing anything on a machine:

```bash
~/omarchy-sp10/capture.sh     # copies this machine's live files into the repo, repins plugins
cd ~/omarchy-sp10 && git diff && git commit -am "..." && git push
```

`capture.sh` refreshes files the repo already tracks, for this machine's parts
only. To track a new file, copy it once into the part it belongs to.

## SP10 camera packages

Building the kernel takes about an hour, so the built packages go in a GitHub
release (they are too big for git). Upload them once after each rebuild:

```bash
cd ~/omarchy-sp10 && gh release create camera-7.0.5-sp10 --title "SP10 camera packages" \
  ~/surface-pro-10-camera-kernel/pkg/arch/kernel-sp10/linux-surface-sp10-{,headers-}7.0.5.arch1-3-x86_64.pkg.tar.zst \
  ~/libcamera-sp10/{libcamera,libcamera-ipa,libcamera-tools,gst-plugin-libcamera}-0.7.2-5-x86_64.pkg.tar.zst
```

`utilities/surface-sp10-camera/camera/kernel/` rebuilds the running kernel
exactly: Arch Linux `v7.0.5-arch1`, plus `0001-sp10-camera.patch` (the committed
camera work) and `0002-sp10-local-followups.patch` (the IMX681 driver and
routing changes that were uncommitted in the original build tree). Both patches
were checked to reproduce that tree byte for byte. A rebuild is `pkgrel=4` and
its version string no longer ends in `-dirty`. `camera/libcamera/` is Arch's
libcamera 0.7.2 package plus the IMX681 sensor helper patch.

## Notes

`machines/sp10/docs/` holds the Surface's detailed notes (system state, camera,
customizations, shortcuts, maintenance). `~/omarchySetup` links to it.
