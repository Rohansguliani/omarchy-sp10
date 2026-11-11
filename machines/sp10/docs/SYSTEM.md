# Current System

Verified on 2026-11-03 (after full `omarchy update`).

| Component | Verified state |
|---|---|
| Machine | Microsoft Surface Pro 10 for Business |
| Base OS | Arch Linux, rolling release |
| Omarchy | `4.5.0rc3-1`, **rc channel** (switched 2026-11-03; pre-switch snapshot #10 = 4.0.6). Return with `omarchy-channel-set stable` once 4.5 ships. |
| Default workspace layout | `floating` (titlebars from `omarchy-hyprland-titlebars`, dock on floating workspaces). Change: `omarchy-hyprland-workspace-layout-default dwindle` or `Super+L` per workspace |
| Hyprland | `0.56.2-4` (aquamarine `0.15.1`) |
| Active kernel | `7.0.5-arch1-3-surface-sp10-00001-g9cda380da3c0-dirty` |
| Active kernel package | `linux-surface-sp10 7.0.5.arch1-3` |
| Other installed kernels | `linux-surface 7.2.14.arch1-1`; `linux 7.2.11.arch1-1` |
| Boot loader | Limine; current firmware entry is `Boot0007` |
| Display | Built-in `eDP-1`, 2880×1920 at 120 Hz, scale 2 (`GDK_SCALE=2`) |
| Theme | `Obsidian Black` |
| Power profile | `performance` |
| Root filesystem | LUKS-backed Btrfs subvolume `@`, `compress=zstd:3` |
| EFI system partition | FAT32 mounted at `/boot` |
| Swap | zram only; no persistent disk swap |

## Boot state

Limine currently exposes all three installed kernels. The custom `linux-surface-sp10` kernel is required for the experimental built-in camera support. The stock `linux` and regular `linux-surface` packages remain installed as fallback kernels.

The firmware still contains old entries named `Omarchy`, `cachyos`, `Windows Boot Manager`, and `MsTemp`. Limine is first in `BootOrder`, so these records are not currently selected. The old `cleanup-boot-entries.sh` was prepared for an earlier kernel/EFI state, was never completed, and is now intentionally disabled. Do not reuse its old entry IDs without a fresh boot audit.

## Surface-specific kernel state

The active command line includes:

```text
i915.enable_psr=0
i915.enable_psr2_sel_fetch=0
```

These are supplied by:

```text
/etc/limine-entry-tool.d/surface-pro-10.conf
```

`enable_psr2_sel_fetch=0` avoids the observed i915 PSR2 selective-fetch failure during Surface Pro 10 `s2idle`. `enable_psr=0` (added 2026-11-03) disables panel self-refresh entirely; PSR1 adds a frame of latency when the panel wakes, which shows up as laggy cursor and gestures. The machine exposes `s2idle`, not traditional deep S3 sleep.

## Performance fixes (2026-11-03)

| Fix | Where | Why |
|---|---|---|
| PL4 raised 45 W → 64 W | `/etc/systemd/system/surface-sp10-pl4.service` (runs at boot and after resume) | Firmware sets peak power (PL4) below PL2, which clamps the iGPU to ~200–800 MHz while it requests 2000 MHz. Causes dropped frames and UI lag. See https://github.com/linux-surface/linux-surface/issues/2331. 64 W equals the firmware's own PL2. |
| VA-API video decode | `intel-media-driver libvpl vpl-gpu-rt` | Omarchy's installer regex misses `Meteor Lake-P [Intel Graphics]`, so these were never installed and all browser video was CPU-decoded. Check with `vainfo`. |
| Helium flags | `~/.config/helium-browser-flags.conf` | Helium ignores `chromium-flags.conf`. This file enables Wayland, touchpad swipe-back, and VA-API decode. |
| Removed `omarchy-max-gpu-performance.service` | moved to `/root/mux-removed-2026-11-03/` | It had an ordering cycle and never ran; pinning GPU min freq to max only adds heat. |

Check GPU clamp: `d=/sys/class/drm/card1/gt/gt0; cat $d/throttle_reason_pl4 $d/rps_cur_freq_mhz $d/rps_act_freq_mhz`.

`/etc/pacman.conf` has `IgnorePkg = libcamera libcamera-ipa libcamera-tools` so repo updates cannot replace the patched camera userspace. Remove it only when an upstream libcamera includes the IMX681 helper.

## Mux — preserve these

These user services were verified enabled and active:

```text
muxrun-runtime.service
muxrun-tunnel.service
newmux-machine.service
```

Important Mux paths:

```text
~/.mux
~/.muxrun
~/.mux/bin/zrok
~/.config/systemd/user/muxrun-runtime.service
~/.config/systemd/user/muxrun-tunnel.service
~/.config/systemd/user/newmux-machine.service
```

`.muxrun` hosts the main runtime and supervisor, while the current setup still uses `newmux-machine`, zrok, and state from `.mux`. Preserve both directories. Mux uses its own zrok binary and state; do not confuse it with the removed standalone zrok setup.

Check Mux without changing it:

```bash
systemctl --user is-enabled muxrun-runtime.service muxrun-tunnel.service newmux-machine.service
systemctl --user is-active muxrun-runtime.service muxrun-tunnel.service newmux-machine.service
ps -eo pid,args | grep -E 'mux-runtime|mux-supervisor|newmux-machine|\.mux/bin/zrok' | grep -v grep
```
