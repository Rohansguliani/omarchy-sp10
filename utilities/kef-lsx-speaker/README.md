# kef-lsx-speaker

For the KEF LSX II LT on USB. Its USB firmware stops answering once the host
stops the stream after idle (`usb_set_interface -110` in the kernel log), and
only unplugging it recovers. This WirePlumber rule never suspends that one
output, so the stream stays open.

| File | Role |
|---|---|
| `home/.config/wireplumber/wireplumber.conf.d/kef-lsx-no-suspend.conf` | `session.suspend-timeout-seconds = 0` for `alsa_output.usb-KEF_LSX_II_LT.*` |

Needs: the KEF LSX II LT over USB. Applies after
`systemctl --user restart wireplumber` or the next login.
