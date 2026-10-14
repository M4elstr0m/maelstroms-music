require "Namespace"
require "Safe"

MaelstromMusic.Options = {}

local SHOW_EXAMPLE_STATION = "showExampleStation"

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

local function install()
    if page or not PZAPI then
        return
    end
    page = PZAPI.ModOptions:create(MaelstromMusic.MOD_ID, "UI_MaelstromMusic_Title")
    page:addTitle("UI_MaelstromMusic_StationsTitle")
    page:addTickBox(SHOW_EXAMPLE_STATION, "UI_MaelstromMusic_ShowExampleStation", true, "UI_MaelstromMusic_ShowExampleStation_tt")
    MaelstromMusic.Safe.call("could not load the saved options", function()
        PZAPI.ModOptions:load()
    end)
end

install()
