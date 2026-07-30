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

function MaelstromMusic.Sound:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function MaelstromMusic.Sound:setEmitter(emitter)
    self.emitter = emitter
end

function MaelstromMusic.Sound:applyVolume()
    if self.id then
        self.emitter:setVolume(self.id, self.volume * self.volumeModifier * self.fadeLevel)
        self.emitter:tick()
    end
end

function MaelstromMusic.Sound:play(sound)
    local hasEmitter = self.emitter

    if hasEmitter then
        self:stop()
    else
        self.emitter = IsoWorld.instance:getFreeEmitter()
        self.emitter:setPos(self.x, self.y, self.z)
    end
    local gameSound = GameSounds.getSound(sound)
    if not gameSound then
        MaelstromMusic.Log.write("sound '" .. tostring(sound) .. "' isn't registered, can't play it.")
        return
    end
    local gameSoundClip = gameSound:getRandomClip()
    self.id = self.emitter:playClip(gameSoundClip, nil)
    self.stopWhenFaded = false
    self.emitter:set3D(self.id, self.sound3D)
    self:applyVolume()
end

function MaelstromMusic.Sound:stop()
    if self.emitter and self.id then
        self.emitter:stopSound(self.id)
    end
    self.id = nil
    self.stopWhenFaded = false
end

function MaelstromMusic.Sound:isPlaying()
    if not self.id then
        return false
    end
    return self.emitter and self.emitter:isPlaying(self.id)
end

function MaelstromMusic.Sound:setVolume(value)
    self.volume = value
    self:applyVolume()
end

function MaelstromMusic.Sound:setVolumeModifier(value)
    self.volumeModifier = value
    self:applyVolume()
end

function MaelstromMusic.Sound:setFadeLevel(level)
    self.fadeLevel = level
    self.fadeOrigin = level
    self.fadeTarget = level
    self.fadeDuration = 0
    self:applyVolume()
end

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

function MaelstromMusic.Sound:fadeOutAndStop(durationMs)
    self:fadeTo(0, durationMs)
    self.stopWhenFaded = true
end

function MaelstromMusic.Sound:isFading()
    return self.fadeLevel ~= self.fadeTarget
end

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

function MaelstromMusic.Sound:setPosAtObject(obj)
    if not obj then
        return
    end
    self:setPos(obj:getX(), obj:getY(), obj:getZ())
end

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
