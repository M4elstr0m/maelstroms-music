-- Run from the repository root: lua5.1 tools/lua-tests/stage_test.lua
local root = "Contents/mods/maelstroms-music/42/media/lua/"
package.path = root .. "shared/?.lua;" .. root .. "client/?.lua;" .. package.path

require "Namespace"
require "Playback/Stage"
local Stage, Occlusion = MaelstromMusic.Playback.Stage, MaelstromMusic.Playback.Occlusion

local failures = 0
local function check(description, condition)
    print((condition and "pass  " or "FAIL  ") .. description)
    if not condition then failures = failures + 1 end
end
local function near(a, b, tolerance) return math.abs(a - b) <= (tolerance or 1e-6) end

check("a source on the left of the forward axis pans left", Stage.pan(0, -1, 1, 0) == -1)
check("a source on the right of the forward axis pans right", Stage.pan(0, 1, 1, 0) == 1)
check("straight ahead and straight behind are centred", Stage.pan(5, 0, 1, 0) == 0 and Stage.pan(-5, 0, 1, 0) == 0)
check("a source on top of the listener is centred", Stage.pan(0.1, 0.1, 1, 0) == 0)

local forwardX, forwardY = -math.sqrt(0.5), -math.sqrt(0.5)
check("on the screen frame a source to the screen right pans right", Stage.pan(1, -1, forwardX, forwardY) > 0.99)
check("on the screen frame a source to the screen left pans left", Stage.pan(-1, 1, forwardX, forwardY) < -0.99)

for _, pan in ipairs({ -1, -0.5, 0, 0.5, 1 }) do
    local left, right = Stage.gains(pan)
    check("equal power at pan " .. pan, near(left ^ 2 + right ^ 2, 1))
end
local left, right = Stage.gains(0)
check("centred gives both ears the same gain", near(left, right))
left, right = Stage.gains(-1)
check("hard left silences the right emitter", near(left, 1) and near(right, 0))

local screenX, screenY = Stage.forward("screen", nil)
check("the screen frame is the engine listener vector", near(screenX, forwardX) and near(screenY, forwardY))
local player = { getLookAngleRadians = function() return math.pi / 2 end }
local lookX, lookY = Stage.forward("look", player)
check("the look frame follows the look angle", near(lookX, 0) and near(lookY, 1))

local clock = 0
getTimestampMs = function() return clock end
require "Playback/ListenerFrame"
local ListenerFrame = MaelstromMusic.Playback.ListenerFrame
local function frameWhen(nextView)
    clock = clock + 1000
    Viewpoint = nextView and { View = { next = function() return nextView end } } or nil
    return ListenerFrame.current()
end
check("without Viewpoint the frame is the screen", frameWhen(nil) == "screen")
check("Viewpoint in first person uses the look angle", frameWhen("third") == "look")
check("Viewpoint in third person uses the look angle", frameWhen("isometric") == "look")
check("Viewpoint in its isometric view keeps the screen frame", frameWhen("first") == "screen")
clock = clock + 100
Viewpoint = { View = { next = function() return "third" end } }
check("the frame is refreshed at most every half second", ListenerFrame.current() == "screen")
clock = clock + 1000
Viewpoint = { View = { next = function() error("broken") end } }
MaelstromMusic.Log = MaelstromMusic.Log or { write = function() end }
check("a failing Viewpoint view falls back to the screen frame", ListenerFrame.current() == "screen")
Viewpoint = nil

local origin = { x = 100, y = 100 }
Occlusion.direct = function() return 0 end
local target = { distance = 10, z = 0, occlusion = 0 }

for _, side in ipairs({ -1, 1 }) do
    local placed = Stage.place({}, origin, 1, 0, side, target)
    local dx, dy = placed.x - origin.x, placed.y - origin.y
    check("a stage emitter keeps the real distance (side " .. side .. ")", near(math.sqrt(dx ^ 2 + dy ^ 2), 10))
    check("a stage emitter sits 40 degrees to its side (side " .. side .. ")", near(math.deg(math.atan2(dy * side, dx)), 40, 1e-6))
end

local seen = {}
Occlusion.direct = function(_, x, y)
    seen[#seen + 1] = { x, y }
    return (x - 100) ^ 2 + (y - 100) ^ 2 > 11 ^ 2 and 0.24 or 0
end
local walled = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0.24 })
check("the search moves outward until the muffling matches", walled and walled.radius >= 11 and #seen > 1)

Occlusion.direct = function() return 0 end
local unmatched = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0.9 })
check("with no matching square the closest one is still used", unmatched ~= nil and not Stage.isMatch(unmatched) and near(unmatched.deficit, 0.9))
check("an under muffled square loses volume to make up for it", near(Stage.mutedGain(0.5), 0.7) and near(Stage.mutedGain(0), 1) and Stage.mutedGain(1) < 0.5)
check("an over muffled square keeps its volume", Stage.mutedGain(-0.4) == 1)

local evaluations = 0
Occlusion.direct = function() evaluations = evaluations + 1 return 0 end
local first = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0.9 })
evaluations = 0
local reused = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0.9 }, first.candidate, false)
check("a failed match is re-evaluated without a new search when asked", evaluations == 1 and reused.candidate == first.candidate)

Occlusion.direct = function() return 0.2 end
local sticky = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0.2 })
local again = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0.2 }, sticky.candidate)
check("a previous candidate is tried first", again.candidate == sticky.candidate)

local previousCandidate = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0 }).candidate
local px, py = Stage.position(origin, 1, 0, 1, previousCandidate, 10)
Occlusion.direct = function(_, x, y) return (near(x, px) and near(y, py)) and 0.2 or 0.22 end
local kept = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0.5 }, previousCandidate)
check("a barely better square does not replace the current one", kept.candidate == previousCandidate)
Occlusion.direct = function(_, x, y) return (near(x, px) and near(y, py)) and 0.2 or 0.45 end
local switched = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0.5 }, previousCandidate)
check("a clearly better square replaces it", switched.candidate ~= previousCandidate)

check("a close radio is not amplified past the cap", Stage.gainCompensation(1, 2.2, 0) <= 1.2)
check("equal distances need no compensation", near(Stage.gainCompensation(10, 10, 0), 1))
check("a farther virtual square is compensated upward", Stage.gainCompensation(10, 12, 0) > 1)

print(failures == 0 and "all checks passed" or (failures .. " check(s) failed"))
os.exit(failures == 0 and 0 or 1)
