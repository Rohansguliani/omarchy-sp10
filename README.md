# omarchy-sp10

My Omarchy setup for a Microsoft Surface Pro 10 for Business. One command
turns a fresh Omarchy install into this machine.

## New machine

1. Install Omarchy from the ISO (https://omarchy.org). Use the same username,
   `rohansguliani`.
2. Run:

   ```bash
   gh auth login && gh repo clone Rohansguliani/omarchy-sp10 ~/omarchy-sp10 && ~/omarchy-sp10/install.sh
   ```

3. Reboot when it says so, and unlock the disk.

`install.sh` is safe to rerun. Any file it replaces is backed up to
`~/.local/state/omarchy-sp10/backup-<time>/`. Add `--dry-run` to see what it
would do, or `--skip-camera` to leave the kernel alone.

It does, in order:

| Step | What |
|---|---|
| Config files | copies `home/` into `~` (Hyprland, shell bar, theme, plugins, hooks, Helium flags, camera WirePlumber rule) |
| System files | copies `system/` into `/` (GPU power-limit service, PSR-off boot options, lid and wake policy), enables the services |
| Camera pin | adds `IgnorePkg` for the patched libcamera |
| Channel | switches Omarchy to the `rc` channel |
| Packages | installs everything in `packages.txt` (repo and AUR) |
| Camera | installs the custom kernel and patched libcamera, from the `camera-7.0.5-sp10` release if it exists, otherwise builds them (about an hour), and makes that kernel the boot default |
| Plugins | clones the plugins in `plugins.txt` at their pinned commits, applies `patches/` |
| Settings | Obsidian Black theme, removes Omarchy's Chromium color policy, Helium window buttons, floating windows by default |

Not covered: Mux (installs itself), 1Password and browser sign-ins, the LUKS
password, Wi-Fi.

## Keeping it up to date

After changing anything on this machine:

```bash
~/omarchy-sp10/capture.sh     # copies live files into the repo, repins plugins
cd ~/omarchy-sp10 && git diff && git commit -am "..." && git push
```

`capture.sh` refreshes files the repo already tracks. To track a new file,
copy it under `home/` (or `system/`) once.

## Prebuilt camera packages

Building the kernel takes about an hour, so the built packages go in a GitHub
release (they are too big for git). Upload them once after each rebuild:

```bash
cd ~/omarchy-sp10 && gh release create camera-7.0.5-sp10 --title "SP10 camera packages" \
  ~/surface-pro-10-camera-kernel/pkg/arch/kernel-sp10/linux-surface-sp10-{,headers-}7.0.5.arch1-3-x86_64.pkg.tar.zst \
  ~/libcamera-sp10/{libcamera,libcamera-ipa,libcamera-tools,gst-plugin-libcamera}-0.7.2-5-x86_64.pkg.tar.zst
```

## Camera sources

`camera/kernel/` rebuilds the running kernel exactly: Arch Linux `v7.0.5-arch1`,
plus `0001-sp10-camera.patch` (the committed camera work) and
`0002-sp10-local-followups.patch` (the IMX681 driver and routing changes that
were uncommitted in the original build tree). Both patches were checked to
reproduce that tree byte for byte. A rebuild is `pkgrel=4` and its version
string no longer ends in `-dirty`.

`camera/libcamera/` is Arch's libcamera 0.7.2 package plus the IMX681 sensor
helper patch.

## Notes

`docs/` holds the detailed notes (system state, camera, customizations,
shortcuts, maintenance). `~/omarchySetup` is a link to it.
