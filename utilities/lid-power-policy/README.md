# lid-power-policy

| Lid closed and… | Result |
|---|---|
| on battery, no monitor | sleeps (logind) |
| a monitor connected | stays awake, laptop panel off, everything on the monitor |
| on power, no monitor | stays awake and locked, panel off |

While the lid stays shut, `omarchy-lid-power-policy watch` keeps that true:
unplugging power suspends, and unplugging the monitor while on power turns the
panel back off.

| File | Role |
|---|---|
| `home/.local/bin/omarchy-lid-power-policy` | close / open / watch |
| `home/.config/hypr/utilities/lid-power-policy.lua` | binds the lid switch to it (also on the lock screen) |
| `system/etc/systemd/logind.conf.d/lid-policy.conf` | logind's half |

Test overrides are listed at the top of the script.
