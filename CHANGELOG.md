# Changelog

All notable changes to Maelstrom's Music are listed here, newest first. The Workshop change note, the GitHub release notes and the `Unreleased` section are generated or checked from this file (see `tools/workshop/README.md`).

## [Unreleased]

## [1.1.0] - 2026-10-15

### Added
- Stereo safe positioning (Options > Mods > Maelstrom's Music): keeps radios and TVs audible from every direction on audio setups that drop the centre and rear speakers of the game's surround mix, typically PulseAudio or PipeWire on Linux, and keeps the muffling through walls (#42)
- Compatibility with the Project Viewpoint first person mod: the sound follows the camera (#42)

### Changed
- Radios and TVs are heard at their real position: the sound moves from one ear to the other as you turn and is muffled through walls, as in the base game (#39)

### Fixed
- A car radio keeps the right level when you get out of the car (#36)
- Radio and TV distances are declared in tiles, so the volume falls off with distance again (#33)
- A moved radio or TV keeps its track instead of restarting it (#32)
- The base game's music is muted earlier while a game loads, which shortens the overlap with the main menu theme (#37)

## [1.0.8] - 2026-10-15

### Added
- Custom game over music: put tracks in a `deaths` folder, they play at the music volume (#16)
- A "Maelstrom's Music" page in the Mods options with a setting for the pause between background tracks (#15)
- A setting to hide the bundled example radio station (#14)

### Changed
- Radio and TV sounds use the engine's own 3D handling (#28)
- The options page is listed first in the Mods options (#26)

### Fixed
- A radio or TV that is picked up stops playing at once, and a moved device keeps its track (#12, #29)
- The character creation voice preview is no longer muted by the main menu theme (#13)
- Sounds that failed to register are detected and reported (#18)
- Warnings about modules that could not be required at startup (#25)
- The game over music plays at the music volume (#27)

## [1.0.7] - 2026-08-10

### Added
- Station ordering also works with `shuffle` enabled

## [1.0.6] - 2026-08-08

### Added
- Support for `.flac` files
