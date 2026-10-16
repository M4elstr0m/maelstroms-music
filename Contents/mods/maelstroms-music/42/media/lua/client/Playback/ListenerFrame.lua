require "Namespace"
require "Safe"

MaelstromMusic.Playback.ListenerFrame = {}

local REFRESH_MS = 500
local VIEW_NEXT_FROM_FIRST_PERSON = "third"
local VIEW_NEXT_FROM_THIRD_PERSON = "isometric"

local cachedFrame = "screen"
local refreshedAt = nil
local viewpointFailed = false

-- Asks Viewpoint which view comes next, and gives up for the session after a failure.
local function readNextView()
    local view = Viewpoint and Viewpoint.View
    if viewpointFailed or not view then
        return nil
    end
    local nextView = nil
    local ok = MaelstromMusic.Safe.call("could not read the Viewpoint view, using the screen frame", function()
        nextView = view.next()
    end)
    viewpointFailed = not ok
    return nextView
end

-- Returns "look" while the first or third person view of Viewpoint is active, otherwise "screen".
local function detect()
    local nextView = readNextView()
    if nextView == VIEW_NEXT_FROM_FIRST_PERSON or nextView == VIEW_NEXT_FROM_THIRD_PERSON then
        return "look"
    end
    return "screen"
end

-- Returns the listener frame, refreshed at most every 500 ms.
function MaelstromMusic.Playback.ListenerFrame.current()
    local now = getTimestampMs()
    if not refreshedAt or now - refreshedAt >= REFRESH_MS then
        cachedFrame = detect()
        refreshedAt = now
    end
    return cachedFrame
end
