# surface-sp10-camera

**Surface Pro 10 for Business only.** Both built-in cameras (rear OV13858,
front IMX681) through a custom kernel and a patched libcamera. Never install
this on other hardware: it replaces the boot kernel and pins libcamera.

| File | Role |
|---|---|
| `camera/kernel/` | `linux-surface-sp10` PKGBUILD: Arch 7.0.5 + SP10 camera patches |
| `camera/libcamera/` | patched libcamera PKGBUILD (IMX681 helper) |
| `setup.sh` | pins libcamera (`IgnorePkg`), installs both packages (GitHub release `camera-7.0.5-sp10`, or builds them, about an hour), makes the camera kernel the boot default |
| `home/.config/omarchy/hooks/pre-refresh-pacman.d/surface-sp10-keep-libcamera` | re-adds the pin when Omarchy rewrites `pacman.conf` (channel switch) |
| `home/.config/wireplumber/wireplumber.conf.d/51-surface-ipu6-camera.conf` | hides the raw IPU6 nodes that gave apps a black screen |
| `packages.txt` | PipeWire libcamera plugin, Snapshot |

Check: `cam -l` lists the internal back and front cameras. Details:
`machines/sp10/docs/CAMERA.md`.
