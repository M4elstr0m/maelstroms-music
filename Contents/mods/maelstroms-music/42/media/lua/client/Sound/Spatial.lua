require "Namespace"
require "Sound/Core"

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
