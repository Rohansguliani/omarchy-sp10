# displaylink

Drivers for DisplayLink docks and adapters (USB video, vendor `17e9`), such as
the HP USB-C/A Universal Dock G2. Their video outputs need these two AUR
packages; the dock's USB, audio and Ethernet work without them.

| Piece | Role |
|---|---|
| `evdi-dkms` | kernel module that creates the virtual display; DKMS builds it for every installed kernel with headers |
| `displaylink` | Synaptics' closed driver service that streams the image to the dock |
| `enable.txt` | starts `displaylink.service` |

Each kernel you boot needs its headers package (e.g. `linux-surface-sp10-headers`)
or DKMS can't build the module for it. The monitor appears as `DVI-I-1`;
arrange it in the Displays page like any other.
