# Diagnosed Incidents and Unfinished Work

Last reviewed: 2026-11-03.

This file records important diagnoses and distinguishes active fixes from ideas that were never implemented.

## Omarchy lock stranded during plugin reload

Observed failure: `omarchy-shell shell rescanPlugins` ran while the session was locked. Omarchy destroyed the `omarchy.lock` service that owned Hyprland’s active Wayland session lock. Hyprland correctly failed closed and displayed its emergency lock screen.

**Fixed upstream in Omarchy 4.0.6.** The lock plugin manifest now sets `"keepLoaded": true`, and `unloadPluginServices()` in `/usr/share/omarchy/shell/shell.qml` keeps `keepLoaded` services alive across reloads. On 2026-11-03 the local hotfix hook reported it no longer applied, the upstream code was verified, and the hook and script were moved to `/root/mux-removed-2026-11-03/`. No local shell patch is installed now.

Upstream references:

- Issue: https://github.com/omacom/omarchy/issues/7106
- Existing fix: https://github.com/omacom/omarchy/pull/9485
- Local reproduction comment: https://github.com/omacom/omarchy/pull/9485#issuecomment-5503850820

Never restart or replace the shell while it reports a pending/active lock.

If Hyprland displays its fail-closed emergency screen again, use the exact recovery command shown on that screen from an authenticated TTY rather than assuming the machine crashed.

## Low-battery warning startup race

Observed failure: Omarchy briefly showed a 10% battery warning while current UPower and sysfs readings were 100%. Omarchy Shell sampled stale UPower state during startup before UPower completed initialization.

No local code patch is documented as installed. Evidence was added upstream:

- Issue: https://github.com/omacom/omarchy/issues/7679
- Proposed fix at the time: https://github.com/omacom/omarchy/pull/8284
- Local reproduction comment: https://github.com/omacom/omarchy/issues/7679#issuecomment-5527866809

If it recurs, verify current values with both `upower` and `/sys/class/power_supply` before treating the notification as accurate.

## Surface suspend and lid behavior

The Surface exposes only `s2idle`. Manual suspend previously woke after a few seconds with ACPI errors. Active mitigations are:

```text
/etc/limine-entry-tool.d/surface-pro-10.conf
/etc/systemd/system-sleep/surface-power-button-only-wake
/etc/systemd/system/surface-buttons.service
/etc/systemd/logind.conf.d/lid-policy.conf
~/.local/bin/omarchy-lid-power-policy
```

The kernel command line currently includes `i915.enable_psr2_sel_fetch=0`; the wake hook keeps only the physical power-button GPIO armed during sleep; `surface-buttons.service` is enabled and active.

Related linux-surface report: https://github.com/linux-surface/linux-surface/issues/2158

## Boot cleanup was not completed

A firmware/kernel cleanup was prepared in `cleanup-boot-entries.sh`, but the current machine still has all three kernel packages and the old EFI records. The script’s hard-coded kernel version and EFI assumptions are obsolete, so it is intentionally disabled.

Current policy is conservative: Limine boots first, the custom SP10 camera kernel is active, and stock kernels remain available as fallbacks. Any future cleanup requires a fresh `efibootmgr`, `/boot/limine.conf`, package, and UKI audit.

## TPM automatic disk unlock was not implemented

Unattended reboot was discussed, but TPM2 auto-unlock and Secure Boot migration were not performed. The encrypted root filesystem still requires unlocking before normal networking, Mux, and user services can start. Do not assume remote access will return after an unattended reboot.

## Mux file explorer investigation

A past investigation found HTTP 400 responses for file rename/delete while direct reads and listings worked. This was diagnosed as a likely client/runtime payload mismatch, not a filesystem failure. No durable system customization from that investigation is recorded here.
