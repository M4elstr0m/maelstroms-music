# 0009 Stereo safe positioning

Status: Accepted. Builds on [0003](0003-radio-and-tv-sound-positioning.md), which stays the default behaviour.

## Context

With true 3D positions (ADR 0003) a radio was silent dead ahead and behind the listener and weak beyond 80 degrees on the maintainer's Linux machine, while left and right worked. The cause is not the positioning, it is the audio output:

- The game's native layer calls `FMOD_System_SetSoftwareFormat(rate 32000, speaker mode 5.1, 0)` and never selects an output type, so FMOD auto detects the output. On a PipeWire or PulseAudio stereo device that is the PulseAudio output (output type 8), whose driver reports a stereo speaker mode.
- Measured end to end (the game's `libfmod.so`, a real PulseAudio output, the sink monitor recorded): on that output only the **front left and front right** speakers of the 5.1 mix reach the ears. The centre and both surround speakers are dropped instead of being folded down. The ALSA output (type 9 in the lab, PulseAudio is 8) folds down correctly, so the effect is specific to the output path.
- A mono 3D source goes to the centre speaker at 0 degrees, to front right from about 30 to 80 degrees and to the surround right beyond, and the front speakers are not adjacent in the 5.1 panner, so no single 3D point can produce a centred image. Audible azimuths therefore are about 15 to 80 degrees on each side only (`tools/fmod-lab/stage_probe.py`).

This affects every 3D sound of the game on such setups, not only this mod. Lua cannot reach `javafmod` (only `FMODSoundEmitter`, `FMODAudio` and a few wrappers are exposed), so the output mode cannot be changed from the mod.

## Decision

An opt-in setting, **Stereo safe positioning** (default off, so setups that fold down correctly keep the engine behaviour), plays each radio and TV through a pair of emitters:

- A left and a right emitter sit 40 degrees to each side of the listener (front right peaks at 30 degrees, 40 is within 0.3 dB of the peak and keeps clear of the surround). Their volumes follow an equal power pan law from the lateral bearing of the real device in the listener frame, so total power is constant from hard left to hard right and a centred image exists (`tools/fmod-lab/pair_probe.py`: constant -16.0 dB total, -19 dB per ear at the centre).
- The wall muffling is kept by **placing each emitter on a square that gets the same engine occlusion as the real square**. The engine computes the occlusion only from the square under the emitter position (`FileSound.tick`; only a window or door parent changes the room test), the rule is reproduced in `Playback/Occlusion.lua`, and `Stage.place` searches around the stage angle and the real distance (radius offsets 0, 1, -1 ... 6, -6 tiles, angle offsets up to 24 degrees, a previous candidate tried first so the placement does not hop) for a square with a muffling within 0.02 of the real one. Turning around therefore never removes the muffle, because the muffle follows the real square and not the bearing.
- When no square is within 0.25 of the target the device falls back to the real position at equal power (0.707 on both copies), correct muffling with the engine's own blind zones. The distance falloff is kept: the virtual radius is clamped to at least 2.2 tiles and the volume is compensated by the ratio of the engine's inverse roll-off at the real and the virtual distance (clamped to 0.5 to 1.2).
- Both copies start in the same call, because file sounds cannot seek and a copy started later would comb filter against the first. Changing the option restarts the playing track once. A held radio or one inside the player's own vehicle stays a flat 2D sound and keeps the second copy silent. A staged vehicle never uses the vehicle's own emitter, whose position the engine owns.
- Listener frame setting: **Screen** uses the engine's fixed listener vector (-1, -1), **Player** uses the character's forward direction, **Automatic** picks Player when the Viewpoint global exists. Viewpoint's listener forward comes from the Java static `Look.yaw`, which Lua cannot read, so the character's facing (`getForwardDirection`, which Viewpoint patches through `Patch_LookAngle`) is used as the closest equivalent. If the pan is mirrored or lags under Viewpoint, that is the place to look.

## Rejected alternatives

- A flat 2D fill emitter in the blind zones. It cannot carry the muffle (the low pass exists only in the 3D path), which makes a radio audible through a wall only when you turn a certain way.
- Replacing the real position by one virtual position. Same coupling, plus no centred image.
- A Java companion (ZombieBuddy) that changes the speaker mode. Possible, but a second Workshop item with a Java dependency, not needed once Lua can solve it.
- Forcing an ALSA output or a 5.1 sink on the player's machine. Not controllable from the mod, and not available to other players.

## Consequences

The stage costs two emitters per positioned device and about three occlusion evaluations per update in the common case (the real square and one square per side), more only while a search runs. Front and back are not distinguished (a radio behind sounds centred, with the engine's muffling). Under Viewpoint the pan reflects the character's facing, which lags the camera slightly. The tuning knobs are in `Stage.lua` (`STAGE_ANGLE`, `MATCH_TOLERANCE`, `ACCEPTABLE_MISMATCH`, the candidate offsets).

## Verification

Offline: `lua5.1 tools/lua-tests/occlusion_test.lua`, `stage_test.lua`, `playback_test.lua`, and `tools/fmod-lab/{stage_probe,pair_probe}.py`. In game: turn the camera around a placed radio (left, centre, right, behind), stand in another room, in a car, with and without Viewpoint, and toggle the option while a station plays.
