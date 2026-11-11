# spotlight-search

Tuning for the Spotlight plugin (Ctrl+Space). The plugin itself is pinned in
`plugins.txt`, with local edits in `patches/io.github.maajix.spotlight.patch`.

| File | Role |
|---|---|
| `home/.config/omarchy/spotlight.json` | Spotlight settings (reduced motion, etc.) |
| `home/.config/fd/ignore` | keeps file search out of source checkouts and tool caches in `~` |
| `home/.config/hypr/utilities/spotlight-search.lua` | no Hyprland animation on its layer |

The Ctrl+Space binding stays in `~/.config/hypr/bindings.lua`, inside the block
Spotlight's setup tour manages.
