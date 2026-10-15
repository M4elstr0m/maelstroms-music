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
local player = { getForwardDirection = function() return { getX = function() return 0 end, getY = function() return 2 end } end }
local playerX, playerY = Stage.forward("player", player)
check("the player frame follows the facing direction", near(playerX, 0) and near(playerY, 1))

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
check("no acceptable square means no virtual placement", unmatched == nil)

Occlusion.direct = function() return 0.2 end
local sticky = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0.2 })
local again = Stage.place({}, origin, 1, 0, 1, { distance = 10, z = 0, occlusion = 0.2 }, sticky.candidate)
check("a previous candidate is tried first", again.candidate == sticky.candidate)

check("a close radio is not amplified past the cap", Stage.gainCompensation(1, 2.2, 0) <= 1.2)
check("equal distances need no compensation", near(Stage.gainCompensation(10, 10, 0), 1))
check("a farther virtual square is compensated upward", Stage.gainCompensation(10, 12, 0) > 1)

print(failures == 0 and "all checks passed" or (failures .. " check(s) failed"))
os.exit(failures == 0 and 0 or 1)
