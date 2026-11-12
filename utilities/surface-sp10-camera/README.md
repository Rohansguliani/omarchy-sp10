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

## Building and publishing the packages

`camera/kernel/` rebuilds the kernel exactly: Arch Linux `v7.0.5-arch1`, plus
`0001-sp10-camera.patch` (the camera work) and `0002-sp10-local-followups.patch`
(the IMX681 driver and routing changes). Both patches were checked to reproduce
the original build tree byte for byte. `camera/libcamera/` is Arch's libcamera
0.7.2 package plus the IMX681 sensor helper patch.

The built packages are too big for git. To save the next install an hour,
upload them as a release after each rebuild:

```bash
gh release create camera-7.0.5-sp10 --title "SP10 camera packages" \
  linux-surface-sp10-{,headers-}7.0.5.arch1-3-x86_64.pkg.tar.zst \
  {libcamera,libcamera-ipa,libcamera-tools,gst-plugin-libcamera}-0.7.2-5-x86_64.pkg.tar.zst
```
