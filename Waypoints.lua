local ADDON_NAME, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

local nativeQuestID
local selectedQuestID
local startPoint
local tomtomUID
local tomtomOwner
local destination

local function Report(message)
    print("|cff33ff99Forever Quest Pins:|r " .. message)
end

local function ValidPoint(mapID, x, y)
    return type(mapID) == "number" and mapID > 0
        and type(x) == "number" and type(y) == "number"
        and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

local function OwnsBlizzardPin()
    if not startPoint or not C_Map or not C_Map.GetUserWaypoint then
        return false
    end
    local point = C_Map.GetUserWaypoint()
    return point and point.uiMapID == startPoint.uiMapID
        and point.position.x == startPoint.position.x
        and point.position.y == startPoint.position.y
end

function ns.ClearWaypoint()
    if nativeQuestID and C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID() == nativeQuestID then
        C_SuperTrack.SetSuperTrackedQuestID(0)
    end
    nativeQuestID = nil
    if tomtomUID and tomtomOwner then
        tomtomOwner:RemoveWaypoint(tomtomUID)
    end
    if OwnsBlizzardPin() and C_Map.ClearUserWaypoint then
        C_Map.ClearUserWaypoint()
    end
    selectedQuestID, startPoint, tomtomUID, tomtomOwner, destination = nil, nil, nil, nil, nil
end

local function SetTomTomPoint(questID, mapID, x, y)
    if not TomTom or type(TomTom.AddWaypoint) ~= "function"
        or type(TomTom.RemoveWaypoint) ~= "function" then
        return false, L["TomTom is not loaded. Choose Blizzard Map Pins or enable TomTom."]
    end
    if destination and destination.mapID == mapID and destination.x == x and destination.y == y then
        return true
    end
    if tomtomUID then
        tomtomOwner:RemoveWaypoint(tomtomUID)
        tomtomUID = nil
        destination = nil
    end
    tomtomOwner = TomTom
    tomtomUID = TomTom:AddWaypoint(mapID, x, y, {
        title = ns.GetQuestTitle(questID) or (L["Quest "] .. questID),
        from = ADDON_NAME,
        persistent = false,
        minimap = true,
        world = true,
        crazy = true,
    })
    if not tomtomUID then
        return false, L["TomTom could not create this waypoint."]
    end
    destination = { mapID = mapID, x = x, y = y }
    return true
end

function ns.TrackQuest(questID, data)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end
    ns.ClearWaypoint()
    local onQuest = ns.IsOnQuest(questID)
    local mapID, x, y
    if onQuest then
        if ns.GetOption("waypointProvider") == "blizzard" then
            if not C_SuperTrack or type(C_SuperTrack.SetSuperTrackedQuestID) ~= "function" then
                Report(L["Blizzard quest tracking is unavailable on this client."])
                return false
            end
            C_SuperTrack.SetSuperTrackedQuestID(questID)
            nativeQuestID = questID
            selectedQuestID = questID
            return true
        end
        if C_QuestLog and C_QuestLog.GetNextWaypoint then
            mapID, x, y = C_QuestLog.GetNextWaypoint(questID)
        end
    else
        data = data or (ns.Quests and ns.Quests[questID])
        if data then
            mapID, x, y = data.mapID, (data.x or -100) / 100, (data.y or -100) / 100
        end
    end
    if not ValidPoint(mapID, x, y) then
        Report(L["No quest location is available yet."])
        return false
    end
    if ns.GetOption("waypointProvider") == "tomtom" then
        local ok, message = SetTomTomPoint(questID, mapID, x, y)
        if not ok then Report(message) return false end
    else
        if not C_Map or type(C_Map.SetUserWaypoint) ~= "function"
            or type(C_Map.GetUserWaypoint) ~= "function"
            or type(C_Map.ClearUserWaypoint) ~= "function"
            or type(C_Map.CanSetUserWaypointOnMap) ~= "function"
            or not UiMapPoint or type(UiMapPoint.CreateFromCoordinates) ~= "function" then
            Report(L["Blizzard Map Pins are unavailable on this client. TomTom can be selected in options."])
            return false
        end
        if not C_Map.CanSetUserWaypointOnMap(mapID) then
            Report(L["Blizzard does not allow a map pin in this zone."])
            return false
        end
        startPoint = UiMapPoint.CreateFromCoordinates(mapID, x, y)
        C_Map.SetUserWaypoint(startPoint)
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end
    selectedQuestID = questID
    return true
end

function ns.UpdateWaypoint()
    if not selectedQuestID or nativeQuestID then return end
    if startPoint and (not OwnsBlizzardPin()
        or (C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint
            and not C_SuperTrack.IsSuperTrackingUserWaypoint())) then
        selectedQuestID, startPoint = nil, nil
        return
    end
    if not ns.IsOnQuest(selectedQuestID) then return end
    if startPoint then
        ns.TrackQuest(selectedQuestID)
    else
        local mapID, x, y
        if C_QuestLog and C_QuestLog.GetNextWaypoint then
            mapID, x, y = C_QuestLog.GetNextWaypoint(selectedQuestID)
        end
        if ValidPoint(mapID, x, y) then
            local ok, message = SetTomTomPoint(selectedQuestID, mapID, x, y)
            if not ok then Report(message) ns.ClearWaypoint() end
        elseif tomtomUID then
            tomtomOwner:RemoveWaypoint(tomtomUID)
            tomtomUID, destination = nil, nil
        end
    end
end

function ns.OnWaypointQuestEnded(questID)
    if selectedQuestID == questID then
        ns.ClearWaypoint()
    end
end
