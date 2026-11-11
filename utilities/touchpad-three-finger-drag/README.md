# touchpad-three-finger-drag

libinput with a patch for snappier three-finger drag on the Surface touchpad:

- no 80 ms wait to tell a drag from a swipe at the start
- fingers spread apart don't turn the drag into a pinch
- lifting mid-touchpad drops at once; lifting within 5 mm of an edge holds
  the drag 300 ms so you can reposition (stock: 700 ms always)

| File | Role |
|---|---|
| `pkg/libinput/PKGBUILD` | Arch's libinput PKGBUILD, `pkgrel=1.2`, applying the patch |
| `pkg/libinput/0001-sp10-3fg-drag.patch` | the change |

`install.sh` builds and installs it. Hyprland loads libinput once, so it takes
effect at the next login. A newer libinput from Arch replaces it (its pkgrel is
only above the current release); rebuild after such an update.
