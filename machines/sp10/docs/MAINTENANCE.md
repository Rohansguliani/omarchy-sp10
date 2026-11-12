# Maintenance and Recovery

Last reviewed: 2026-11-03.

## Before any update

This machine has one package-sensitive local modification: a custom `linux-surface-sp10` kernel and patched libcamera packages for both built-in cameras. libcamera is pinned with `IgnorePkg` in `/etc/pacman.conf`. (The old lock-service hotfix was retired after Omarchy 4.0.6 fixed it upstream.)

Read [`CAMERA.md`](CAMERA.md) and [`INCIDENTS.md`](INCIDENTS.md) before updating kernels, libcamera, PipeWire/WirePlumber, or Omarchy Shell.

Record the working state first:

```bash
uname -r
omarchy version
pacman -Q linux-surface-sp10 linux-surface linux libcamera libcamera-ipa libcamera-tools pipewire-libcamera
cam -l
systemctl --user is-active muxrun-runtime.service muxrun-tunnel.service newmux-machine.service
```

## Update Omarchy

Use Omarchy’s updater instead of treating the system as plain Arch.

`libinput` is a local build (`1.32.0-1.2`, patch `~/libinput-sp10/pkg/0001-sp10-3fg-drag.patch`) and is deliberately **not** pinned, so security updates still arrive. When Arch ships a newer libinput, three-finger drag reverts to stock behavior. To reapply: in `~/libinput-sp10/pkg`, `git pull`, re-add the patch to `source`/`b2sums`/`prepare()` and bump `pkgrel` to `.2`, then `makepkg -Cf --nocheck` and `sudo pacman -U libinput-*-x86_64.pkg.tar.zst` (not the `-tools`/`-debug` packages). Log out and back in afterwards.

`omarchy-channel-set` and `omarchy refresh pacman` overwrite `/etc/pacman.conf` and run `pacman -Syyuu`, which would downgrade the patched libcamera. `~/.config/omarchy/hooks/pre-refresh-pacman.d/surface-sp10-keep-libcamera` re-adds the `IgnorePkg` line before that runs. If libcamera is ever replaced anyway, reinstall from `~/libcamera-sp10/*-0.7.2-5-*.pkg.tar.zst`.

Update:

```bash
omarchy update
```

The updater handles Omarchy packages, Arch packages, migrations, AUR packages, and snapshots. Run it from a visible terminal so sudo can prompt normally. `omarchy update -y` still stops at `gum` prompts (remove orphans, reboot), so a detached run looks stuck when it's waiting on those.

Watch specifically for replacement of:

```text
linux-surface-sp10
libcamera
libcamera-ipa
libcamera-tools
```

The local camera packages use ordinary package names/versions and can be replaced by repository updates. If that occurs, rebuild/reinstall from the documented source trees before expecting both cameras to work.


After a kernel or major Omarchy update completes, reboot only when someone can unlock the LUKS root volume locally:

```bash
omarchy system reboot
```

TPM auto-unlock was not configured. Mux and networking cannot start until encrypted root is unlocked.

Check versions and pending packages:

```bash
omarchy version
uname -r
Hyprland --version
pacman -Qu
```

## Post-update verification

```bash
uname -r
cat /proc/cmdline
powerprofilesctl get
systemctl is-active power-profiles-daemon.service surface-buttons.service
systemctl --user is-active muxrun-runtime.service muxrun-tunnel.service newmux-machine.service
cam -l
```

Expected highlights:

- Active kernel is the custom `surface-sp10` kernel when built-in cameras are needed.
- Kernel command line contains `i915.enable_psr2_sel_fetch=0`.
- Power profile is `performance` unless deliberately changed.
- All three Mux services are active.
- `cam -l` lists internal back and front cameras.

Warnings about missing `ov13858.yaml` and `imx681.yaml` tuning files are currently known. Missing cameras are not.

## Validate Hyprland edits

Hyprland normally reloads when its Lua configuration changes. Validate from a GUI terminal:

```bash
luac -p ~/.config/hypr/input.lua
luac -p ~/.config/hypr/bindings.lua
luac -p ~/.config/hypr/looknfeel.lua
luac -p ~/.config/hypr/monitors.lua
hyprctl reload
hyprctl configerrors
```

An empty `hyprctl configerrors` result is healthy.

## Custom bar changes

After every edit to `rohansguliani.bar`, validate it and fully restart Omarchy Shell. A plugin rescan alone can leave the old bar instance alive:

```bash
OMARCHY_PATH=/usr/share/omarchy omarchy plugin validate ~/.config/omarchy/plugins/rohansguliani.bar
OMARCHY_PATH=/usr/share/omarchy omarchy restart shell
OMARCHY_PATH=/usr/share/omarchy omarchy-shell shell ping
```

Only do this while the graphical session is unlocked. See `INCIDENTS.md` for the lock-service failure history.

## Reset configuration safely

Always get confirmation before resetting configuration. Prefer Omarchy’s commands because they make timestamped backups:

```bash
omarchy refresh hyprland
omarchy refresh shell
omarchy refresh config hypr/input.lua
```

A refresh can overwrite or disconnect active customizations. Before refreshing, preserve or review:

```text
~/.config/hypr/input.lua
~/.config/hypr/bindings.lua
~/.config/hypr/looknfeel.lua
~/.config/hypr/monitors.lua
~/.config/omarchy/shell.json
~/.config/omarchy/plugins/rohansguliani.bar/
~/.config/omarchy/plugins/local.helium-desktop/
~/.config/wireplumber/wireplumber.conf.d/51-surface-ipu6-camera.conf
```

Do not manually delete `/usr/share/omarchy/`. The installed shell is package-owned, with one documented local hotfix maintained by a root-owned pacman hook.

## Theme troubleshooting

Read:

```text
~/.agents/skills/omarchy/theming.md
```

Useful commands:

```bash
omarchy theme current
omarchy theme list
omarchy theme set obsidian-black
omarchy theme refresh
```

If Helium’s frame still uses its old color after a theme change, fully quit and reopen it. Omarchy’s generated Chromium-family color policy can recreate the generic “managed by your organization” banner. The previously observed policy contained cosmetic color settings, but always inspect `helium://policy` rather than assuming.

## Camera recovery

If Camera/Snapshot is black or lists many raw IPU6 devices:

```bash
uname -r
cam -l
cat ~/.config/wireplumber/wireplumber.conf.d/51-surface-ipu6-camera.conf
systemctl --user restart wireplumber pipewire pipewire-pulse
```

Then fully quit and reopen Snapshot. Do not remove the WirePlumber rule merely to expose raw nodes; those nodes caused the black-screen failure.

## Boot maintenance

The old `cleanup-boot-entries.sh` is disabled and historical. It contains entry IDs from a previous state. Before removing any kernel or EFI record, freshly inspect:

```bash
uname -r
pacman -Q linux-surface-sp10 linux-surface linux
efibootmgr
cat /boot/limine.conf
ls -l /boot/EFI/Linux/
```

Keep at least one independently bootable fallback when changing the custom camera kernel. Do not infer that an old firmware label means its current target is safe to delete.

## Power and sleep

Omarchy's idle settings (`idle` in `~/.config/omarchy/shell.json`) only lock the screen after 5 minutes and turn the display off; they never suspend. On 2026-11-04 a reboot (`omarchy-system reboot` at 02:35) left the machine at the LUKS password prompt all day, where nothing saves power, and the battery went from 100% to 12%.

`~/.config/systemd/user/omarchy-idle-power-policy.service` (script `~/.local/bin/omarchy-idle-power-policy`, utility `idle-power-policy`) sets Omarchy's idle lock timeout by power source: 1 hour plugged in, 5 minutes on battery. On battery it also suspends after 10 minutes locked; plugged in it never suspends. The power button (`~/.local/bin/omarchy-power-button`) locks and turns the displays off; pressed while locked, it turns them back on. Omarchy's power menu moved to Super+Escape only. None of this can help at the LUKS prompt, which runs before any user service. Lid behavior is separate: see `omarchy-lid-power-policy` in `CUSTOMIZATIONS.md`.

## Diagnostics

Use Omarchy’s safe noninteractive report:

```bash
omarchy debug --no-sudo --print
```
