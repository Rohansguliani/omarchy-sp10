# surface-smart-charging

**Surface only** (tested on Surface Pro 10 for Business). Keeps the battery
charging to 100% instead of stopping at ~80%.

Surface firmware "Smart Charging" holds the battery at ~80% once the device has
been plugged in for long stretches (Microsoft: support.microsoft.com, "Smart
charging on Surface"). On Windows the Surface app pauses it; Linux has no
switch. `surface-smart-charging` sends the same pause request to the embedded
controller through `/dev/surface/aggregator`, using the commands found by
linux-surface contributors (linux-surface discussion #986). The firmware
re-enables it on its own, so a timer re-checks every 30 minutes and pauses it
only when it is active.

Evidence on this machine: plugged in for 2.5 days at 79%, "not charging", 0 W;
EC status `c0 00`. After the pause: `00 00`, charging at ~22 W.

- `system/usr/local/bin/surface-smart-charging` — `status`, `pause`, or no
  argument (pause only if active). Run as root.
- `surface-smart-charging.timer` — 1 min after boot, then every 30 min.
- `modules-load.d` — loads `surface_aggregator_cdev` at boot.

It never touches the UEFI Battery Limit (50%) mode; if that is on, it says so
and does nothing. To go back to Smart Charging: `sudo systemctl disable --now
surface-smart-charging.timer` (the firmware turns it back on by itself).
