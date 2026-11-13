local ADDON_NAME, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

ns.MapPins = ns.MapPins or {}
local MapPins = ns.MapPins

-- Keep native atlas size off so pins stay PIN_SIZE. Special pins reuse the
-- QuestNormal silhouette with desaturation + a vertex tint because Forever's
-- QuestDaily atlas can resolve to yellow. Gossip AvailableQuestIcon is not
-- used: it can bind with no pixels.
local NORMAL_ICON_ATLAS = "QuestNormal"
local NORMAL_ICON_FILE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\QuestAvailable"
local REPEATABLE_ICON_ATLAS = "QuestDaily"
local REPEATABLE_ICON_FILE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\QuestRepeatable"
local INSTANCE_ICON_FILE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\QuestAttunement"
local PROFESSION_PIN_R, PROFESSION_PIN_G, PROFESSION_PIN_B = 1.00, 0.65, 0.20
-- Same look as ForeverQuestTint's map icons: a desaturated teal copy, solid over the
-- bottom 45% and gone by 75%, leaving the icon's own yellow on top.
local FOREVER_TINT_R, FOREVER_TINT_G, FOREVER_TINT_B = 0.44, 1.00, 1.00
local FOREVER_SOLID = 0.45
local FOREVER_FADE = 0.75
local PIN_SIZE = 24
-- Keep dense spawn loops together without merging separate camps. Six pins per
-- quest cap a zone view while the hover cloud still shows every point.
local SPAWN_CLUSTER_RADIUS_PX = 48
local SPAWN_CLUSTER_LIMIT = 6
local SPAWN_DOT_SIZE = 8
local SPAWN_RING_FILE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\SpawnRing"
local LIVE_SNAP_GAP = 0.5
local GAMEPAD_PIN_DISTANCE_SQUARED = 12 * 12
-- Normalized map units. Morin Cloudstalker's patrol is ~0.12 from village to crate.
local LIVE_NEAR = 0.20

-- Extra static ends of known patrols. The export stores one coord (usually the village).
-- Morin Cloudstalker (2988) walks Bloodhoof 54.4,60.4 ↔ crate 53.8,48.3.
local PATROL_EXTRA = {
    [2988] = {
        { mapID = 1412, x = 53.8, y = 48.3 },
    },
}

local pool = {}
local active = {}
local refreshGeneration = 0
local refreshJob
-- Yield by elapsed script time and item count to keep each frame responsive.
local MAX_REFRESH_ITEMS_PER_FRAME = 150
local REFRESH_BUDGET_FRACTION = 0.30
local MAX_REFRESH_BUDGET_MS = 5.0
local PIN_FADE_ENABLED = true
local PIN_FADE_DURATION = 0.18
local hoveredPin
local gamepadTooltip
local gamepadTooltipPin
local gamepadHoverAccum = 0
local activeCursorInput = "mouse"
local lastMouseX, lastMouseY
local liveAccum = 0
local stitchedPins = false
local ReprojectStitchedPins
local canvasCache
local canvasCacheName
local lastStatus = {
    viewedMap = nil,
    count = 0,
    mode = "none",
    lastError = nil,
    icon = nil,
    parent = nil,
    paintedIDs = {},
    cloudCount = 0,
    managed = 0,
}

local function IsGamepadUIEnabled()
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() or false
end

local function IsGamepadCursorVisible()
    return IsGamepadUIEnabled() and SoftCursor and SoftCursor.IsShown and SoftCursor:IsShown() or false
end

local function ReturnNoPinCenter()
    return nil
end

local function HidePinFromGamepadCursor(pin)
    if not pin._fqpGetCenter then
        pin._fqpGetCenter = pin.GetCenter
    end
    pin.GetCenter = ReturnNoPinCenter
end

local BLIZZARD_PIN_TEMPLATES = {
    "GroupMembersPinTemplate",
    "WorldMapUnitPinTemplate",
    "QuestPinTemplate",
    "AreaPOIPinTemplate",
    "DungeonEntrancePinTemplate",
    "FlightPointPinTemplate",
    "WaypointLocationPinTemplate",
    "MapHighlightPinTemplate",
}

local function Norm(x, y)
    if not x or not y then
        return nil, nil
    end
    if x > 1 or y > 1 then
        return x / 100, y / 100
    end
    return x, y
end

local function IsOpenMapStitched()
    return OpenMapAPI and OpenMapAPI.IsStitched and OpenMapAPI.WorldFromMap
        and OpenMapAPI.MapFromWorld and OpenMapAPI.IsStitched() or false
end

local function InvalidateCanvas()
    canvasCache = nil
    canvasCacheName = nil
end

local function AcceptCanvas(frame, name)
    if not frame then
        return nil
    end
    lastStatus.parent = name
    if frame.GetWidth and (frame:GetWidth() or 0) >= 1 then
        canvasCache = frame
        canvasCacheName = name
    end
    return frame
end

-- Same parent Blizzard uses for the player arrow / quest pins. Never the
-- ScrollContainer viewport: that is window-pixel space and drifts on resize.
local function CanvasFromBlizzardPins()
    if not (WorldMapFrame and WorldMapFrame.EnumeratePinsByTemplate) then
        return nil
    end
    for i = 1, #BLIZZARD_PIN_TEMPLATES do
        local template = BLIZZARD_PIN_TEMPLATES[i]
        local found
        local ok = pcall(function()
            for pin in WorldMapFrame:EnumeratePinsByTemplate(template) do
                local parent = pin and pin.GetParent and pin:GetParent()
                if parent then
                    found = parent
                    break
                end
            end
        end)
        if ok and found then
            return AcceptCanvas(found, "blizzard:" .. template)
        end
    end
    return nil
end

local function IsUsableCanvas(frame)
    if not frame or not WorldMapFrame then
        return false
    end
    -- The map art, never the window or the scroll viewport. Those stretch with
    -- the quest-log layout so north-edge pins (A Sacred Burial) vanish unless
    -- the map is maximized.
    if frame == WorldMapFrame then
        return false
    end
    local scroll = WorldMapFrame.ScrollContainer
    if scroll and frame == scroll and scroll.Child then
        return false
    end
    return true
end

local function GetCanvas()
    if canvasCache and canvasCache.GetWidth and (canvasCache:GetWidth() or 0) >= 1 and IsUsableCanvas(canvasCache) then
        lastStatus.parent = canvasCacheName
        return canvasCache
    end
    lastStatus.parent = nil
    if not WorldMapFrame then
        return nil
    end
    if WorldMapFrame.GetCanvas then
        local canvas = WorldMapFrame:GetCanvas()
        if IsUsableCanvas(canvas) then
            return AcceptCanvas(canvas, "WorldMapFrame:GetCanvas")
        end
    end
    local scroll = WorldMapFrame.ScrollContainer
    if scroll then
        if IsUsableCanvas(scroll.Child) then
            return AcceptCanvas(scroll.Child, "ScrollContainer.Child")
        end
        if scroll.GetCanvas then
            local canvas = scroll:GetCanvas()
            if IsUsableCanvas(canvas) then
                return AcceptCanvas(canvas, "ScrollContainer:GetCanvas")
            end
        end
    end
    local blizzard = CanvasFromBlizzardPins()
    if blizzard and IsUsableCanvas(blizzard) then
        return blizzard
    end
    if IsUsableCanvas(WorldMapDetailFrame) then
        return AcceptCanvas(WorldMapDetailFrame, "WorldMapDetailFrame")
    end
    if IsUsableCanvas(WorldMapButton) then
        return AcceptCanvas(WorldMapButton, "WorldMapButton")
    end
    return nil
end

function ns.GetViewedMapID()
    if WorldMapFrame and WorldMapFrame.GetMapID then
        local mapID = WorldMapFrame:GetMapID()
        if mapID then
            return mapID
        end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

-- Project 0-100 coordinates onto the currently viewed UiMapID.
-- Needs C_Map.GetMapRectOnMap for continent / parent maps. If that API is
-- missing, pins only appear when the viewed map equals the quest map.
function ns.ProjectToViewedMap(questMapID, x, y, viewedMapID)
    local nx, ny = Norm(x, y)
    if not nx or not ny or not questMapID or not viewedMapID then
        return nil, nil
    end
    if IsOpenMapStitched() then
        local u, v = OpenMapAPI.WorldFromMap(questMapID, nx, ny)
        if u and v then
            return OpenMapAPI.MapFromWorld(viewedMapID, u, v)
        end
        return nil, nil
    end
    if questMapID == viewedMapID then
        return nx, ny
    end
    if not (C_Map and C_Map.GetMapRectOnMap) then
        return nil, nil
    end
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(questMapID, viewedMapID)
    if not minX or (minX == 0 and maxX == 0 and minY == 0 and maxY == 0) then
        return nil, nil
    end
    return minX + ((maxX - minX) * nx), minY + ((maxY - minY) * ny)
end

local function TrySetAtlas(tex, name)
    if not tex or not tex.SetAtlas or not name then
        return false
    end
    local ok = pcall(function()
        tex:SetAtlas(name, false)
        if tex.SetDrawLayer then
            tex:SetDrawLayer("OVERLAY", 7)
        end
        if tex.SetBlendMode then
            pcall(tex.SetBlendMode, tex, "BLEND")
        end
        if tex.SetDesaturated then
            pcall(tex.SetDesaturated, tex, false)
        end
        if tex.SetVertexColor then
            tex:SetVertexColor(1, 1, 1, 1)
        end
        if tex.SetAlpha then
            tex:SetAlpha(1)
        end
        if tex.SetAllPoints then
            tex:SetAllPoints()
        end
        tex:Show()
    end)
    return ok and true or false
end

local function TrySetTintedAtlas(tex, name, red, green, blue)
    if not tex or not tex.SetDesaturated or not tex.SetVertexColor then
        return false
    end
    if not TrySetAtlas(tex, name) then
        return false
    end
    local ok = pcall(function()
        tex:SetDesaturated(true)
        tex:SetVertexColor(red, green, blue, 1)
    end)
    return ok and true or false
end

local function TrySetFile(tex, path)
    if not tex or not tex.SetTexture or not path then
        return false
    end
    local ok = pcall(function()
        if tex.SetDrawLayer then
            tex:SetDrawLayer("OVERLAY", 7)
        end
        if tex.SetBlendMode then
            pcall(tex.SetBlendMode, tex, "BLEND")
        end
        if tex.SetTexCoord then
            tex:SetTexCoord(0, 1, 0, 1)
        end
        tex:SetTexture(path)
        if tex.SetDesaturated then
            pcall(tex.SetDesaturated, tex, false)
        end
        if tex.SetVertexColor then
            tex:SetVertexColor(1, 1, 1, 1)
        end
        if tex.SetAlpha then
            tex:SetAlpha(1)
        end
        if tex.SetAllPoints then
            tex:SetAllPoints()
        end
        tex:Show()
    end)
    return ok and true or false
end

local function IsRepeatableOnly(pin)
    local quests = pin.quests
    if quests and #quests > 0 then
        for i = 1, #quests do
            local data = quests[i].data
            if not data or not data.repeatable then
                return false
            end
        end
        return true
    end
    return pin.data and pin.data.repeatable or false
end

local function IsInstanceOnly(pin)
    local quests = pin.quests
    if quests and #quests > 0 then
        for i = 1, #quests do
            local quest = quests[i]
            if not ns.IsInstanceQuest(quest.id, quest.data) then
                return false
            end
        end
        return true
    end
    return ns.IsInstanceQuest(pin.questID, pin.data)
end

local function HasClassRestriction(data)
    return data and data.classes and #data.classes > 0
end

local function IsClassOnly(pin)
    local quests = pin.quests
    if quests and #quests > 0 then
        for i = 1, #quests do
            if not HasClassRestriction(quests[i].data) then
                return false
            end
        end
        return true
    end
    return HasClassRestriction(pin.data)
end

local function IsProfessionOnly(pin)
    local quests = pin.quests
    if quests and #quests > 0 then
        for i = 1, #quests do
            local data = quests[i].data
            if not data or not data.requireSkill then
                return false
            end
        end
        return true
    end
    return pin.data and pin.data.requireSkill and true or false
end

local function PlayerClassFile()
    local _, classFile = UnitClass("player")
    if type(classFile) == "string" and classFile ~= "" then
        return classFile
    end
    return nil
end

local function PlayerClassRGB()
    local classFile = PlayerClassFile()
    if not classFile then
        return nil
    end
    if C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classFile)
        if color then
            if color.GetRGB then
                return color:GetRGB()
            end
            if color.r then
                return color.r, color.g, color.b
            end
        end
    end
    local colors = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if colors and colors.r then
        return colors.r, colors.g, colors.b
    end
    return nil
end

-- Rogue yellow matches normal quest gold too closely; a 1px dark bang
-- under the class tint reads as a shadowed mark instead.
local function ShowRoguePinShadow(fill, pin)
    if not fill or not pin then
        return false
    end
    if not TrySetTintedAtlas(fill, NORMAL_ICON_ATLAS, 0.06, 0.06, 0.06) then
        return false
    end
    if fill.ClearAllPoints and fill.SetPoint then
        fill:ClearAllPoints()
        fill:SetPoint("TOPLEFT", pin, "TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 1, -1)
    end
    if fill.Show then
        fill:Show()
    end
    return true
end

local function EnsurePinTextures(pin)
    if not pin.Fill then
        pin.Fill = pin:CreateTexture(nil, "ARTWORK")
        pin.Fill:SetAllPoints()
    end
    if not pin.Texture then
        pin.Texture = pin:CreateTexture(nil, "OVERLAY")
        pin.Texture:SetAllPoints()
    end
    return pin.Fill, pin.Texture
end

local cloudDots = {}
local cloudOwner

local function HideSpawnCloud()
    for i = 1, #cloudDots do
        cloudDots[i]:Hide()
    end
    cloudOwner = nil
    lastStatus.cloudCount = 0
end

local function GetGamepadTooltip()
    if not gamepadTooltip then
        gamepadTooltip = CreateFrame("GameTooltip", "ForeverQuestPinsGamepadTooltip", UIParent, "GameTooltipTemplate")
        if gamepadTooltip.SetFrameStrata then
            gamepadTooltip:SetFrameStrata("TOOLTIP")
        end
    end
    if gamepadTooltip.SetScale and GameTooltip and GameTooltip.GetScale then
        gamepadTooltip:SetScale(GameTooltip:GetScale())
    end
    return gamepadTooltip
end

local function HideGamepadTooltip()
    if gamepadTooltip then
        gamepadTooltip:Hide()
    end
    gamepadTooltipPin = nil
end

-- Dots live on UIParent above the map but below tooltips, and they are placed
-- in screen units.
local function SpawnCloudDot(index)
    local dot = cloudDots[index]
    if dot then
        return dot
    end
    dot = CreateFrame("Frame", nil, UIParent)
    dot:SetFrameStrata("FULLSCREEN_DIALOG")
    dot:SetSize(SPAWN_DOT_SIZE, SPAWN_DOT_SIZE)
    local tex = dot:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(dot)
    tex:SetTexture(SPAWN_RING_FILE)
    cloudDots[index] = dot
    return dot
end

local function ShowSpawnCloud(pin)
    HideSpawnCloud()
    if not pin or not ns.GetOption("showSpawnClusters") then
        return
    end
    local points = pin.spawnPoints
    if not points or #points < 2 or not pin.nx or not pin.ny then
        return
    end
    local canvas = GetCanvas()
    if not canvas or not canvas.GetWidth or not canvas.GetHeight or not pin._fqpGetCenter then
        return
    end
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    local centerX, centerY = pin._fqpGetCenter(pin)
    if not width or not height or width < 1 or height < 1 or not centerX or not centerY then
        return
    end
    -- Canvas pixels to UIParent units: the canvas and UIParent may each carry
    -- their own scale.
    local uiScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local canvasScale = canvas.GetEffectiveScale and canvas:GetEffectiveScale() or 1
    local pinScale = pin.GetEffectiveScale and pin:GetEffectiveScale() or 1
    if not uiScale or uiScale <= 0 or not canvasScale or canvasScale <= 0 or not pinScale or pinScale <= 0 then
        return
    end
    centerX, centerY = centerX * pinScale / uiScale, centerY * pinScale / uiScale
    local unitsPerCanvasPixel = canvasScale / uiScale
    local shown = 0
    for i = 1, #points do
        local point = points[i]
        if point.nx and point.ny then
            -- Map y grows downward; screen y grows upward.
            local x = centerX + (point.nx - pin.nx) * width * unitsPerCanvasPixel
            local y = centerY - (point.ny - pin.ny) * height * unitsPerCanvasPixel
            local dot = SpawnCloudDot(i)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
            dot:Show()
            shown = shown + 1
        end
    end
    cloudOwner = pin
    lastStatus.cloudCount = shown
end

local function HasForeverNewQuest(pin)
    if not ns.IsForeverNewQuest then
        return false
    end
    local quests = pin.quests
    if quests and #quests > 0 then
        for i = 1, #quests do
            if ns.IsForeverNewQuest(quests[i].id) then
                return true
            end
        end
        return false
    end
    return ns.IsForeverNewQuest(pin.questID)
end

local function PlainYellowArt(pin)
    if pin.icon == "atlas:" .. NORMAL_ICON_ATLAS then
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(NORMAL_ICON_ATLAS)
        if info then
            return info.file or info.filename, info.leftTexCoord, info.rightTexCoord, info.topTexCoord,
                info.bottomTexCoord
        end
    elseif pin.icon == "QuestAvailable.tga" then
        return NORMAL_ICON_FILE, 0, 1, 0, 1
    end
    return nil
end

local function ApplyForeverGradient(pin)
    local tex = pin.Texture
    local file, l, r, t, b
    if tex and ns.GetOption("highlightNewQuests") and HasForeverNewQuest(pin) then
        file, l, r, t, b = PlainYellowArt(pin)
    end
    local solid, fade = pin.ForeverSolid, pin.ForeverFade
    if not file or not CreateColor then
        if solid then
            solid:Hide()
            fade:Hide()
        end
        return
    end
    if not solid then
        solid = pin:CreateTexture(nil, "OVERLAY", nil, 7)
        fade = pin:CreateTexture(nil, "OVERLAY", nil, 7)
        pin.ForeverSolid, pin.ForeverFade = solid, fade
        pin.ForeverColors = {
            CreateColor(FOREVER_TINT_R, FOREVER_TINT_G, FOREVER_TINT_B, 1),
            CreateColor(FOREVER_TINT_R, FOREVER_TINT_G, FOREVER_TINT_B, 0),
        }
    end
    -- The icon drops one sublevel so the copy always draws over it.
    tex:SetDrawLayer("OVERLAY", 6)
    local height = pin:GetHeight()
    if not height or height <= 0 then
        height = PIN_SIZE
    end
    local opaque, clear = pin.ForeverColors[1], pin.ForeverColors[2]
    local function slice(piece, from, to, low, high)
        piece:ClearAllPoints()
        piece:SetPoint("BOTTOMLEFT", pin, "BOTTOMLEFT", 0, height * from)
        piece:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 0, height * from)
        piece:SetHeight(height * (to - from))
        piece:SetTexture(file)
        piece:SetTexCoord(l, r, b + (t - b) * to, b + (t - b) * from)
        piece:SetDesaturated(true)
        piece:SetGradient("VERTICAL", low, high)
        piece:Show()
    end
    slice(solid, 0, FOREVER_SOLID, opaque, opaque)
    slice(fade, FOREVER_SOLID, FOREVER_FADE, opaque, clear)
end

local function PaintPinIcon(pin)
    local fill, tex = EnsurePinTextures(pin)
    if not tex then
        lastStatus.icon = "none"
        pin.icon = "none"
        return
    end
    if fill then
        if fill.SetAllPoints then
            fill:SetAllPoints()
        end
        if fill.Hide then
            fill:Hide()
        end
    end
    if tex.Hide then
        tex:Hide()
    end
    -- Priority: instance > class > profession > repeatable > normal.
    -- Mixed stacks stay on the first matching uniform type, else yellow.
    local instanceQuest = IsInstanceOnly(pin)
    local classQuest = not instanceQuest and IsClassOnly(pin)
    local profession = not instanceQuest and not classQuest and IsProfessionOnly(pin)
    local repeatable = not instanceQuest and not classQuest and not profession and IsRepeatableOnly(pin)
    local fallbackFile = NORMAL_ICON_FILE
    local fallbackName = "QuestAvailable.tga"
    if instanceQuest then
        fallbackFile = INSTANCE_ICON_FILE
        fallbackName = "QuestAttunement.tga"
    elseif repeatable then
        fallbackFile = REPEATABLE_ICON_FILE
        fallbackName = "QuestRepeatable.tga"
    end

    local hasFallback = false
    if instanceQuest then
        if TrySetTintedAtlas(tex, NORMAL_ICON_ATLAS, 1.00, 0.32, 0.08) then
            pin.icon = "atlas:" .. NORMAL_ICON_ATLAS .. ":orange" .. (hasFallback and "+fallback" or "")
            lastStatus.icon = pin.icon
            return
        end
        if TrySetFile(tex, fallbackFile) then
            pin.icon = fallbackName
            lastStatus.icon = pin.icon
            return
        end
        if TrySetAtlas(tex, NORMAL_ICON_ATLAS) then
            pin.icon = "atlas:" .. NORMAL_ICON_ATLAS
            lastStatus.icon = pin.icon
            return
        end
    elseif classQuest then
        local r, g, b = PlayerClassRGB()
        local painted = false
        if r and TrySetTintedAtlas(tex, NORMAL_ICON_ATLAS, r, g, b) then
            pin.icon = "atlas:" .. NORMAL_ICON_ATLAS .. ":class" .. (hasFallback and "+fallback" or "")
            painted = true
        elseif TrySetAtlas(tex, NORMAL_ICON_ATLAS) then
            pin.icon = "atlas:" .. NORMAL_ICON_ATLAS
            painted = true
        elseif TrySetFile(tex, fallbackFile) then
            pin.icon = fallbackName
            painted = true
        end
        if painted then
            if PlayerClassFile() == "ROGUE" and ShowRoguePinShadow(fill, pin) then
                pin.icon = pin.icon .. "+shadow"
            end
            lastStatus.icon = pin.icon
            return
        end
    elseif profession then
        if TrySetTintedAtlas(tex, NORMAL_ICON_ATLAS, PROFESSION_PIN_R, PROFESSION_PIN_G, PROFESSION_PIN_B) then
            pin.icon = "atlas:" .. NORMAL_ICON_ATLAS .. ":copper" .. (hasFallback and "+fallback" or "")
            lastStatus.icon = pin.icon
            return
        end
        if TrySetAtlas(tex, NORMAL_ICON_ATLAS) then
            pin.icon = "atlas:" .. NORMAL_ICON_ATLAS
            lastStatus.icon = pin.icon
            return
        end
        if TrySetFile(tex, fallbackFile) then
            pin.icon = fallbackName
            lastStatus.icon = pin.icon
            return
        end
    elseif repeatable then
        if TrySetTintedAtlas(tex, NORMAL_ICON_ATLAS, 0.12, 0.72, 1.00) then
            pin.icon = "atlas:" .. NORMAL_ICON_ATLAS .. ":blue" .. (hasFallback and "+fallback" or "")
            lastStatus.icon = pin.icon
            return
        end
        if TrySetFile(tex, fallbackFile) then
            pin.icon = fallbackName
            lastStatus.icon = pin.icon
            return
        end
        if TrySetAtlas(tex, REPEATABLE_ICON_ATLAS) then
            pin.icon = "atlas:" .. REPEATABLE_ICON_ATLAS
            lastStatus.icon = pin.icon
            return
        end
    else
        if TrySetAtlas(tex, NORMAL_ICON_ATLAS) then
            pin.icon = "atlas:" .. NORMAL_ICON_ATLAS .. (hasFallback and "+fallback" or "")
            lastStatus.icon = pin.icon
            return
        end
        if TrySetFile(tex, fallbackFile) then
            pin.icon = fallbackName
            lastStatus.icon = pin.icon
            return
        end
    end
    pin.icon = "none"
    lastStatus.icon = "none"
end

local function SetPinTexture(pin)
    PaintPinIcon(pin)
    ApplyForeverGradient(pin)
end

local function ReleasePin(pin)
    if cloudOwner == pin then
        HideSpawnCloud()
    end
    if pin.managed then
        local map = pin.GetMap and pin:GetMap()
        if map and map.RemovePin then
            map:RemovePin(pin)
        elseif WorldMapFrame and WorldMapFrame.RemovePin then
            pcall(WorldMapFrame.RemovePin, WorldMapFrame, pin)
        elseif pin.Hide then
            pin:Hide()
        end
        pin.quests, pin.questID, pin.data = nil, nil, nil
        pin.spawnPoints, pin.spawnCount, pin.anchor = nil, nil, nil
        return
    end
    pin:Hide()
    pin:ClearAllPoints()
    pin.questID = nil
    pin.data = nil
    pin.reason = nil
    pin.nx = nil
    pin.ny = nil
    pin.attNx = nil
    pin.attNy = nil
    pin.live = nil
    pin.titleReady = nil
    pin._fqpFadeElapsed = nil
    pin.quests = nil
    pin.icon = nil
    pin.spawnPoints = nil
    pin.spawnCount = nil
    pin.anchor = nil
    pool[#pool + 1] = pin
end

function MapPins:CancelPendingRefresh()
    refreshGeneration = refreshGeneration + 1
    refreshJob = nil
end

function MapPins:Clear()
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    HideSpawnCloud()
    if hoveredPin then
        hoveredPin = nil
    end
    HideGamepadTooltip()
    for i = 1, #active do
        ReleasePin(active[i])
    end
    wipe(active)
    lastStatus.count = 0
    lastStatus.paintedIDs = {}
    return true
end

local function QuestGiverID(data)
    if not data then
        return nil
    end
    if data.qg then
        return data.qg
    end
    if data.qgs then
        return data.qgs[1]
    end
    return nil
end

local function QuestLineText(questID)
    local title = ns.GetQuestTitle(questID)
    local level = ns.GetQuestDifficultyLevel and ns.GetQuestDifficultyLevel(questID)
    if title and level then
        return ("[%d] %s"):format(level, title), level
    end
    return title, level
end

local function QuestLineColor(level)
    if ns.GetQuestDifficultyRGB then
        return ns.GetQuestDifficultyRGB(level)
    end
    return 1, 0.82, 0
end

local function PinTrackingEnabled()
    if ns.GetOption("enablePinTracking") == false then return false end
    if ns.GetOption("trackOnWorldMaps") then return true end
    local mapID = ns.GetViewedMapID()
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if not info or not info.mapType then return false end
    local types = Enum and Enum.UIMapType
    return info.mapType ~= (types and types.World or 1)
        and info.mapType ~= (types and types.Continent or 2)
end

local function ShowTooltip(pin, tooltip)
    if not pin.questID and not (pin.quests and pin.quests[1]) then
        return
    end
    tooltip = tooltip or GameTooltip
    if tooltip == gamepadTooltip then
        gamepadTooltipPin = pin
    end
    hoveredPin = pin
    ShowSpawnCloud(pin)
    local quests = pin.quests
    if not quests or #quests == 0 then
        quests = { { id = pin.questID, data = pin.data, reason = pin.reason } }
    end
    for i = 1, #quests do
        ns.PrefetchQuestInfo(quests[i].id, quests[i].data)
    end
    tooltip:SetOwner(pin, "ANCHOR_RIGHT")
    local debugOn = ns.GetOption("debug")
    local primaryText, primaryLevel = QuestLineText(quests[1].id)
    local pr, pg, pb = QuestLineColor(primaryLevel)
    if primaryText then
        tooltip:SetText(primaryText, pr, pg, pb)
    elseif debugOn then
        tooltip:SetText(L["Quest "] .. tostring(quests[1].id), 1, 0.82, 0)
    else
        tooltip:SetText(L["Quest"], 1, 0.82, 0)
    end
    for i = 2, #quests do
        local extraText, extraLevel = QuestLineText(quests[i].id)
        if extraText then
            local r, g, b = QuestLineColor(extraLevel)
            tooltip:AddLine(extraText, r, g, b)
        elseif debugOn then
            tooltip:AddLine(L["Quest "] .. tostring(quests[i].id), 1, 0.82, 0)
        end
    end
    local qg = QuestGiverID(quests[1].data or pin.data)
    local npcName = qg and ns.GetNPCName(qg) or nil
    if npcName then
        tooltip:AddLine(npcName, 1, 1, 1)
    elseif debugOn and qg then
        tooltip:AddLine(L["Quest giver NPC "] .. tostring(qg), 0.8, 0.8, 0.8)
    end
    if pin.spawnCount and pin.spawnCount > 1 then
        tooltip:AddLine((L["%d possible spawn locations"]):format(pin.spawnCount), 0.8, 0.8, 0.8)
    end
    if debugOn then
        tooltip:AddLine(" ")
        tooltip:AddLine("Debug", 0.4, 0.8, 1)
        for i = 1, #quests do
            tooltip:AddLine("Quest ID: " .. tostring(quests[i].id), 0.6, 0.8, 1)
        end
        if qg then
            tooltip:AddLine("NPC ID: " .. tostring(qg), 0.6, 0.8, 1)
        end
        tooltip:AddLine("reason: " .. tostring(pin.reason or "?"), 0.6, 0.8, 1)
        tooltip:AddLine("parent: " .. tostring(lastStatus.parent or "?"), 0.6, 0.8, 1)
        tooltip:AddLine("icon: " .. tostring(pin.icon or "?"), 0.6, 0.8, 1)
        tooltip:AddLine("spawn points: " .. tostring(pin.spawnCount or 0), 0.6, 0.8, 1)
        if pin.live then
            tooltip:AddLine("position: live NPC", 0.6, 0.8, 1)
        end
        local data = pin.data
        if data then
            for _, entry in ipairs({
                { "sourceQuestGroup", data.sourceQuestGroup },
                { "sourceQuestSingle", data.sourceQuestSingle },
                { "sourceQuests", data.sourceQuests },
            }) do
                local list = entry[2]
                if list and #list > 0 then
                    local parts = {}
                    for i = 1, #list do
                        parts[i] = tostring(list[i])
                    end
                    tooltip:AddLine(entry[1] .. ": " .. table.concat(parts, ", "), 0.6, 0.8, 1)
                end
            end
            if data.faction then
                tooltip:AddLine("faction: " .. tostring(data.faction), 0.6, 0.8, 1)
            end
            if data.minLevel then
                tooltip:AddLine("minLevel: " .. tostring(data.minLevel), 0.6, 0.8, 1)
            end
            tooltip:AddLine(("map %s @ %.1f, %.1f"):format(tostring(data.mapID), data.x or 0, data.y or 0), 0.6, 0.8, 1)
        end
        if pin.nx and pin.ny then
            tooltip:AddLine(("normalized %.3f, %.3f"):format(pin.nx, pin.ny), 0.6, 0.8, 1)
        end
    end
    if PinTrackingEnabled() then
        tooltip:AddLine(L["Click to track this quest start."], 1, 1, 1)
        tooltip:AddLine(L["Shift-click to hide this marker."], 0.7, 0.7, 0.7)
    end
    tooltip:Show()
end

local function FindPinAtCursor(cursorX, cursorY, normalized)
    if not cursorX or not cursorY then
        return nil
    end
    local canvas = normalized and GetCanvas() or nil
    if normalized and (not canvas or not canvas.GetWidth or not canvas.GetHeight) then
        return nil
    end
    local closestPin, closestDistance
    for i = 1, #active do
        local pin = active[i]
        local getCenter = pin._fqpGetCenter
        if getCenter and pin.IsShown and pin:IsShown() and pin.questID then
            local pinX, pinY
            local radiusX, radiusY
            if normalized and pin.nx and pin.ny then
                pinX = (pin.nx - cursorX) * canvas:GetWidth()
                pinY = (pin.ny - cursorY) * canvas:GetHeight()
                local scale = pin.GetScale and pin:GetScale() or 1
                radiusX = (pin.GetWidth and pin:GetWidth() or PIN_SIZE) * scale * 0.5
                radiusY = (pin.GetHeight and pin:GetHeight() or PIN_SIZE) * scale * 0.5
            else
                local centerX, centerY = getCenter(pin)
                pinX, pinY = centerX and centerX - cursorX, centerY and centerY - cursorY
                radiusX, radiusY = math.sqrt(GAMEPAD_PIN_DISTANCE_SQUARED), math.sqrt(GAMEPAD_PIN_DISTANCE_SQUARED)
            end
            if pinX and pinY and radiusX and radiusY then
                local distance = pinX * pinX + pinY * pinY
                if math.abs(pinX) <= radiusX and math.abs(pinY) <= radiusY
                    and (not closestDistance or distance < closestDistance) then
                    closestPin, closestDistance = pin, distance
                end
            end
        end
    end
    return closestPin
end

local function UpdateActiveCursorInput()
    if not IsGamepadUIEnabled() then
        activeCursorInput = "mouse"
        return
    end
    local mouseX, mouseY
    if GetCursorPosition then
        mouseX, mouseY = GetCursorPosition()
    end
    local mouseMoved = mouseX and mouseY and (mouseX ~= lastMouseX or mouseY ~= lastMouseY)
    local buttonDown = IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
    lastMouseX, lastMouseY = mouseX, mouseY
    if SoftCursor and SoftCursor.IsMoving and SoftCursor:IsMoving() then
        activeCursorInput = "gamepad"
    elseif mouseMoved and buttonDown then
        activeCursorInput = "gamepad"
    elseif mouseMoved then
        activeCursorInput = "mouse"
    end
end

function MapPins:FindGamepadCursorPin()
    local scroll = WorldMapFrame and WorldMapFrame.ScrollContainer
    -- This is the same map-relative cursor used by Blizzard and Leatrix Maps.
    if WorldMapFrame and WorldMapFrame.GetNormalizedGamepadCursorPosition then
        local cursorX, cursorY = WorldMapFrame:GetNormalizedGamepadCursorPosition()
        if cursorX ~= nil and cursorY ~= nil then
            return FindPinAtCursor(cursorX, cursorY, true)
        end
    end
    if scroll and scroll.GetNormalizedGamepadCursorPosition then
        local cursorX, cursorY = scroll:GetNormalizedGamepadCursorPosition()
        if cursorX ~= nil and cursorY ~= nil then
            return FindPinAtCursor(cursorX, cursorY, true)
        end
    end
    -- Older clients may expose only screen coordinates through SoftCursor.
    if not (SoftCursor and SoftCursor.IsShown and SoftCursor:IsShown()) then
        return nil
    end
    local cursorX, cursorY
    if SoftCursor.GetCenter then
        cursorX, cursorY = SoftCursor:GetCenter()
    end
    if (not cursorX or not cursorY) and scroll and scroll.GetGamepadCursorPosition then
        cursorX, cursorY = scroll:GetGamepadCursorPosition()
    end
    return FindPinAtCursor(cursorX, cursorY, false)
end

function MapPins:FindMouseCursorPin()
    local scroll = WorldMapFrame and WorldMapFrame.ScrollContainer
    if not (WorldMapFrame and WorldMapFrame.GetNormalizedCursorPosition
        and scroll and scroll.IsMouseOver and scroll:IsMouseOver()) then
        return nil
    end
    local cursorX, cursorY = WorldMapFrame:GetNormalizedCursorPosition()
    return FindPinAtCursor(cursorX, cursorY, true)
end

function MapPins:UpdateGamepadHover()
    UpdateActiveCursorInput()
    local gamepadPin = MapPins:FindGamepadCursorPin()
    local mousePin = MapPins:FindMouseCursorPin()
    local pin
    if activeCursorInput == "gamepad" then
        pin = gamepadPin
    else
        pin = mousePin or gamepadPin
    end
    if pin == hoveredPin then
        if pin and IsGamepadUIEnabled() and gamepadTooltipPin ~= pin then
            ShowTooltip(pin, GetGamepadTooltip())
        end
        return
    end
    HideSpawnCloud()
    if hoveredPin then
        HideGamepadTooltip()
    end
    hoveredPin = pin
    if pin then
        ShowTooltip(pin, GetGamepadTooltip())
    end
end

local function PinQuestIDs(pin)
    local ids = {}
    local quests = pin.quests
    if quests and #quests > 0 then
        for i = 1, #quests do
            ids[#ids + 1] = quests[i].id
        end
    elseif pin.questID then
        ids[1] = pin.questID
    end
    return ids
end

local function HidePinQuests(pin)
    local count = ns.HideQuests(PinQuestIDs(pin))
    if hoveredPin == pin then
        hoveredPin = nil
    end
    HideSpawnCloud()
    GameTooltip:Hide()
    if count > 0 then
        -- Refresh is deferred in combat; hide now so the marker cannot be clicked again.
        pin:Hide()
        print((L["|cffffd100Forever Quest Pins:|r Hid %d quest(s). Use Reset hidden quest pins in options or /fqp unhide to restore."]):format(count))
    end
end

local function OnPinClick(pin, shiftDown)
    if shiftDown == nil then
        shiftDown = IsShiftKeyDown and IsShiftKeyDown() or false
    end
    if shiftDown then
        HidePinQuests(pin)
        return
    end
    if not PinTrackingEnabled() then
        return
    end
    local data = pin.data
    if pin.anchor and data then
        data = {}
        for key, value in pairs(pin.data) do
            data[key] = value
        end
        data.mapID = pin.anchor.mapID
        data.x = pin.anchor.x
        data.y = pin.anchor.y
    end
    ns.TrackQuest(pin.questID, data)
end

function MapPins:OnTitleLoaded(questID)
    if not hoveredPin then
        return
    end
    if hoveredPin.questID == questID then
        ShowTooltip(hoveredPin, IsGamepadUIEnabled() and GetGamepadTooltip() or GameTooltip)
        return
    end
    local quests = hoveredPin.quests
    if quests then
        for i = 1, #quests do
            if quests[i].id == questID then
                ShowTooltip(hoveredPin, IsGamepadUIEnabled() and GetGamepadTooltip() or GameTooltip)
                return
            end
        end
    end
end

local function IsNormalized(x, y)
    return x and y and x >= 0 and y >= 0 and x <= 1 and y <= 1 and not (x == 0 and y == 0)
end

local function GetCanvasScale(parent)
    if WorldMapFrame and WorldMapFrame.GetCanvasScale then
        local scale = WorldMapFrame:GetCanvasScale()
        if type(scale) == "number" and scale > 0 then
            return scale
        end
    end
    if parent and parent.GetScale then
        local scale = parent:GetScale()
        if type(scale) == "number" and scale > 0 then
            return scale
        end
    end
    return 1
end

local function GetPinSize()
    return PIN_SIZE * ns.GetOption("iconScale") / 100
end

local function CanvasOffsets(parent, nx, ny)
    if not parent or not nx or not ny or not parent.GetWidth then
        return nil, nil
    end
    local width = parent:GetWidth()
    local height = parent:GetHeight()
    if not width or not height or width < 1 or height < 1 then
        return nil, nil
    end
    return width * nx, -height * ny
end

local function RaisePin(pin, parent)
    parent = parent or pin:GetParent()
    if pin.UseFrameLevelType then
        pcall(pin.UseFrameLevelType, pin, "PIN_FRAME_LEVEL_AREA_POI")
    end
    local base = 0
    if parent and parent.GetFrameLevel then
        base = parent:GetFrameLevel() or 0
    end
    -- Map detail layers sit well above the canvas default; +20 was under the art
    -- so some bangs disappeared depending on zoom/layer order.
    local artLevel = IsOpenMapStitched() and OpenMapAPI.ArtTopLevel and OpenMapAPI.ArtTopLevel() or 0
    pin:SetFrameLevel(math.max(base + 400, (artLevel or 0) + 1))
    -- Keep the pin on the canvas strata. HIGH pulled pins out of the map child
    -- and they stopped compositing on Forever's world map.
    if pin.SetFrameStrata and parent and parent.GetFrameStrata then
        local strata = parent:GetFrameStrata()
        if strata then
            pcall(pin.SetFrameStrata, pin, strata)
        end
    end
end

local function ApplyPinPoint(pin, parent)
    if pin.managed then
        local pinSize = GetPinSize()
        pin:SetSize(pinSize, pinSize)
        pin:SetPosition(pin.nx, pin.ny)
        return true
    end
    parent = parent or pin:GetParent() or GetCanvas()
    local ox, oy = CanvasOffsets(parent, pin.nx, pin.ny)
    if not ox then
        return false
    end
    if parent and pin.GetParent and pin:GetParent() ~= parent then
        pin:SetParent(parent)
    end
    -- Match MapCanvas ApplyPinPosition: pin scale counters canvas zoom so the
    -- bang stays PIN_SIZE on screen in both windowed and maximized layouts.
    local canvasScale = GetCanvasScale(parent)
    local pinSize = GetPinSize()
    if pin.placedParent == parent and pin.placedX == ox and pin.placedY == oy
        and pin.placedScale == canvasScale and pin.placedSize == pinSize then
        return true
    end
    pin.placedParent, pin.placedX, pin.placedY, pin.placedScale, pin.placedSize = parent, ox, oy, canvasScale, pinSize
    if pin.SetIgnoreParentScale then
        pin:SetIgnoreParentScale(false)
    end
    pin:SetScale(1 / canvasScale)
    pin:SetSize(pinSize, pinSize)
    local pinScale = pin.GetScale and pin:GetScale() or 1
    if not pinScale or pinScale == 0 then
        pinScale = 1
    end
    RaisePin(pin, parent)
    pin:SetAlpha(1)
    pin:Show()
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", parent, "TOPLEFT", ox / pinScale, oy / pinScale)
    return true
end

function MapPins:RepositionAll()
    local canvas = GetCanvas()
    for i = 1, #active do
        ApplyPinPoint(active[i], canvas)
    end
end

ReprojectStitchedPins = function(mapID)
    local oldMap = lastStatus.viewedMap
    if not oldMap or not mapID then return false end
    if oldMap == mapID then return true end
    local u, v = OpenMapAPI.WorldFromMap(oldMap, 0.5, 0.5)
    if not u or not v or not OpenMapAPI.MapFromWorld(mapID, u, v) then return false end
    local function project(x, y)
        local u, v = OpenMapAPI.WorldFromMap(oldMap, x, y)
        if u and v then return OpenMapAPI.MapFromWorld(mapID, u, v) end
    end
    HideSpawnCloud()
    for i = 1, #active do
        local pin = active[i]
        pin.nx, pin.ny = project(pin.attNx, pin.attNy)
        pin.attNx, pin.attNy = pin.nx, pin.ny
        pin.live = nil
        if pin.SetMouseClickEnabled then pin:SetMouseClickEnabled(PinTrackingEnabled()) end
        for _, point in ipairs(pin.spawnPoints or {}) do
            point.nx, point.ny = project(point.nx, point.ny)
        end
    end
    lastStatus.viewedMap = mapID
    MapPins:RepositionAll()
    return true
end

local function AcquirePin(parent)
    -- The native gamepad cursor scans MapCanvas pins outside secure code. Use
    -- ordinary canvas children in gamepad mode and resolve hover privately.
    if not IsOpenMapStitched() and not IsGamepadUIEnabled() and MapCanvasPinMixin and WorldMapFrame and WorldMapFrame.AcquirePin then
        -- Populate the mixin lazily in case Blizzard_MapCanvas loaded after us.
        for key, value in pairs(MapCanvasPinMixin) do
            if ForeverQuestPinsMapPinMixin[key] == nil then
                ForeverQuestPinsMapPinMixin[key] = value
            end
        end
        local pin = WorldMapFrame:AcquirePin("ForeverQuestPinsMapPinTemplate")
        if pin and pin.EnableMouse then
            pin:EnableMouse(true)
            pin:SetMouseClickEnabled(PinTrackingEnabled())
        end
        return pin
    end
    local pin = table.remove(pool)
    if not pin then
        pin = CreateFrame("Button", nil, parent)
        pin:RegisterForClicks("LeftButtonUp")
        if pin.EnableMouse then
            pin:EnableMouse(true)
        end
        EnsurePinTextures(pin)
        pin:SetScript("OnClick", ForeverQuestPinsMapPinMixin.OnClick)
        pin:SetScript("OnEnter", ForeverQuestPinsMapPinMixin.OnMouseEnter)
        pin:SetScript("OnLeave", ForeverQuestPinsMapPinMixin.OnMouseLeave)
    end
    if not pin._fqpGetCenter then
        pin._fqpGetCenter = pin.GetCenter
    end
    pin:SetParent(parent)
    if pin.EnableMouse then
        pin:EnableMouse(true)
        pin:SetMouseClickEnabled(PinTrackingEnabled())
    end
    pin.placedParent = nil
    if pin.SetIgnoreParentScale then
        pin:SetIgnoreParentScale(false)
    end
    pin:SetScale(1)
    local pinSize = GetPinSize()
    pin:SetSize(pinSize, pinSize)
    RaisePin(pin, parent)
    return pin
end

ForeverQuestPinsMapPinMixin = {}

function ForeverQuestPinsMapPinMixin:OnLoad()
    self.managed = true
    HidePinFromGamepadCursor(self)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1, 1)
    self:SetSize(PIN_SIZE, PIN_SIZE)
    self.Texture:ClearAllPoints()
    self.Texture:SetAllPoints(self)
end

function ForeverQuestPinsMapPinMixin:OnAcquired()
    HidePinFromGamepadCursor(self)
    local pinSize = GetPinSize()
    self:SetSize(pinSize, pinSize)
    self:SetAlpha(1)
end

function ForeverQuestPinsMapPinMixin:OnClick(button)
    if button ~= "LeftButton" then
        return
    end
    if not PinTrackingEnabled() then
        return
    end
    if IsGamepadUIEnabled() and C_Timer and C_Timer.After then
        -- MapCanvas dispatches controller pin clicks from its input handler.
        local pin = self
        local questID, data = pin.questID, pin.data
        local shiftDown = IsShiftKeyDown and IsShiftKeyDown() or false
        C_Timer.After(0, function()
            if pin.questID == questID and pin.data == data then
                OnPinClick(pin, shiftDown)
            end
        end)
        return
    end
    OnPinClick(self)
end

function ForeverQuestPinsMapPinMixin:OnMouseEnter()
    if IsGamepadUIEnabled() then
        -- Gamepad hover is resolved by the cursor poll. MapCanvas can dispatch
        -- this event while the soft cursor is hidden, and Blizzard can suppress
        -- its shared tooltip in Gamepad UI. Defer all hover to our private tooltip.
        return
    end
    ShowTooltip(self)
end

function ForeverQuestPinsMapPinMixin:OnMouseLeave()
    if IsGamepadUIEnabled() then
        return
    end
    if hoveredPin == self then
        hoveredPin = nil
    end
    HideSpawnCloud()
    GameTooltip:Hide()
end

local function SameSpot(ax, ay, bx, by)
    if not ax or not ay or not bx or not by then
        return false
    end
    local dx = ax - bx
    local dy = ay - by
    return (dx * dx + dy * dy) < (0.002 * 0.002)
end

local function PinAlreadyListsQuest(pin, questID)
    local quests = pin.quests
    if quests then
        for i = 1, #quests do
            if quests[i].id == questID then
                return true
            end
        end
    end
    return pin.questID == questID
end

local function AppendSpawnPoints(pin, spawnPoints)
    pin.spawnPoints = pin.spawnPoints or {}
    for i = 1, #spawnPoints do
        pin.spawnPoints[#pin.spawnPoints + 1] = spawnPoints[i]
    end
    pin.spawnCount = #pin.spawnPoints
end

local function GetRefreshBudgetMS()
    local frameRate = GetFramerate and GetFramerate()
    if type(frameRate) == "number" and frameRate > 0 then
        return math.min(MAX_REFRESH_BUDGET_MS, (1000 / frameRate) * REFRESH_BUDGET_FRACTION)
    end
    return MAX_REFRESH_BUDGET_MS
end

local function StartPinFade(pin)
    if not PIN_FADE_ENABLED then
        pin._fqpFadeElapsed = nil
        pin:SetAlpha(1)
        return
    end
    pin._fqpFadeElapsed = 0
    pin:SetAlpha(0)
end

local function UpdatePinFades(elapsed)
    for i = 1, #active do
        local pin = active[i]
        if pin._fqpFadeElapsed then
            pin._fqpFadeElapsed = pin._fqpFadeElapsed + elapsed
            local alpha = pin._fqpFadeElapsed / PIN_FADE_DURATION
            if alpha >= 1 then
                pin._fqpFadeElapsed = nil
                alpha = 1
            end
            pin:SetAlpha(alpha)
        end
    end
end

local function PlacePin(parent, nx, ny, questID, data, reason, live, spawnPoints, anchor)
    if not spawnPoints then
        spawnPoints = { {
            nx = nx,
            ny = ny,
            mapID = data and data.mapID,
            x = data and data.x,
            y = data and data.y,
        } }
    end
    for i = 1, #active do
        local existing = active[i]
        if SameSpot(existing.nx, existing.ny, nx, ny) then
            existing.quests = existing.quests or { { id = existing.questID, data = existing.data, reason = existing.reason } }
            local alreadyListed = PinAlreadyListsQuest(existing, questID)
            if not alreadyListed then
                existing.quests[#existing.quests + 1] = { id = questID, data = data, reason = reason }
            else
                -- A stacked pin keeps the first quest's count and cloud. Summing
                -- another quest's points would misreport both quests.
                AppendSpawnPoints(existing, spawnPoints)
            end
            SetPinTexture(existing)
            ns.PrefetchQuestInfo(questID, data)
            return true
        end
    end
    local pin = AcquirePin(parent)
    pin.questID = questID
    pin.data = data
    pin.reason = reason
    pin.nx = nx
    pin.ny = ny
    pin.attNx = nx
    pin.attNy = ny
    pin.live = live and true or nil
    pin.quests = { { id = questID, data = data, reason = reason } }
    local _, titleReady = ns.GetQuestTitle(questID)
    pin.titleReady = titleReady
    pin.anchor = anchor or spawnPoints[1]
    AppendSpawnPoints(pin, spawnPoints)
    SetPinTexture(pin)
    ApplyPinPoint(pin, parent)
    pin:Show()
    StartPinFade(pin)
    active[#active + 1] = pin
    ns.PrefetchQuestInfo(questID, data)
    return true
end

local function CandidateMapIDs(viewedMapID, byMap)
    local maps = {}
    local seen = {}
    local function add(mapID)
        if mapID and not seen[mapID] then
            seen[mapID] = true
            maps[#maps + 1] = mapID
        end
    end
    add(viewedMapID)
    if C_Map and C_Map.GetMapChildrenInfo then
        local children = C_Map.GetMapChildrenInfo(viewedMapID, nil, true)
        if type(children) == "table" then
            for i = 1, #children do
                local info = children[i]
                local childID = type(info) == "table" and (info.mapID or info[1]) or info
                add(childID)
            end
        end
    end
    -- Continent / parent views: try every known quest map and let
    -- ProjectToViewedMap drop maps that do not belong on this canvas.
    if type(byMap) == "table" then
        for mapID in pairs(byMap) do
            add(mapID)
        end
    end
    return maps
end

local function EachCoord(data, fn)
    local seen = {}
    local function emit(mapID, x, y)
        if not mapID or not x or not y then
            return
        end
        local key = tostring(mapID) .. ":" .. tostring(x) .. ":" .. tostring(y)
        if seen[key] then
            return
        end
        seen[key] = true
        fn(mapID, x, y)
    end
    if data.coords then
        for i = 1, #data.coords do
            local coord = data.coords[i]
            emit(coord[3] or data.mapID, coord[1], coord[2])
        end
    else
        emit(data.mapID, data.x, data.y)
    end
    local qg = QuestGiverID(data)
    local extras = qg and PATROL_EXTRA[qg]
    if extras then
        for i = 1, #extras do
            local extra = extras[i]
            emit(extra.mapID or data.mapID, extra.x, extra.y)
        end
    end
end

local function NpcIDFromGUID(guid)
    if ns.NpcIDFromGUID then
        return ns.NpcIDFromGUID(guid)
    end
    return nil
end

local function MapPosFromVector(pos)
    if not pos then
        return nil, nil
    end
    if pos.GetXY then
        local x, y = pos:GetXY()
        if x and y then
            return x, y
        end
    end
    if pos.x and pos.y then
        return pos.x, pos.y
    end
    return nil, nil
end

local function UnitMapPosition(unit, mapID)
    if not unit or not mapID then
        return nil, nil
    end
    if UnitExists and not UnitExists(unit) then
        return nil, nil
    end
    -- GetPlayerMapPosition is player-only on retail-style clients. Using it for
    -- target/nameplate can return the player's point (or a dummy 0-1 value) and
    -- v0.1.4 then replaced Morin's quest bang with that, so 764 vanished.
    if unit == "player" and C_Map and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
        if ok then
            local x, y = MapPosFromVector(pos)
            if IsNormalized(x, y) then
                return x, y
            end
        end
    end
    if UnitPosition and C_Map and C_Map.GetMapPosFromWorldPos then
        local ok, posY, posX, _, instance = pcall(UnitPosition, unit)
        if ok and posX and posY then
            local world
            if CreateVector2D then
                world = CreateVector2D(posX, posY)
            end
            if world then
                local ok2, uiMapID, mapPos = pcall(C_Map.GetMapPosFromWorldPos, instance, world)
                if ok2 then
                    local x, y = MapPosFromVector(mapPos)
                    if IsNormalized(x, y) then
                        if uiMapID == mapID then
                            return x, y
                        end
                        if uiMapID and ns.ProjectToViewedMap then
                            local nx, ny = ns.ProjectToViewedMap(uiMapID, x * 100, y * 100, mapID)
                            if nx and ny then
                                return nx, ny
                            end
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

local function CollectSpawnPoints(data, viewedMapID)
    local points = {}
    EachCoord(data, function(questMapID, x, y)
        local nx, ny = ns.ProjectToViewedMap(questMapID, x, y, viewedMapID)
        if nx and ny then
            points[#points + 1] = {
                nx = nx,
                ny = ny,
                mapID = questMapID,
                x = x,
                y = y,
            }
        end
    end)
    return points
end

local function ClusterSpawnPoints(parent, points)
    if #points <= 1 or not ns.GetOption("showSpawnClusters") then
        return { points }
    end
    local width = parent and parent.GetWidth and parent:GetWidth() or nil
    local height = parent and parent.GetHeight and parent:GetHeight() or nil
    if not width or not height or width < 1 or height < 1 then
        return { points }
    end
    local radius2 = SPAWN_CLUSTER_RADIUS_PX * SPAWN_CLUSTER_RADIUS_PX
    local roots = {}
    for i = 1, #points do
        roots[i] = i
    end
    local function find(index)
        while roots[index] ~= index do
            roots[index] = roots[roots[index]]
            index = roots[index]
        end
        return index
    end
    local function union(left, right)
        local leftRoot, rightRoot = find(left), find(right)
        if leftRoot ~= rightRoot then
            roots[rightRoot] = leftRoot
        end
    end
    for i = 1, #points do
        for j = i + 1, #points do
            local dx = (points[i].nx - points[j].nx) * width
            local dy = (points[i].ny - points[j].ny) * height
            if (dx * dx) + (dy * dy) <= radius2 then
                union(i, j)
            end
        end
    end
    local clusters = {}
    local byRoot = {}
    for i = 1, #points do
        local root = find(i)
        local cluster = byRoot[root]
        if not cluster then
            cluster = {}
            byRoot[root] = cluster
            clusters[#clusters + 1] = cluster
        end
        cluster[#cluster + 1] = points[i]
    end
    while #clusters > SPAWN_CLUSTER_LIMIT do
        local bestLeft, bestRight, bestDistance
        for i = 1, #clusters - 1 do
            local left = clusters[i][1]
            for j = i + 1, #clusters do
                local right = clusters[j][1]
                local dx = (left.nx - right.nx) * width
                local dy = (left.ny - right.ny) * height
                local distance = (dx * dx) + (dy * dy)
                if not bestDistance or distance < bestDistance then
                    bestLeft, bestRight, bestDistance = i, j, distance
                end
            end
        end
        if not bestLeft then
            break
        end
        local left, right = clusters[bestLeft], clusters[bestRight]
        for i = 1, #right do
            left[#left + 1] = right[i]
        end
        table.remove(clusters, bestRight)
    end
    return clusters
end

local function ChooseSpawnAnchor(points, viewedMapID)
    if #points == 0 then
        return nil
    end
    local px, py = UnitMapPosition("player", viewedMapID)
    if not px or not py then
        px, py = 0.5, 0.5
    end
    local best = points[1]
    local bestDistance = ((best.nx - px) * (best.nx - px)) + ((best.ny - py) * (best.ny - py))
    for i = 2, #points do
        local point = points[i]
        local distance = ((point.nx - px) * (point.nx - px)) + ((point.ny - py) * (point.ny - py))
        if distance < bestDistance then
            best, bestDistance = point, distance
        end
    end
    return best
end

local function UnitMatchesNpc(unit, npcID)
    if not UnitGUID then
        return false
    end
    return NpcIDFromGUID(UnitGUID(unit)) == npcID
end

-- Live snap only while the NPC is actually visible. Never reuse a stale last
-- position: that was replacing The Venture Co. (764) with a continent coord
-- that sat off the Mulgore map.
function ns.TryQuestGiverPosition(npcID, viewedMapID)
    if not npcID or not viewedMapID then
        return nil, nil
    end
    local units = { "target", "focus", "mouseover", "npc", "questnpc" }
    for i = 1, #units do
        local unit = units[i]
        if UnitMatchesNpc(unit, npcID) then
            local x, y = UnitMapPosition(unit, viewedMapID)
            if x then
                return x, y
            end
        end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if type(plates) == "table" then
            for i = 1, #plates do
                local plate = plates[i]
                local unit = plate and (plate.namePlateUnitToken or plate.unitToken)
                if unit and UnitMatchesNpc(unit, npcID) then
                    local x, y = UnitMapPosition(unit, viewedMapID)
                    if x then
                        return x, y
                    end
                end
            end
        end
    end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitMatchesNpc(unit, npcID) then
            local x, y = UnitMapPosition(unit, viewedMapID)
            if x then
                return x, y
            end
        end
    end
    return nil, nil
end

local function Dist2(ax, ay, bx, by)
    if not ax or not ay or not bx or not by then
        return nil
    end
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

function MapPins:SnapToQuestGivers()
    local viewedMapID = lastStatus.viewedMap
    local parent = GetCanvas()
    if not viewedMapID or not parent or #active == 0 then
        return
    end
    local liveByNpc = {}
    for i = 1, #active do
        local pin = active[i]
        local qg = QuestGiverID(pin.data)
        if qg and not liveByNpc[qg] then
            local x, y = ns.TryQuestGiverPosition(qg, viewedMapID)
            if x and y then
                liveByNpc[qg] = { x = x, y = y }
            end
        end
        if pin.questID and not pin.titleReady then
            local _, titleReady = ns.GetQuestTitle(pin.questID, true)
            if titleReady then
                pin.titleReady = true
                MapPins:OnTitleLoaded(pin.questID)
            end
        end
    end
    local nearest = {}
    local nearLimit = LIVE_NEAR * LIVE_NEAR
    for i = 1, #active do
        local pin = active[i]
        local qg = QuestGiverID(pin.data)
        local live = qg and liveByNpc[qg]
        if live then
            local d2 = Dist2(pin.attNx or pin.nx, pin.attNy or pin.ny, live.x, live.y)
            if d2 and d2 <= nearLimit then
                local best = nearest[qg]
                if not best or d2 < best.d2 then
                    nearest[qg] = { pin = pin, d2 = d2 }
                end
            end
        end
    end
    local chosen = {}
    for qg, best in pairs(nearest) do
        chosen[best.pin] = liveByNpc[qg]
    end
    for i = 1, #active do
        local pin = active[i]
        local live = chosen[pin]
        if live then
            pin.nx = live.x
            pin.ny = live.y
            pin.live = true
            ApplyPinPoint(pin, parent)
        elseif pin.live then
            pin.nx = pin.attNx or pin.nx
            pin.ny = pin.attNy or pin.ny
            pin.live = nil
            ApplyPinPoint(pin, parent)
        end
    end
end

function MapPins:GetStatus()
    return lastStatus
end

function MapPins:Refresh(reason)
    -- Forever's MapCanvas calls the protected SetPassThroughButtons method
    -- while managed pins are added or removed. Defer the whole refresh so the
    -- existing pin set remains intact until PLAYER_REGEN_ENABLED.
    if InCombatLockdown and InCombatLockdown() then
        lastStatus.mode = "combat-deferred"
        return
    end
    self:CancelPendingRefresh()
    local stitched = IsOpenMapStitched()
    if stitched and stitchedPins and (reason == "map-changed" or reason == "map-display") then
        if ReprojectStitchedPins(ns.GetViewedMapID()) then return end
    end
    self:Clear()
    stitchedPins = false
    lastStatus.lastError = nil
    lastStatus.mode = "canvas"

    if not ns.GetOption("enabled") then
        lastStatus.mode = "disabled"
        return
    end
    if not WorldMapFrame or (WorldMapFrame.IsShown and not WorldMapFrame:IsShown()) then
        lastStatus.mode = "hidden"
        return
    end

    local viewedMapID = ns.GetViewedMapID()
    lastStatus.viewedMap = viewedMapID
    if not viewedMapID then
        lastStatus.lastError = "no-map-id"
        lastStatus.mode = "no-map"
        return
    end

    if not ns.GetOption("showWorldMapPins") and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(viewedMapID)
        local mapTypes = Enum and Enum.UIMapType
        local worldType = mapTypes and mapTypes.World or 1
        local continentType = mapTypes and mapTypes.Continent or 2
        if info and (info.mapType == worldType or info.mapType == continentType) then
            lastStatus.mode = "map-level-hidden"
            return
        end
    end

    local canvas = GetCanvas()
    if not canvas or not canvas.GetWidth then
        lastStatus.lastError = "no-canvas"
        lastStatus.mode = "no-canvas"
        return
    end
    if (canvas:GetWidth() or 0) < 1 or (canvas:GetHeight() or 0) < 1 then
        lastStatus.lastError = "canvas-zero"
        lastStatus.mode = "canvas-zero"
        lastStatus.zeroRetries = (lastStatus.zeroRetries or 0) + 1
        if lastStatus.zeroRetries <= 8 and ns.RequestRefresh then
            ns.RequestRefresh("canvas-zero")
        end
        return
    end
    lastStatus.zeroRetries = 0
    stitchedPins = stitched
    lastStatus.paintedIDs = {}

    local byMap = ns.ByMap or {}
    local quests = ns.Quests or {}
    local painted = 0
    local seen = {}
    local maps = CandidateMapIDs(viewedMapID, byMap)

    local function consider(questID)
        if not questID or seen[questID] then
            return
        end
        seen[questID] = true
        local data = quests[questID]
        if not data then
            return
        end
        local available, why = ns.IsQuestAvailable(questID, data)
        if not available then
            return
        end
        local points = CollectSpawnPoints(data, viewedMapID)
        if #points == 0 then
            return
        end
        local clusters = ClusterSpawnPoints(canvas, points)
        for i = 1, #clusters do
            local anchor = ChooseSpawnAnchor(clusters[i], viewedMapID)
            local before = #active
            if anchor and PlacePin(canvas, anchor.nx, anchor.ny, questID, data, why, false, clusters[i], anchor) then
                if #active > before then
                    painted = painted + 1
                end
                lastStatus.paintedIDs[questID] = true
            end
        end
    end

    local candidates = {}
    for mapIndex = 1, #maps do
        local mapID = maps[mapIndex]
        local list = byMap[mapID]
        if list then
            for i = 1, #list do
                candidates[#candidates + 1] = list[i]
            end
        end
    end
    if ns.offeredQuestIDs then
        for questID in pairs(ns.offeredQuestIDs) do
            candidates[#candidates + 1] = questID
        end
    end

    lastStatus.mode = "painting"
    local job = { generation = refreshGeneration, mapID = viewedMapID, index = 1 }
    refreshJob = job
    local function processBatch()
        if refreshJob ~= job or job.generation ~= refreshGeneration then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            refreshJob = nil
            lastStatus.mode = "combat-deferred"
            return
        end
        if not WorldMapFrame or (WorldMapFrame.IsShown and not WorldMapFrame:IsShown())
            or ns.GetViewedMapID() ~= job.mapID then
            refreshJob = nil
            if not (InCombatLockdown and InCombatLockdown()) then
                MapPins:Clear()
            end
            lastStatus.mode = "refresh-interrupted"
            return
        end

        local profileStart = type(debugprofilestop) == "function" and debugprofilestop() or nil
        local processed = 0
        local itemLimit = profileStart and MAX_REFRESH_ITEMS_PER_FRAME or 60
        local timeBudget = GetRefreshBudgetMS()
        while job.index <= #candidates and processed < itemLimit do
            consider(candidates[job.index])
            job.index = job.index + 1
            processed = processed + 1
            if profileStart and processed > 0
                and (debugprofilestop() - profileStart) >= timeBudget then
                break
            end
        end

        lastStatus.count = painted
        if job.index <= #candidates then
            C_Timer.After(0, processBatch)
            return
        end

        refreshJob = nil
        lastStatus.mode = "canvas"
        local managed = 0
        for i = 1, #active do
            if active[i].managed then
                managed = managed + 1
            end
        end
        lastStatus.managed = managed
    end

    processBatch()
    if ns.GetOption("debug") and reason then
        -- Keep this cheap; stats are available via /fqp stats.
    end
end

-- Avoid HookScript on WorldMapFrame; use hooksecurefunc and our own OnUpdate while open.
local mapWatch = CreateFrame("Frame")
local mapOpen = false
local lastStitchedObserved
local sizeWatchFrames = {}
local sizeSnapshot = {}

local function ResetSizeSnapshots()
    sizeSnapshot = {}
    sizeWatchFrames = {}
    if not WorldMapFrame then
        return
    end
    local function add(frame)
        if frame and frame.GetWidth then
            sizeWatchFrames[#sizeWatchFrames + 1] = frame
        end
    end
    add(WorldMapFrame)
    add(WorldMapFrame.ScrollContainer)
    add(WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
    add(WorldMapDetailFrame)
    add(GetCanvas())
end

local function MapSizeChanged()
    for i = 1, #sizeWatchFrames do
        local frame = sizeWatchFrames[i]
        if frame and frame.GetWidth and frame.GetHeight then
            local width, height = frame:GetWidth(), frame:GetHeight()
            local prev = sizeSnapshot[frame]
            if not prev or prev.width ~= width or prev.height ~= height then
                sizeSnapshot[frame] = { width = width, height = height }
                return true
            end
        end
    end
    return false
end

local function OnMapOpen()
    mapOpen = true
    lastStitchedObserved = IsOpenMapStitched()
    ResetSizeSnapshots()
    InvalidateCanvas()
    ns.RequestRefresh("map-show")
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            InvalidateCanvas()
            ns.RequestRefresh("map-show-layout")
        end)
    end
end

local function OnMapClose()
    mapOpen = false
    lastStitchedObserved = nil
    sizeSnapshot = {}
    sizeWatchFrames = {}
    liveAccum = 0
    gamepadHoverAccum = 0
    activeCursorInput = "mouse"
    lastMouseX, lastMouseY = nil, nil
    hoveredPin = nil
    HideGamepadTooltip()
    InvalidateCanvas()
    MapPins:CancelPendingRefresh()
    MapPins:Clear()
end

mapWatch:SetScript("OnUpdate", function(_, elapsed)
    if not mapOpen then
        return
    end
    local stitched = IsOpenMapStitched()
    if stitched ~= lastStitchedObserved then
        lastStitchedObserved = stitched
        ns.RequestRefresh("openmap-mode")
    end
    local sizeChanged = MapSizeChanged()
    if sizeChanged then
        InvalidateCanvas()
        HideSpawnCloud()
    end
    if #active > 0 then
        MapPins:RepositionAll()
        UpdatePinFades(elapsed)
        if IsGamepadUIEnabled() then
            gamepadHoverAccum = gamepadHoverAccum + elapsed
            if gamepadHoverAccum >= 0.05 then
                gamepadHoverAccum = 0
                MapPins:UpdateGamepadHover()
            end
        else
            gamepadHoverAccum = 0
        end
        liveAccum = liveAccum + elapsed
        if liveAccum >= LIVE_SNAP_GAP then
            liveAccum = 0
            MapPins:SnapToQuestGivers()
        end
    elseif sizeChanged then
        liveAccum = 0
    else
        liveAccum = 0
    end
end)

function MapPins:HookMap()
    if self.hooked or not WorldMapFrame then
        return
    end
    if ns.TryRegisterWorldMapDropdown then
        ns.TryRegisterWorldMapDropdown()
    end
    self.hooked = true
    mapOpen = WorldMapFrame.IsShown and WorldMapFrame:IsShown() or false
    if mapOpen then
        OnMapOpen()
    end
    if WorldMapFrame.Show then
        hooksecurefunc(WorldMapFrame, "Show", function()
            if not mapOpen then
                OnMapOpen()
            end
        end)
    end
    if WorldMapFrame.Hide then
        hooksecurefunc(WorldMapFrame, "Hide", function()
            if mapOpen then
                OnMapClose()
            end
        end)
    end
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            InvalidateCanvas()
            if stitchedPins and IsOpenMapStitched() and ReprojectStitchedPins(ns.GetViewedMapID()) then
                return
            end
            local previousMapID = lastStatus.viewedMap
            local viewedMapID = ns.GetViewedMapID()
            if previousMapID and viewedMapID and previousMapID ~= viewedMapID then
                -- Remove the previous zone's pins now; the debounced, sliced
                -- refresh will paint the new zone over the next few frames.
                MapPins:CancelPendingRefresh()
                MapPins:Clear()
                lastStatus.mode = "map-changing"
            end
            ns.RequestRefresh("map-changed")
        end)
    end
    if WorldMapFrame.OnCanvasScaleChanged then
        hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function()
            InvalidateCanvas()
            HideSpawnCloud()
            MapPins:RepositionAll()
        end)
    end
    if WorldMapFrame.SynchronizeDisplayState then
        hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", function()
            InvalidateCanvas()
            if stitchedPins and IsOpenMapStitched() and ReprojectStitchedPins(ns.GetViewedMapID()) then
                MapPins:RepositionAll()
                return
            end
            ns.RequestRefresh("map-display")
        end)
    end
end
