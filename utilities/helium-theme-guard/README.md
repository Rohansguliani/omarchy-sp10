# helium-theme-guard

Omarchy writes `/etc/chromium/policies/managed/color.json` on theme changes and
browser installs. Helium reads that folder, and a color policy overrides its own
black theme (gray toolbar and tabs). A path unit deletes the file the moment it
appears. Side effect: Chromium also stops following the Omarchy theme color.

| File | Role |
|---|---|
| `system/etc/systemd/system/helium-no-color-policy.path` | watches for the file |
| `system/etc/systemd/system/helium-no-color-policy.service` | removes it |

If Helium is already open when the file appears, it picks the theme back up on
the next `helium-browser --refresh-platform-policy --no-startup-window` or restart.
