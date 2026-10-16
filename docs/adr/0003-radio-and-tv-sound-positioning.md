# 0003 Radio and TV sound positioning

Status: Accepted. Supersedes the "softened virtual position" approach (PR 36), which is rejected below.

## Context

Players want radios and TVs to behave like vanilla ones: the sound moves from one ear to the other as the character or, under the Viewpoint first person mod, the camera turns, and a radio in another room is muffled ("mumble"). The history shows how the answer was found:

1. Flat scripts (`is3D = false`) with a mod computed falloff: a source anywhere off centre was entirely in one ear, standing on the radio was almost silent, Viewpoint was wrong.
2. Full 3D scripts with `distanceMin = 30` (a unit mistake, engine positions are in tiles): no attenuation within 30 tiles, loud everywhere.
3. Full 3D scripts with `distanceMin = 2`, `distanceMax = 75`: reported as working, one side of a radio sounded muffled (this was the engine's occlusion).
4. Flat scripts and a softened virtual position (`Spatial.lua`): uniform volume, but the head turn stereo and the muffling through walls were gone.
5. Back to 3. This record.

## Decision

Radio and TV tracks are generated as `is3D = true` scripts with `distanceMin = 2` and `distanceMax = 75` (tiles), and played at their **true position** so the engine's own handling applies. Everything else (backgrounds, main menu, game over music) stays `is3D = false` because a 3D sound that ticks without a player throws every frame.

A device has a mode, evaluated on every update, which sets the 2D or 3D state and the volume modifier:

| Mode | Sound | Modifier |
| ---- | ----- | -------- |
| `held` | 2D | 0.6 |
| `vehicleInside` (the player's own vehicle) | 2D | 0.8 |
| `vehicleOutside` | 3D on the vehicle's own emitter | 0.3 |
| `world` | 3D, positioned at the object | 0.4 |

The modifier used to be fixed when a track started, which left a car radio at the inside value after the player got out. The distance falloff in `Tick/Volume.lua` (dropoff range grows with the device volume, silent beyond 75 tiles) is kept on top of the engine's inverse roll-off.

## Evidence

Measured on the game's own FMOD 2.03 with `tools/fmod-lab`, and read from the bytecode (`FileSound.tick`, `FMODManager.init`, `SoundListener.tick`, `viewpoint.game.Hearing.listen`):

- A stereo file played as a 3D source is collapsed to mono at one point (default spread 0): +3 dB at the centre and +5.6 dB at a hard side compared with 2D for correlated stereo, which is why a car radio changed level when it switched between 2D and 3D. Pan is equal power and symmetric front to back, straight ahead or behind is 3 dB lower per ear than hard to one side. A centimetre to one side is already one ear only; the engine blends to 2D only within two tiles. Minimum distance never changes panning.
- The game initializes FMOD with core flags `0x20300` (`VOL0_BECOMES_VIRTUAL | CHANNEL_DISTANCEFILTER | CHANNEL_LOWPASS`). With `CHANNEL_LOWPASS`, `Set3DOcclusion` is a low pass filter: 0.24 to 0.33 removes the highs only, 0.79 muffles heavily, the engine's cap 0.9 leaves almost nothing. That is the vanilla mumble.
- For `is3D = true` scripts `FileSound.tick` computes the occlusion itself from the real square of the sound: none in the same room, 0.24 to 0.33 between rooms or buildings, 0.6 on another floor, 0.8 and 0.59 for a sound in a building heard from outside, plus 0.4 without line of sight. It also sets the 3D level, the distances and the reverb. None of it can be switched off from a script.
- The vanilla listener faces a fixed screen up direction. Viewpoint replaces it: player position (floor times three), zero velocity, forward and up from camera yaw and pitch, and `SoundLift` re-places every 3D file channel in the same frame. A sound at its true position therefore pans like a normal first person game in both cases (offline reproduction: turning the camera moves the radio from one ear to the other).

## Rejected alternatives

- Softened virtual position (same distance, bearing leaning at most 27 degrees, centred within 6 tiles, flat script). Uniform and gentle, but the engine derives occlusion from the sound's real square, so the muffling through walls cannot survive a virtual position, and the head turn stereo is deliberately flattened.
- Centred 2D fallback under Viewpoint. Unnecessary: the listener pipeline is consistent with true positions.
- Forcing the music option to 0 or any other global state to shape the sound: persisted settings could be corrupted (see ADR 0005).

## Consequences

Direction dependent loudness is intentional: the centre is 3 dB lower than the sides, a radio behind a wall is dull, a radio without line of sight is dull and quieter. Panning is hard beyond two tiles, as for any vanilla 3D sound. If Viewpoint still shows a front and back dip, re-run `tools/fmod-lab/pan_probe.py --listener camera` first (FMOD alone produces only the 3 dB centre dip), then suspect the occlusion (`isCouldSee`) that Viewpoint's vision patches feed. The tuning knobs are `WORLD_DISTANCE_MIN` and `WORLD_DISTANCE_MAX` in `Manifest.lua` and the modifiers in `Device.lua`.
