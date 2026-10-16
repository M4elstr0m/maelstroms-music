require "Namespace"

MaelstromMusic.Fader = {}
MaelstromMusic.Fader.__index = MaelstromMusic.Fader

-- Creates a fader resting at full level.
function MaelstromMusic.Fader.new()
    return setmetatable({ level = 1, origin = 1, target = 1, startedAt = 0, duration = 0 }, MaelstromMusic.Fader)
end

-- Jumps to a level and cancels any running ramp.
function MaelstromMusic.Fader:jump(level)
    self.level = level
    self.origin = level
    self.target = level
    self.duration = 0
end

-- Starts a linear ramp from the current level to the target, over the duration in milliseconds.
function MaelstromMusic.Fader:ramp(target, durationMs, now)
    self.origin = self.level
    self.target = target
    self.startedAt = now
    self.duration = durationMs
end

-- Whether a ramp is still running.
function MaelstromMusic.Fader:isActive()
    return self.level ~= self.target
end

-- Moves the level along the ramp to the given time.
function MaelstromMusic.Fader:step(now)
    local elapsed = now - self.startedAt
    if self.duration <= 0 or elapsed >= self.duration then
        self.level = self.target
        return
    end
    self.level = self.origin + (self.target - self.origin) * (elapsed / self.duration)
end
