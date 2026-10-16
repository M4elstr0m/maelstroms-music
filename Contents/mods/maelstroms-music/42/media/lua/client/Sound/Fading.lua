require "Namespace"
require "Sound/Core"

-- Jumps to a fade level and cancels any running fade.
function MaelstromMusic.Sound:setFadeLevel(level)
    self.fader:jump(level)
    self:applyVolume()
end

-- Starts a fade to the target level over the duration, advanced by updateFade.
function MaelstromMusic.Sound:fadeTo(target, durationMs)
    if not durationMs or durationMs <= 0 then
        self:setFadeLevel(target)
        return
    end
    self.fader:ramp(target, durationMs, getTimestampMs())
    self:applyVolume()
end

-- Fades to silence, then stops the sound once updateFade completes the fade.
function MaelstromMusic.Sound:fadeOutAndStop(durationMs)
    self:fadeTo(0, durationMs)
    self.stopWhenFaded = true
end

-- Whether a fade is still running.
function MaelstromMusic.Sound:isFading()
    return self.fader:isActive()
end

-- Advances the fade by one step, returns true while it is still running, stops the sound when a fade out ends.
function MaelstromMusic.Sound:updateFade()
    if not self.fader:isActive() then
        return false
    end
    self.fader:step(getTimestampMs())
    self:applyVolume()
    if self.fader:isActive() then
        return true
    end
    if self.stopWhenFaded then
        self:stop()
    end
    return false
end
