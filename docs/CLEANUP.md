# Cleanup History

## Removed

The cleanup removed old or unwanted software and data, including:

- OpenClaw services, timers, scripts, logs, configuration, and runtime data.
- OpenCode services, package, daemon, configuration, caches, database, and notes.
- Non-Mux zrok services, shares, binary, and state.
- Spotify package and user data.
- Omarchy Chromium package and Chromium profile/cache; Helium was kept.
- Cursor and Signal packages and user data.
- Ruby and its Tobi/RubyGems dependents, .NET runtimes, OpenJDK, and Deno. Removing Deno also removed `yt-dlp-ejs` and `yt-dlp` because they formed a required dependency chain.
- Both unpacked balenaEtcher copies and its user configuration.
- The Pacman package cache was emptied.
- Typora and its user configuration.
- The standalone Tree-sitter CLI; Neovim's required Tree-sitter runtime and parsers were preserved.
- QEMU user-mode emulation and binfmt integration.
- Old Omarchy Quattro upgrade backups, legacy desktop configuration backups, and residual OpenCode application data.
- npm and Bun package-manager caches; installed Mise runtimes, Neovim data, Mux data, keyrings, launchers, and Nautilus state were preserved.
- Telegram binary/data, launchers, icons, and installer archive.
- Helium browser profile, settings, extensions, and cache were reset; the Helium package remains installed.
- Old Linux ISO downloads and disposable installers.
- Google OAuth client-secret files from Downloads and their editor swap files.
- Agentify runtime data.
- Large Bun, AUR, browser, and package-build caches that were clearly stale.
- Old top-level user Git repositories explicitly selected for deletion.
- Unused Music and Pictures directories at the time; screenshot tools may recreate Pictures when saving captures.
- Tailscale package, `tailscaled`, and the Omarchy Taildrop receiver; Mux-owned zrok was not affected.

## Preserved intentionally

- Helium browser package. Its profile was reset during cleanup; later launches may have recreated normal profile data.
- Omarchy package-owned files and defaults (no local patches since 2026-11-03).
- Mux runtime, tunnel, identity, services, and Mux-owned zrok.
- SSH and PKI directories.
- Application configuration that was not clearly disposable.
- All three currently installed kernels: custom `linux-surface-sp10`, regular `linux-surface`, and stock `linux`. They now serve as the active camera kernel plus fallbacks.
- Camera build trees under `~/surface-pro-10-camera-kernel/` and `~/libcamera-sp10/`.

## Boot cleanup status

Firmware/kernel cleanup was investigated but not completed. Limine is first in firmware boot order, while legacy `Omarchy`, `cachyos`, `Windows Boot Manager`, and `MsTemp` records still exist. The old `cleanup-boot-entries.sh` is deliberately disabled because its hard-coded assumptions predate the custom camera kernel.

## Security notes

Old OpenClaw/OpenCode services had plaintext secrets in unit files and public-tunnel configuration. Those units and application data were removed. Do not copy old service files or secrets back into the system.

Never put credentials into this directory. Use protected environment files or the application’s supported secret storage.
