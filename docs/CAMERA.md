# Surface Pro 10 Camera Stack

Verified on 2026-09-11. This is experimental, model-specific support and is not part of the stock Omarchy camera setup.

## Current state

Both built-in cameras are detected by libcamera:

```text
1: Internal back camera (OV13858)
2: Internal front camera (IMX681)
```

Installed components:

```text
linux-surface-sp10 7.0.5.arch1-3
libcamera 0.7.2-5
libcamera-ipa 0.7.2-5
libcamera-tools 0.7.2-5
pipewire-libcamera 1:1.6.8-1
snapshot 50.0-1
```

GNOME Snapshot appears as **Camera** in the launcher and starts with:

```bash
snapshot
```

Use libcamera/PipeWire-aware applications. `guvcview` and direct raw V4L2 capture nodes are not appropriate for this IPU6 pipeline.

## Custom kernel

Active kernel:

```text
7.0.5-arch1-3-surface-sp10-00001-g9cda380da3c0-dirty
```

Build tree:

```text
~/surface-pro-10-camera-kernel/pkg/arch/kernel-sp10/
```

The `linux-surface-sp10` PKGBUILD starts from Arch Linux 7.0.5 and applies `0001-sp10-camera.patch`, plus manually ported/follow-up changes in the source tree. The work includes:

- Surface Pro 10 INT3472 GPIO type `0x08` handling.
- Rear OmniVision OV13858 sensor configuration and IPU6 routing.
- Front Sony IMX681 sensor driver and routing.
- Front-camera Bayer order/orientation corrections.

The regular `linux-surface` and stock `linux` kernels remain installed as fallbacks, but they do not provide this complete camera setup.

Upstream references used during the work:

- https://github.com/linux-surface/linux-surface/issues/2153
- https://github.com/linux-surface/linux-surface/pull/2156
- https://github.com/djmulder/linux-surface/tree/feature/surface-pro-10-cameras
- https://gist.github.com/djmulder/2ce4980d8fc438bf72201d361f4a55e4

## Patched libcamera

Build tree:

```text
~/libcamera-sp10/
```

The PKGBUILD applies:

```text
libcamera-imx681-helper.patch
```

The installed custom packages currently share version `0.7.2-5`. A routine Arch upgrade may replace them with repository builds that lack the local IMX681 work. Check `cam -l` after any libcamera upgrade.

## PipeWire/WirePlumber routing

Raw IPU6 V4L2 nodes caused Snapshot to select unusable devices and show a black screen. This user rule disables those raw PCI capture nodes for desktop applications:

```text
~/.config/wireplumber/wireplumber.conf.d/51-surface-ipu6-camera.conf
```

Processed front and rear libcamera cameras remain exposed through PipeWire. If applications again show dozens of IPU6 nodes or a black screen, verify this rule and restart:

```bash
systemctl --user restart wireplumber pipewire pipewire-pulse
```

Then recheck:

```bash
cam -l
```

## Known limitations

The cameras are detected, but image processing is not fully calibrated. Current libcamera diagnostics report:

```text
Configuration file 'ov13858.yaml' not found
Configuration file 'imx681.yaml' not found
falling back to uncalibrated.yaml
```

Consequences can include imperfect color, exposure, orientation, or other image quality. Detection and routing are fixed; sensor-specific tuning remains unfinished.

The front camera is experimental and was reported around 16 FPS in the upstream work. The IR/Windows Hello camera is not documented as supported.

## Verification

```bash
uname -r
pacman -Q linux-surface-sp10 libcamera libcamera-ipa libcamera-tools pipewire-libcamera snapshot
cam -l
wpctl status
```

Success means the custom SP10 kernel is active and `cam -l` lists exactly the internal back and front cameras. Warnings about missing tuning files are currently expected; no cameras or raw-only devices are not expected.
