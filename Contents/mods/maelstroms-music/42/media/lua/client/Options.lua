require "Namespace"
require "Safe"

MaelstromMusic.Options = {}

local SHOW_EXAMPLE_STATION = "showExampleStation"
local BACKGROUND_GAP_MIN = "backgroundGapMinSeconds"
local BACKGROUND_GAP_MAX = "backgroundGapMaxSeconds"
local STEREO_SAFE_POSITIONING = "stereoSafePositioning"

local DEFAULT_GAP_MIN_SECONDS = 30
local DEFAULT_GAP_MAX_SECONDS = 80
local GAP_SLIDER_MAX_SECONDS = 300
local GAP_SLIDER_STEP_SECONDS = 5

local page = nil

local function readValue(id, default)
    local option = page and page:getOption(id)
    if option == nil then
        return default
    end
    return option:getValue()
end

function MaelstromMusic.Options.showExampleStation()
    return readValue(SHOW_EXAMPLE_STATION, true)
end

function MaelstromMusic.Options.backgroundGapSeconds()
    local minSeconds = math.floor(readValue(BACKGROUND_GAP_MIN, DEFAULT_GAP_MIN_SECONDS))
    local maxSeconds = math.floor(readValue(BACKGROUND_GAP_MAX, DEFAULT_GAP_MAX_SECONDS))
    return minSeconds, math.max(minSeconds, maxSeconds)
end

function MaelstromMusic.Options.stereoSafePositioning()
    return readValue(STEREO_SAFE_POSITIONING, false)
end

local function moveToFront(createdPage)
    local pages = PZAPI.ModOptions.Data
    for index, existing in ipairs(pages) do
        if existing == createdPage then
            table.remove(pages, index)
            break
        end
    end
    table.insert(pages, 1, createdPage)
end

local function install()
    if page or not PZAPI then
        return
    end
    page = PZAPI.ModOptions:create(MaelstromMusic.MOD_ID, "UI_MaelstromMusic_Title")
    moveToFront(page)
    page:addTitle("UI_MaelstromMusic_StationsTitle")
    page:addTickBox(SHOW_EXAMPLE_STATION, "UI_MaelstromMusic_ShowExampleStation", true, "UI_MaelstromMusic_ShowExampleStation_tt")
    page:addTitle("UI_MaelstromMusic_BackgroundsTitle")
    page:addSlider(BACKGROUND_GAP_MIN, "UI_MaelstromMusic_GapMin", 0, GAP_SLIDER_MAX_SECONDS, GAP_SLIDER_STEP_SECONDS, DEFAULT_GAP_MIN_SECONDS, "UI_MaelstromMusic_GapMin_tt")
    page:addSlider(BACKGROUND_GAP_MAX, "UI_MaelstromMusic_GapMax", 0, GAP_SLIDER_MAX_SECONDS, GAP_SLIDER_STEP_SECONDS, DEFAULT_GAP_MAX_SECONDS, "UI_MaelstromMusic_GapMax_tt")
    page:addTitle("UI_MaelstromMusic_AudioTitle")
    page:addTickBox(STEREO_SAFE_POSITIONING, "UI_MaelstromMusic_StereoSafe", false, "UI_MaelstromMusic_StereoSafe_tt")
    MaelstromMusic.Safe.call("could not load the saved options", function()
        PZAPI.ModOptions:load()
    end)
end

install()
