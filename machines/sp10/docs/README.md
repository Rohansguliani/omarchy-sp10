# Omarchy Setup Notes

Last verified: 2026-11-03

These notes describe the current customized Omarchy installation on a Microsoft Surface Pro 10 for Business. They distinguish verified active configuration from historical work and unfinished plans.

## Read this first

1. [`SYSTEM.md`](SYSTEM.md) — current OS, kernels, storage, power profile, and Mux state.
2. [`CAMERA.md`](CAMERA.md) — experimental Surface Pro 10 camera kernel, libcamera stack, application setup, and known limitations.
3. [`CUSTOMIZATIONS.md`](CUSTOMIZATIONS.md) — active display, input, shell, shortcut, power, and theme changes.
4. [`SHORTCUTS.md`](SHORTCUTS.md) — requested inputs and shortcuts with current completion status.
5. [`MAINTENANCE.md`](MAINTENANCE.md) — updates, validation, recovery, and custom-kernel precautions.
6. [`CLEANUP.md`](CLEANUP.md) — removed software, preserved data, and boot-cleanup history.
7. [`INCIDENTS.md`](INCIDENTS.md) — diagnosed bugs, upstream reports, local hotfixes, and work that was discussed but not implemented.

## Required Omarchy guidance

Before changing Omarchy, Hyprland, themes, screenshots, shell, or terminal configuration, read:

```text
~/.agents/skills/omarchy/SKILL.md
```

Then read the matching topic guide:

```text
~/.agents/skills/omarchy/hyprland.md
~/.agents/skills/omarchy/theming.md
~/.agents/skills/omarchy/capture.md
~/.agents/skills/omarchy/plugins.md
~/.agents/skills/omarchy/hooks.md
```

Important rules:

- Never edit `/usr/share/omarchy/` casually; it is package-owned and updates overwrite it.
- Put ordinary user changes in `~/.config/`.
- Put custom themes in `~/.config/omarchy/themes/<theme-name>/`.
- Prefer the stable `omarchy <group> <command>` CLI.
- Before resets, get confirmation and use `omarchy refresh ...`; it creates backups.
- Performance fixes specific to this machine (PL4 limit, PSR off, VA-API, Helium flags) are listed in `SYSTEM.md`.
- The active camera depends on a custom kernel and patched libcamera packages. Read `CAMERA.md` before kernel or camera-package changes.
- Never write passwords, tokens, OAuth secrets, LUKS recovery material, or Mux identity material into these notes.
