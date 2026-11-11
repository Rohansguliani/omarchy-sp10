# surface-sp10-hardware

**Surface Pro 10 for Business only.** Boot options and sleep fixes for this
model's Intel display and buttons.

| File | Role |
|---|---|
| `system/etc/limine-entry-tool.d/surface-pro-10.conf` | kernel options: `i915.enable_psr=0` (panel self-refresh added cursor and gesture lag) and `i915.enable_psr2_sel_fetch=0` (s2idle failures) |
| `system/etc/systemd/system/surface-buttons.service` | reloads the Surface button driver so the power button wakes it reliably |
| `system/etc/systemd/system-sleep/surface-power-button-only-wake` | only the power button can wake it from sleep |

The boot options take effect after `limine-update` and a reboot (`install.sh`
does both).
