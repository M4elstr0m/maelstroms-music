-- Run from the repository root: lua5.1 tools/lua-tests/director_test.lua
local Support = dofile("tools/lua-tests/support.lua")
Support.installEvents()
local World = dofile("tools/lua-tests/music_world.lua")

require "Namespace"
MaelstromMusic.ScanComplete = true
MaelstromMusic.Backgrounds = {
    bg_calm = { title = "Calm", drama = 1, shuffle = false, tracks = { "calm_1", "calm_2" }, trackFiles = { "c1.mp3", "c2.mp3" } },
    bg_tense = { title = "Tense", drama = 6, shuffle = false, tracks = { "tense_1" }, trackFiles = { "t1.mp3" } },
}
require "Playback/Cache"
require "Backgrounds/Backgrounds"

local Cache = MaelstromMusic.Playback.Cache
local function tick(times) for _ = 1, times or 1 do Support.fire("OnTick") end end
local function played(text) return text:find("world play", 1, true) ~= nil end
local function trace(label) Support.trace(label, World.clock, (World.take():gsub("\n", " | "))) end

Support.check("the director is active when backgrounds exist", MaelstromMusic.Ambience.Director.isActive())

Support.fire("OnPreMapLoad")
local priming = World.take()
Support.check("the first tracks of every mood are queued for pre decoding", true)
Support.trace("priming", (priming:gsub("\n", " | ")))

tick()
local first = World.take()
Support.check("taking over silences the vanilla soundtrack", first:find("vanilla volume 0.00", 1, true) ~= nil)
Support.check("taking over holds the in game music state", first:find("vanilla state InGame", 1, true) ~= nil)
Support.check("nothing plays during the first gap", not played(first))
trace("takeover")

World.advance(29000)
tick()
Support.check("still silent just before the gap ends", not played(World.take()))

World.advance(1500)
tick()
local started = World.take()
Support.check("the calmest mood starts when the gap is over", started:find("world play calm_1", 1, true) ~= nil)
Support.check("a background plays flat", started:find("world 3d #1 false", 1, true) ~= nil)
Support.check("a background starts silent to fade in", started:find("world volume #1 0.000", 1, true) ~= nil)
Support.trace("started", (started:gsub("\n", " | ")))

World.advance(2000)
tick()
local fading = World.take()
Support.check("the fade in raises the volume", fading:find("world volume #1 0.", 1, true) ~= nil)
Support.trace("fade in", (fading:gsub("\n", " | ")))

World.advance(3000)
tick(35)
World.take()
Support.check("calm music keeps playing while the drama stays low", not played(World.take()))

World.zombies = 3
tick(30)
local cut = World.take()
Support.check("rising drama fades the current track out", cut:find("world volume #1", 1, true) ~= nil and not played(cut))
Support.trace("cut", (cut:gsub("\n", " | ")))
World.advance(3100)
tick()
local switched = World.take()
Support.check("the tense mood starts once the fade out is over", switched:find("world play tense_1", 1, true) ~= nil)
Support.check("the previous track is stopped", switched:find("world stop #1", 1, true) ~= nil)
Support.trace("switched", (switched:gsub("\n", " | ")))

World.zombies = 0
World.advance(5000)
tick(40)
Support.check("calming down never cuts the current track", not played(World.take()))

Cache.entries = { { sound = { isPlaying = function() return true end } } }
tick()
local paused = World.take()
Support.check("an audible radio fades the soundtrack out", paused:find("world volume", 1, true) ~= nil and not played(paused))
World.advance(3100)
tick()
Support.check("then a gap starts, nothing plays", not played(World.take()))
World.advance(60000)
tick(3)
Support.check("nothing plays while the radio is audible", not played(World.take()))
Support.trace("radio", World.clock)

Cache.entries = {}
tick()
local resumed = World.take()
Support.check("once the radio is off and the gap has passed a mood plays again", played(resumed))
Support.trace("after radio", (resumed:gsub("\n", " | ")))

World.worldEmitter.playing = false
tick()
World.take()
World.advance(30500)
World.zombies = 0
tick()
local again = World.take()
Support.check("when a track ends a gap starts and a track follows", played(again))
Support.trace("again", (again:gsub("\n", " | ")))

Support.fire("OnPlayerDeath")
local death = World.take()
Support.check("dying stops the soundtrack and gives the vanilla music back", death:find("world stop", 1, true) ~= nil and death:find("vanilla volume 0.50", 1, true) ~= nil)
Support.trace("death", (death:gsub("\n", " | ")))
World.advance(100000)
tick(3)
Support.check("the soundtrack stays quiet after death", not played(World.take()))

Support.fire("OnCreatePlayer")
tick()
World.take()
World.advance(30500)
tick()
Support.check("a new character gets the soundtrack back", played(World.take()))

World.player = nil
Support.fire("OnRenderTick")
local gone = World.take()
Support.check("losing the player releases the soundtrack", gone:find("world stop", 1, true) ~= nil and gone:find("vanilla volume 0.50", 1, true) ~= nil)
Support.trace("gone", (gone:gsub("\n", " | ")))

Support.finish()
