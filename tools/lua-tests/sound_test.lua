-- Run from the repository root: lua5.1 tools/lua-tests/sound_test.lua
local Support = dofile("tools/lua-tests/support.lua")

local clock = 0
getTimestampMs = function() return clock end

local known = { track = true }
GameSounds = {
    isKnownSound = function(name) return known[name] == true end,
    getSound = function() return { getRandomClip = function() return "clip" end } end,
}

local log = {}
local function newEmitter()
    local emitter = { playing = true }
    function emitter:playClip() log[#log + 1] = "play" return 7 end
    function emitter:setVolume(id, value) log[#log + 1] = string.format("volume %d %.3f", id, value) end
    function emitter:set3D(id, flag) log[#log + 1] = "3d " .. id .. " " .. tostring(flag) end
    function emitter:setPos(x, y, z) log[#log + 1] = string.format("pos %.1f %.1f %.1f", x, y, z or -1) end
    function emitter:tick() log[#log + 1] = "tick" end
    function emitter:isPlaying() return self.playing end
    function emitter:stopSound(id) log[#log + 1] = "stop " .. id end
    return emitter
end
local emitter = newEmitter()
IsoWorld = { instance = { getFreeEmitter = function() return emitter end } }

require "Namespace"
require "Sound"
local Sound = MaelstromMusic.Sound

local function last() return log[#log - 1] end
local function reset() log = {} end

local sound = Sound:new()
Support.check("a new sound is not playing", not sound:isPlaying())
sound:play("missing")
Support.check("an unknown sound is not played", sound.id == nil)

sound:setVolume(0.5)
sound:setVolumeModifier(0.4)
sound:play("track")
Support.equal("a played sound has an id", sound.id, 7)
Support.equal("the volume is base times modifier times fade", last(), "volume 7 0.200")
Support.equal("a fresh sound is flat", sound.sound3D, false)

reset()
sound:setFadeLevel(0)
Support.equal("a fade level of zero silences the sound", last(), "volume 7 0.000")
Support.check("setting a level is not a running fade", not sound:isFading())

sound:fadeTo(1, 1000)
Support.check("a fade is running", sound:isFading())
clock = clock + 500
Support.equal("a running fade reports it is not finished", sound:updateFade(), true)
Support.equal("halfway through the fade the volume is half", last(), "volume 7 0.100")
clock = clock + 600
Support.equal("the end of the fade is reported", sound:updateFade(), false)
Support.equal("the fade ends at full level", last(), "volume 7 0.200")
Support.equal("updating a finished fade does nothing", sound:updateFade(), false)

sound:fadeTo(0.5, 0)
Support.equal("a fade without duration jumps to the target", sound.fader.level, 0.5)
sound:fadeTo(1, -5)
Support.equal("a negative duration jumps too", sound.fader.level, 1)

reset()
sound:fadeOutAndStop(1000)
clock = clock + 400
sound:updateFade()
Support.check("the sound keeps playing during the fade out", sound.id == 7 and not (log[#log] or ""):find("stop"))
clock = clock + 700
Support.equal("the fade out finishes", sound:updateFade(), false)
Support.check("the sound is stopped when the fade out ends", sound.id == nil)
Support.check("the stop was sent to the emitter", (function() for _, line in ipairs(log) do if line == "stop 7" then return true end end end)())

sound:play("track")
sound:fadeOutAndStop(0)
Support.check("a fade out without duration stops at once", sound.fader.level == 0 and sound.stopWhenFaded == true)

reset()
local positioned = Sound:new()
positioned:setPos(10, 20, 1)
Support.check("setPos makes the sound 3D", positioned.sound3D == true)
Support.check("setPos before playing only stores the position", #log == 0 and positioned.x == 10 and positioned.z == 1)
positioned:play("track")
Support.check("playing places the free emitter at the stored position", (function() for _, line in ipairs(log) do if line == "pos 10.0 20.0 1.0" then return true end end end)())
Support.equal("a playing 3D sound is flagged 3D on its emitter", (function() for _, line in ipairs(log) do if line == "3d 7 true" then return line end end end)(), "3d 7 true")
reset()
positioned:moveTo(11, 21)
Support.equal("moveTo moves without a tick", table.concat(log, ";"), "pos 11.0 21.0 0.0")
reset()
positioned:set3D(false)
Support.check("set3D(false) updates a playing sound", positioned.sound3D == false and log[1] == "3d 7 false")
positioned:set3D()
Support.equal("set3D with no argument means true", positioned.sound3D, true)

local object = { getX = function() return 1 end, getY = function() return 2 end, getZ = function() return 3 end }
positioned:setPosAtObject(object)
Support.check("setPosAtObject copies the object position", positioned.x == 1 and positioned.y == 2 and positioned.z == 3)
positioned:setPosAtObject(nil)
Support.equal("setPosAtObject ignores nil", positioned.x, 1)

emitter.playing = false
Support.check("isPlaying follows the emitter", not positioned:isPlaying())
positioned:stop()
Support.check("stop clears the id", positioned.id == nil and not positioned:isPlaying())

local borrowed = Sound:new()
local other = newEmitter()
borrowed:setEmitter(other)
borrowed:play("track")
Support.equal("a sound with an emitter keeps it", borrowed.emitter, other)

Support.finish()
