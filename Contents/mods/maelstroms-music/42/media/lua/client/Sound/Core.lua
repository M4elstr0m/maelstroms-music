require "Namespace"
require "Log"
require "Fader"

MaelstromMusic.Sound = {
    emitter = nil,
    id = nil,
    x = 0,
    y = 0,
    z = 0,
    volume = 1,
    volumeModifier = 1,
    stopWhenFaded = false,
    sound3D = false,
}

-- Creates a sound object that inherits the defaults of the Sound class.
function MaelstromMusic.Sound:new()
    local o = { fader = MaelstromMusic.Fader.new() }
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
        self.emitter:setVolume(self.id, self.volume * self.volumeModifier * self.fader.level)
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
