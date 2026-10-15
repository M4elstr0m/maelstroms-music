# 0004 Device lifecycle: validity, muting and adoption

Status: Accepted

## Context

A playback entry (`Playback/Cache.lua`) keeps direct references to a device and its `DeviceData`. A TV that was picked up kept playing from its old position and logged errors. A radio that was picked up or placed restarted on another track, as if Tune In was pressed. The cause of the second problem is in the game's move code: `ISMoveableSpriteProps` calls `setDeviceData(deviceData)` with the **same object** on the new inventory item or world object.

## Decision

- `Device.isPresent` decides whether the device still exists: an object has a square (`getObjectIndex() ~= -1`), an item has a container or a world item, a vehicle part still has a vehicle.
- When a non vehicle device disappears its entry is not destroyed. It is muted at once and kept for 5 seconds (`ORPHAN_GRACE_MS`), then released if nothing took it over. A TV that stays removed is therefore silent immediately.
- `Device.ensurePlaying` lets a powered device take over such an entry instead of starting a track: first the entry that shares its `DeviceData` (which is what the game's move code produces), otherwise any muted entry of the same station within 20 tiles. The sound is reconfigured for the new device's mode and keeps playing the same track. An explicit Tune In still starts a new track.
- Vehicle radios are dropped immediately when the vehicle goes (their emitter belongs to the vehicle).
- A reused entry always clears its muted state in `playStation`.

## Consequences

Pick up and placement need one discovery scan (100 ticks) before sound returns. Offline stub tests covered: placed, picked up, held adoption with shared data, TV staying removed, a far radio not adopting.
