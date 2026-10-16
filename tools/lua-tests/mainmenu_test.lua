-- Run from the repository root: lua5.1 tools/lua-tests/mainmenu_test.lua
local Support = dofile("tools/lua-tests/support.lua")
Support.installEvents()
local World = dofile("tools/lua-tests/music_world.lua")

local previewPlaying = false
CharacterCreationMain = { onOptionMouseDown = function() end }

require "Namespace"
MaelstromMusic.ScanComplete = true
MaelstromMusic.MainMenuStation = { title = "Main Menu Theme", shuffle = false, tracks = { "menu_1", "menu_2" }, trackFiles = { "m1.mp3", "m2.mp3" } }
require "MainMenu"

local function render(times) for _ = 1, times or 1 do Support.fire("OnRenderTick") end end
local function lines(text) return (text:gsub("\n", " | ")) end
local function has(text, part) return text:find(part, 1, true) ~= nil end

local boot = World.take()
Support.check("loading the module clears the menu emitter", has(boot, "ui stopAll"))
Support.check("loading the module gives the vanilla music volume back", has(boot, "vanilla volume 0.50"))

Support.fire("OnGameBoot")
Support.check("the vanilla mute is only claimed once the theme plays", not has(World.take(), "vanilla volume 0.00"))

render()
Support.check("nothing starts before the main menu is entered", not has(World.take(), "ui play"))

Support.fire("OnMainMenuEnter")
render()
local started = World.take()
Support.check("the theme starts on the menu emitter", has(started, "ui play menu_1 #1"))
Support.check("the theme is flat", has(started, "ui 3d #1 false"))
Support.check("the theme fades in from silence", has(started, "ui volume #1 0.000"))
Support.check("the vanilla soundtrack is muted", has(started, "vanilla volume 0.00"))
Support.check("the main menu music state is held", has(started, "vanilla state MainMenu") and has(started, "vanilla stop"))
Support.check("the emitter is recentred before playing", has(started, "ui pos 0 0 0"))
Support.trace("started", lines(started))

World.advance(1500)
render()
local rising = World.take()
Support.check("the fade in raises the volume with the music option", has(rising, "ui volume #1 0.2"))
Support.trace("rising", lines(rising))

World.advance(2000)
render()
local full = World.take()
Support.check("the theme reaches the music option volume", has(full, "ui volume #1 0.500"))
Support.trace("full", lines(full))

local panel = { soundPlayer = { isPlaying = function() return previewPlaying end }, soundRef = 3 }
CharacterCreationMain.onOptionMouseDown(panel, { internal = "PLAYDEMOVOICE" }, 0, 0)
previewPlaying = true
render()
local ducked = World.take()
Support.check("the theme ducks under the voice preview", has(ducked, "ui volume #1 0.150"))
Support.check("the music state is left alone during the voice preview", not has(ducked, "vanilla state MainMenu"))
Support.trace("ducked", lines(ducked))
previewPlaying = false
render()
Support.check("the theme comes back after the voice preview", has(World.take(), "ui volume #1 0.500"))

World.uiEmitter.playing = false
World.advance(1000)
render()
local ended = World.take()
Support.check("a finished track is discarded", has(ended, "ui stop #1"))
Support.trace("ended", lines(ended))
World.advance(5000)
render()
Support.check("the next track waits for the gap", not has(World.take(), "ui play"))
World.advance(6000)
World.uiEmitter.playing = true
render()
local following = World.take()
Support.check("the next track follows after the gap", has(following, "ui play menu_2"))
Support.trace("following", lines(following))

World.advance(3000)
render()
World.take()
Support.fire("OnGameStart")
render()
local leaving = World.take()
Support.check("starting a game fades the theme out", has(leaving, "ui volume #2") and not has(leaving, "ui stop"))
Support.trace("leaving", lines(leaving))
World.advance(2600)
render()
local gone = World.take()
Support.check("the faded theme is stopped", has(gone, "ui stop #2"))
Support.check("the vanilla soundtrack is given back", has(gone, "vanilla volume 0.50"))
Support.trace("gone", lines(gone))
World.advance(30000)
render(3)
Support.check("nothing plays after the game started", not has(World.take(), "ui play"))

Support.finish()
