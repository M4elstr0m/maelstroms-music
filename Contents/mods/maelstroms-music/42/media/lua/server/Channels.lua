require "Namespace"
require "Log"
require "Safe"

MaelstromMusic.Channels = {}
MaelstromMusic.Channels.channelByUUID = {}
MaelstromMusic.Channels.stationByUUID = {}

function MaelstromMusic.Channels.refreshBroadcasts()
    for uuid, channel in pairs(MaelstromMusic.Channels.channelByUUID) do
        local stationId = MaelstromMusic.Channels.stationByUUID[uuid]
        local station = MaelstromMusic.Broadcasts and MaelstromMusic.Broadcasts[stationId]
        if station then
            local bc = RadioBroadCast.new("RADIOSTATION-" .. tostring(ZombRand(100000, 999999)), -1, -1)
            bc:AddRadioLine(RadioLine.new("[img=music] " .. station.title .. " [img=music]", 1.0, 1.0, 1.0))
            channel:setAiringBroadcast(bc)
        end
    end
end

Events.EveryTenMinutes.Add(MaelstromMusic.Channels.refreshBroadcasts)

function MaelstromMusic.Channels.onLoadRadioScripts(_scriptManager, _isNewGame)
    MaelstromMusic.Safe.call("channel registration failed", function()
        MaelstromMusic.Channels.channelByUUID = {}
        MaelstromMusic.Channels.stationByUUID = {}

        if not MaelstromMusic.Broadcasts and MaelstromMusic.Scanner.run then
            MaelstromMusic.Scanner.run()
        end

        if not MaelstromMusic.Broadcasts then
            return
        end

        for stationId, station in pairs(MaelstromMusic.Broadcasts) do
            local uuid = "RADIOSTATION-" .. stationId
            local category = station.kind == "television" and ChannelCategory.Television or ChannelCategory.Radio
            local channel = DynamicRadioChannel.new(station.title, station.frequency, category, uuid)
            channel:setAirCounterMultiplier(1.0)
            _scriptManager:AddChannel(channel, false)
            MaelstromMusic.Channels.channelByUUID[uuid] = channel
            MaelstromMusic.Channels.stationByUUID[uuid] = stationId
        end

        MaelstromMusic.Channels.refreshBroadcasts()

        local count = 0
        for _ in pairs(MaelstromMusic.Channels.channelByUUID) do count = count + 1 end
        MaelstromMusic.Log.write("registered " .. count .. " tunable channel(s).")
    end)
end

Events.OnLoadRadioScripts.Add(MaelstromMusic.Channels.onLoadRadioScripts)
