-- Run from the repository root: lua5.1 tools/lua-tests/scanner_test.lua
local Support = dofile("tools/lua-tests/support.lua")
Support.installEvents()
local World = dofile("tools/lua-tests/scanner_world.lua")
require "Namespace"
require "Scanner/Scanner"

local Scanner = MaelstromMusic.Scanner
Scanner.run()

local broadcasts, backgrounds = MaelstromMusic.Broadcasts, MaelstromMusic.Backgrounds
local manifestPath = "maelstromsmusic/media/radios/_radios_manifest.txt"
local scriptPath = "maelstromsmusic/media/scripts/GeneratedRadios.txt"

local count = 0
for _ in pairs(broadcasts) do count = count + 1 end
Support.equal("radios and TVs of the base mod and the addon are registered", count, 4)
Support.check("the scan runs on game boot and when mods change", #Support.handlers.OnGameBoot == 1 and #Support.handlers.OnModsModified == 1)
Support.equal("the scan is flagged complete", MaelstromMusic.ScanComplete, true)

local example = broadcasts.radio_example
Support.check("a radio keeps its title, kind and flags", example.title == "Example Radio" and example.kind == "radio" and example.shuffle and example.fade)
Support.equal("only playable tracks are listed, sorted", table.concat(example.trackFiles, ","), "one.mp3,two.ogg")
Support.equal("the sound names follow the station id", example.tracks[2], "BroadcastTrack_radio_example_2")
Support.equal("an automatic frequency is hashed from the id", example.frequency, 88600)
Support.equal("presets are on by default", example.autoPreset, true)

local tv = broadcasts.tv_tvnews
Support.check("a television is a television", tv.kind == "television" and tv.autoPreset == false)

local night = broadcasts.radio_night
Support.equal("a station of an addon with the same title and mergeTracks is merged in", table.concat(night.trackFiles, ","), "a.mp3,b.mp3,x.mp3,z.mp3")
Support.check("sequences chain a hand off", night.forcedNext[1] == 2 and night.forcedNext[3] == 1 and night.forcedNext[4] == 1)
Support.check("the targets of a sequence are gated", night.gated[1] == true and night.gated[2] == true and night.gated[3] == nil)
Support.equal("invalid sequences are dropped", (function() local n = 0 for _ in pairs(night.forcedNext) do n = n + 1 end return n end)(), 3)
Support.equal("a fixed frequency taken by another station is lost", night.frequency, 104200)
Support.equal("addon stations are namespaced by their mod", broadcasts.radio_fallout_galaxy.frequency, 95400)
Support.equal("an addon station without mergeTracks stays separate", broadcasts.radio_fallout_nightfo, nil)

Support.check("a station without a title, tracks or valid JSON is skipped",
    broadcasts.radio_bad == nil and broadcasts.radio_empty == nil and broadcasts.radio_broken == nil)

Support.check("only the first mod's backgrounds are used", backgrounds.bg_calm ~= nil and backgrounds.bg_tense ~= nil and backgrounds.bg_ignored == nil)
Support.check("a background needs a drama value", backgrounds.bg_nodrama == nil)
Support.check("a background keeps its drama and shuffle", backgrounds.bg_calm.drama == 1 and backgrounds.bg_calm.shuffle == true and backgrounds.bg_tense.drama == 6)

local menu = MaelstromMusic.MainMenuStation
Support.equal("main menu tracks of all sources are pooled", table.concat(menu.trackFiles, ","), "theme1.mp3,theme2.flac,fallout.mp3")
Support.check("a pooled station shuffles", menu.shuffle == true and menu.tracks[3] == "BroadcastTrack_mainmenu_3")
local death = MaelstromMusic.DeathStation
Support.equal("game over tracks are pooled", table.concat(death.trackFiles, ","), "d1.mp3,d2.ogg")

local manifest = World.written[manifestPath]
Support.equal("the manifest lists every station sorted", manifest, table.concat({
    "schema|6",
    "bg_calm|Calm|true|c1.mp3,c2.mp3",
    "bg_tense|Tense|false|t1.mp3",
    "death|Game Over|true|d1.mp3,d2.ogg",
    "mainmenu|Main Menu Theme|true|theme1.mp3,theme2.flac,fallout.mp3",
    "radio_example|Example Radio|true|one.mp3,two.ogg",
    "radio_fallout_galaxy|Galaxy News|false|g1.mp3",
    "radio_night|Night FM|false|a.mp3,b.mp3,x.mp3,z.mp3",
    "tv_tvnews|News TV|false|n1.mp3",
}, "\n"))

local script = World.written[scriptPath]
local sounds = 0
for _ in script:gmatch("\tsound BroadcastTrack_") do sounds = sounds + 1 end
Support.equal("the script defines one sound per track", sounds, 16)
Support.check("the script is one module", script:find("^module MaelstromMusic\n{\n") ~= nil and script:find("}\n$") ~= nil)
Support.check("a radio track is a 3D sound with a distance range",
    script:find("sound BroadcastTrack_radio_example_1\n\t{\n\t\tcategory = Maelstrom Music,\n\t\tmaster = Ambient,\n\t\tis3D = true,\n\t\tclip\n\t\t{\n\t\t\tfile = media/radios/example/one.mp3,\n\t\t\tdistanceMin = 2,\n\t\t\tdistanceMax = 75,\n", 1, true) ~= nil)
Support.check("a background track is a flat sound", script:find("is3D = false,\n\t\tclip\n\t\t{\n\t\t\tfile = media/backgrounds/calm/c1.mp3,\n\t\t\tdistanceMax = 75,\n", 1, true) ~= nil)
Support.check("a merged track points into its own addon folder", script:find("file = media/radios/nightfo/z.mp3,", 1, true) ~= nil)
Support.check("pooled tracks live in their pool folder", script:find("file = media/mainmenu/theme1.mp3,", 1, true) ~= nil and script:find("file = media/deaths/dead/d1.mp3,", 1, true) ~= nil)
Support.equal("the first run reloads the sounds", World.reloads, 1)

Support.trace("manifest", manifest)
Support.trace("script", script)

Scanner.run()
Support.equal("an unchanged scan does not regenerate anything", World.reloads, 1)
Support.equal("the same scan assigns the same frequencies", MaelstromMusic.Broadcasts.radio_example.frequency, 88600)

Support.finish()
