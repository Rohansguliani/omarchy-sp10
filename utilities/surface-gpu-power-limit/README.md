# surface-gpu-power-limit

The Surface Pro 10 firmware sets PL4 to 45 W, below its own 64 W PL2, which
clamps the iGPU to 200-800 MHz (linux-surface#2331). This oneshot raises PL4 to
64 W at boot and after every resume. Undo: `sudo systemctl disable surface-sp10-pl4`.

| File | Role |
|---|---|
| `system/etc/systemd/system/surface-sp10-pl4.service` | writes `intel-rapl:0/constraint_2_power_limit_uw` |
