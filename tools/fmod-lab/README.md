# FMOD lab

Small offline probes that drive the game's own FMOD build (`natives/libfmod.so`) through `ctypes`, render a test signal with the WAV writer output, and measure the level of each ear. They exist so audio claims about the engine can be checked instead of assumed. The probes use the same init flags as the game (`0x20300`, see `docs/ENGINE_NOTES.md`).

```bash
PZ_NATIVES=<game dir>/natives python3 pan_probe.py --listener camera
PZ_NATIVES=<game dir>/natives python3 occlusion_probe.py
```

Requirements: Python 3 with `numpy`. Nothing is written inside the repository.

| File | Purpose |
| ---- | ------- |
| `fmodlab.py` | Library: loads FMOD, renders a signal, returns the stereo output, level helpers |
| `pan_probe.py` | Level of each ear while the listener turns, for a fixed radio. `--listener vanilla` uses the fixed screen up listener, `camera` uses the first person style yaw and pitch |
| `occlusion_probe.py` | Effect of the occlusion factors the engine uses on each frequency band |

Extending: call `fmodlab.render` with a `channel_setup` callback to apply any `FMOD_Channel_*` call (minimum and maximum distance, 3D level, spread, occlusion) to the channel before it starts.
