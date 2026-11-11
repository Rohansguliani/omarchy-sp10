# Setting up a machine (for AI agents)

You are on one of Rohan's machines, running Omarchy, and asked to set it up
from this repo. Read `README.md` first. The shared part is the same everywhere;
your job is the part that depends on this hardware.

## Ground rules

- **Never copy another machine's hardware parts.** `surface-sp10-*` and
  `surface-gpu-power-limit` replace the kernel, pin libcamera, or write CPU
  power limits. On any machine other than a Surface Pro 10 for Business they
  are wrong and can be harmful.
- Leave GPU drivers to Omarchy's own installer (NVIDIA, AMD, Intel). Only add
  driver packages it demonstrably missed, with the evidence in a comment.
- Don't edit `/usr/share/omarchy/`. Config goes in `~/.config`, through this repo.
- Dry-run before every real run, and show the user what will change.
- Ask before anything that needs a reboot or touches boot entries, kernels or
  disk encryption.
- Don't commit or push unless the user asks.

## New machine

1. Inspect the hardware, read-only:

   ```bash
   cat /sys/class/dmi/id/{sys_vendor,product_name}
   lspci -nn | grep -Ei 'vga|3d|display'
   ls /sys/class/power_supply/        # BAT* = laptop
   hyprctl monitors all
   hyprctl devices                     # touchpads, mice, keyboards
   ```

2. Create `machines/<name>/` (short name, e.g. `gaming-pc`):
   - `utilities.txt`: start from the "any" rows of the utility table in
     `README.md`. Add the laptop rows only with a battery and lid, the
     touchpad one only with a touchpad, the peripheral ones only if that
     device is used here. Hardware-specific utilities: none unless you write
     one for this machine (below).
   - `packages.txt`: this machine's hardware packages only (often empty).
   - `README.md`: model, GPU, displays, anything unusual.

3. Run `~/omarchy-sp10/install.sh <name> --dry-run`, review, then without
   `--dry-run`. It records the machine name for later runs.

4. Tune per-machine settings live (Displays page for monitors; touchpad and
   mouse speed in `~/.config/hypr/input.lua`), then track them for this machine:

   ```bash
   install -D ~/.config/hypr/monitors.lua ~/omarchy-sp10/machines/<name>/home/.config/hypr/monitors.lua
   install -D ~/.config/hypr/input.lua    ~/omarchy-sp10/machines/<name>/home/.config/hypr/input.lua
   ```

   After that, `capture.sh` keeps them current.

## A hardware fix for one machine

Make it its own utility, `utilities/<model>-<what>/`, like
`surface-gpu-power-limit`: a README saying which hardware it is for and why
(with evidence: logs, measurements, an upstream issue), its files under
`home/` and `system/`, and optional `packages.txt`, `enable.txt`
(`system <unit>` / `user <unit>` per line), `pkg/<name>/PKGBUILD`, or
`setup.sh` (sourced by `install.sh` with `run`, `note`, `DRY`, `REBOOT` and
`$DIR`; must be idempotent and respect `DRY`). List it only in that machine's
`utilities.txt`.

## A feature for every machine

Put it in `utilities/<name>/`, add it to the README table with its "Needs",
and list it in each machine that should get it.
