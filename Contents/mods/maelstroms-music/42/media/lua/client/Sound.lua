require "Namespace"
require "Log"

MaelstromMusic.Sound = {
    emitter = nil,
    id = nil,
    x = 0,
    y = 0,
    z = 0,
    volume = 1,
    volumeModifier = 1,
    fadeLevel = 1,
    fadeOrigin = 1,
    fadeTarget = 1,
    fadeStartedAt = 0,
    fadeDuration = 0,
    stopWhenFaded = false,
    sound3D = false,
}

-- Creates a sound object that inherits the defaults of the Sound class.
function MaelstromMusic.Sound:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Sets the FMOD emitter that plays this sound.
function MaelstromMusic.Sound:setEmitter(emitter)
    self.emitter = emitter
end

-- Pushes volume times modifier times fade level to the emitter and ticks it, which makes it audible.
function MaelstromMusic.Sound:applyVolume()
    if self.id then
        self.emitter:setVolume(self.id, self.volume * self.volumeModifier * self.fadeLevel)
        self.emitter:tick()
    end
end

-- Plays a registered sound script on the emitter (a free world emitter when none is set), restarting any current playback.
function MaelstromMusic.Sound:play(sound)
    local hasEmitter = self.emitter

    if hasEmitter then
        self:stop()
    else
        self.emitter = IsoWorld.instance:getFreeEmitter()
        self.emitter:setPos(self.x, self.y, self.z)
    end
    if not GameSounds.isKnownSound(sound) then
        MaelstromMusic.Log.write("sound '" .. tostring(sound) .. "' isn't registered, can't play it.")
        return
    end
    local gameSound = GameSounds.getSound(sound)
    local gameSoundClip = gameSound:getRandomClip()
    self.id = self.emitter:playClip(gameSoundClip, nil)
    self.stopWhenFaded = false
    self.emitter:set3D(self.id, self.sound3D)
    self:applyVolume()
end

-- Stops the current playback, if any.
function MaelstromMusic.Sound:stop()
    if self.emitter and self.id then
        self.emitter:stopSound(self.id)
    end
    self.id = nil
    self.stopWhenFaded = false
end

-- Whether the sound is currently playing on its emitter.
function MaelstromMusic.Sound:isPlaying()
    if not self.id then
        return false
    end
    return self.emitter and self.emitter:isPlaying(self.id)
end

-- Sets the base volume.
function MaelstromMusic.Sound:setVolume(value)
    self.volume = value
    self:applyVolume()
end

-- Sets the multiplier of the base volume, used for the per mode loudness of devices.
function MaelstromMusic.Sound:setVolumeModifier(value)
    self.volumeModifier = value
    self:applyVolume()
end

-- Jumps to a fade level and cancels any running fade.
function MaelstromMusic.Sound:setFadeLevel(level)
    self.fadeLevel = level
    self.fadeOrigin = level
    self.fadeTarget = level
    self.fadeDuration = 0
    self:applyVolume()
end

-- Starts a fade to the target level over the duration, advanced by updateFade.
function MaelstromMusic.Sound:fadeTo(target, durationMs)
    if not durationMs or durationMs <= 0 then
        self:setFadeLevel(target)
        return
    end
    self.fadeOrigin = self.fadeLevel
    self.fadeTarget = target
    self.fadeStartedAt = getTimestampMs()
    self.fadeDuration = durationMs
    self:applyVolume()
end

-- Fades to silence, then stops the sound once updateFade completes the fade.
function MaelstromMusic.Sound:fadeOutAndStop(durationMs)
    self:fadeTo(0, durationMs)
    self.stopWhenFaded = true
end

-- Whether a fade is still running.
function MaelstromMusic.Sound:isFading()
    return self.fadeLevel ~= self.fadeTarget
end

-- Advances the fade by one step, returns true while it is still running, stops the sound when a fade out ends.
function MaelstromMusic.Sound:updateFade()
    if self.fadeLevel == self.fadeTarget then
        return false
    end

    local elapsed = getTimestampMs() - self.fadeStartedAt
    if self.fadeDuration <= 0 or elapsed >= self.fadeDuration then
        self.fadeLevel = self.fadeTarget
    else
        self.fadeLevel = self.fadeOrigin + (self.fadeTarget - self.fadeOrigin) * (elapsed / self.fadeDuration)
    end
    self:applyVolume()

    if self.fadeLevel ~= self.fadeTarget then
        return true
    end
    if self.stopWhenFaded then
        self:stop()
    end
    return false
end

-- Places the emitter at a position and switches the sound to 3D.
function MaelstromMusic.Sound:setPos(x, y, z)
    self.x = x
    self.y = y
    self.z = z or 0
    self:set3D(true)

    if self.emitter then
        self.emitter:setPos(x, y, z)
        self.emitter:tick()
    end
end

-- Moves the emitter without changing the 3D mode or ticking, cheap enough to call every frame.
function MaelstromMusic.Sound:moveTo(x, y, z)
    self.x = x
    self.y = y
    self.z = z or 0
    if self.emitter then
        self.emitter:setPos(x, y, self.z)
    end
end

-- Places the sound at the position of a world object.
function MaelstromMusic.Sound:setPosAtObject(obj)
    if not obj then
        return
    end
    self:setPos(obj:getX(), obj:getY(), obj:getZ())
end

-- Switches between 3D and flat 2D playback (nil means true).
function MaelstromMusic.Sound:set3D(bool)
    if bool == nil then
        bool = true
    end
    self.sound3D = bool
    if self.id then
        self.emitter:set3D(self.id, self.sound3D)
        self.emitter:tick()
    end
end
