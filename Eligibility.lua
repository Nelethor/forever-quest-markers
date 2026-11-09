local ADDON_NAME, ns = ...
local HIGH_LEVEL_GAP_MAX = 15

local function Call(apiTable, name, ...)
    local fn = apiTable and apiTable[name]
    if type(fn) == "function" then
        return fn(...)
    end
end

local completedLookup
local completedLookupReady = false
local completedListLoaded = false

-- Session overrides for Forever quest APIs that lag behind QUEST_* events.
-- The completed-ID list stays authoritative for historical progress (alts),
-- but turn-ins and accepts must hide pins immediately without waiting on
-- GetAllCompletedQuestIDs / IsOnQuest to catch up.
ns.sessionCompleted = ns.sessionCompleted or {}
ns.sessionInLog = ns.sessionInLog or {}

function ns.InvalidateCompletionCache()
    completedLookup = nil
    completedLookupReady = false
    completedListLoaded = false
end

function ns.NoteQuestCompleted(questID)
    questID = tonumber(questID)
    if not questID or questID <= 0 then
        return
    end
    ns.sessionCompleted[questID] = true
    ns.sessionInLog[questID] = nil
    if ns.offeredQuestIDs then
        ns.offeredQuestIDs[questID] = nil
    end
    if completedLookup then
        completedLookup[questID] = true
    end
end

function ns.NoteQuestAccepted(questID)
    questID = tonumber(questID)
    if not questID or questID <= 0 then
        return
    end
    ns.sessionInLog[questID] = true
    if ns.offeredQuestIDs then
        ns.offeredQuestIDs[questID] = nil
    end
end

function ns.NoteQuestRemoved(questID)
    questID = tonumber(questID)
    if not questID or questID <= 0 then
        return
    end
    ns.sessionInLog[questID] = nil
    if ns.offeredQuestIDs then
        ns.offeredQuestIDs[questID] = nil
    end
end

local function AddCompletedQuest(lookup, questID)
    questID = tonumber(questID)
    if type(questID) == "number" and questID > 0 then
        lookup[questID] = true
    end
end

-- [questID] = true and [questID] = 1 record that quest ID.
-- [questID] = questID records that quest ID.
-- [index] = questID records the value.
local function IngestCompleted(lookup, completed)
    for key, value in pairs(completed) do
        local keyID = tonumber(key)
        if keyID and (value == true or value == 1 or (type(value) == "number" and value == keyID)) then
            AddCompletedQuest(lookup, keyID)
        elseif type(value) == "number" and value > 0 then
            AddCompletedQuest(lookup, value)
        end
    end
end

local function CompletedLookup()
    if completedLookupReady then
        return completedLookup
    end
    completedLookupReady = true
    local lookup = {}
    local loaded = false
    if GetQuestsCompleted then
        local ok, completed = pcall(GetQuestsCompleted)
        if ok and type(completed) == "table" then
            IngestCompleted(lookup, completed)
            loaded = true
        end
    end
    local ids = Call(C_QuestLog, "GetAllCompletedQuestIDs")
    if type(ids) == "table" then
        IngestCompleted(lookup, ids)
        loaded = true
    end
    -- A loaded list is authoritative, including an empty one. Object-started
    -- quests such as the Ravaged Caravan crate are in these lists even when
    -- C_QuestLog.IsQuestFlaggedCompleted misses them.
    completedListLoaded = loaded
    completedLookup = lookup
    return lookup
end

function ns.IsQuestFlaggedCompleted(questID)
    if not questID then
        return false
    end
    if ns.sessionCompleted[questID] then
        return true
    end
    local lookup = CompletedLookup()
    if completedListLoaded then
        return lookup[questID] and true or false
    end
    -- Neither completed-ID list loaded. Character completion only.
    if Call(C_QuestLog, "IsQuestFlaggedCompleted", questID) then
        return true
    end
    if IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(questID) then
        return true
    end
    return false
end

function ns.HasQuestCompletionAPI()
    return (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted)
        or (C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
        or IsQuestFlaggedCompleted
        or GetQuestsCompleted
        or false
end

function ns.HasQuestGiver(data)
    if not data then
        return false
    end
    if data.qg then
        return true
    end
    if data.qgs and data.qgs[1] then
        return true
    end
    return false
end

function ns.IsQuestReadyForTurnIn(questID)
    if not questID then
        return false
    end
    if C_QuestLog and C_QuestLog.IsComplete then
        local ok, complete = pcall(C_QuestLog.IsComplete, questID)
        if ok and complete ~= nil then
            return complete and true or false
        end
    end
    local index = Call(C_QuestLog, "GetLogIndexForQuestID", questID)
    if index and index > 0 and GetQuestLogTitle then
        local ok, _, _, _, _, _, isComplete = pcall(GetQuestLogTitle, index)
        if ok then
            return isComplete == 1 or isComplete == true
        end
    end
    return false
end

function ns.IsOnQuest(questID)
    if not questID then
        return false
    end
    if ns.sessionInLog[questID] then
        return true
    end
    local onQuest = Call(C_QuestLog, "IsOnQuest", questID)
    if onQuest ~= nil then
        return onQuest and true or false
    end
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local index = C_QuestLog.GetLogIndexForQuestID(questID)
        return index and index > 0 or false
    end
    if GetQuestLogIndexByID then
        local index = GetQuestLogIndexByID(questID)
        return index and index > 0 or false
    end
    return false
end

local titleCache = {}
local npcNameCache = {}
local requestedTitles = {}
local requestedLevels = {}
local npcNameScanner

local function RememberTitle(questID, title)
    if questID and type(title) == "string" and title ~= "" then
        titleCache[questID] = title
        return title
    end
    return nil
end

local function QuestTitleFromData(questID)
    local data = ns.Quests and ns.Quests[questID]
    local title = data and data.title
    if type(title) == "string" and title ~= "" then
        return title
    end
    return nil
end

local function ReadQuestTitle(questID)
    local title = Call(C_QuestLog, "GetTitleForQuestID", questID)
    if RememberTitle(questID, title) then
        return titleCache[questID]
    end
    title = Call(C_QuestLog, "GetQuestInfo", questID)
    if type(title) == "string" then
        return RememberTitle(questID, title)
    end
    if type(title) == "table" then
        return RememberTitle(questID, title.title)
    end
    return nil
end

function ns.RequestQuestTitle(questID)
    if not questID or requestedTitles[questID] or titleCache[questID] then
        return
    end
    requestedTitles[questID] = true
    Call(C_QuestLog, "RequestLoadQuestByID", questID)
end

function ns.GetQuestTitle(questID)
    if not questID then
        return nil
    end
    if titleCache[questID] then
        return titleCache[questID]
    end
    local title = ReadQuestTitle(questID)
    if title then
        return title
    end
    ns.RequestQuestTitle(questID)
    return QuestTitleFromData(questID)
end

-- Suggested quest level (tracker [9]), not the database required level. Forever exposes this
-- for unaccepted IDs via C_QuestLog.GetQuestDifficultyLevel.
function ns.GetQuestDifficultyLevel(questID)
    if not questID then
        return nil
    end
    local level = Call(C_QuestLog, "GetQuestDifficultyLevel", questID)
    if type(level) == "number" and level > 0 then
        return level
    end
    if not requestedLevels[questID] then
        requestedLevels[questID] = true
        Call(C_QuestLog, "RequestLoadQuestByID", questID)
    end
    return nil
end

function ns.GetQuestDifficultyRGB(level)
    if type(level) ~= "number" then
        return 1, 0.82, 0
    end
    if GetQuestDifficultyColor then
        local color = GetQuestDifficultyColor(level)
        if type(color) == "table" and color.r then
            return color.r, color.g, color.b
        end
    end
    return 1, 0.82, 0
end

function ns.OnQuestDataLoad(questID)
    if not questID then
        return
    end
    requestedTitles[questID] = nil
    requestedLevels[questID] = nil
    ReadQuestTitle(questID)
    if ns.MapPins and ns.MapPins.OnTitleLoaded then
        ns.MapPins:OnTitleLoaded(questID)
    end
    local highLevelGap = ns.GetOption("highLevelGap")
    local highLevelLimitEnabled = type(highLevelGap) == "number" and highLevelGap < HIGH_LEVEL_GAP_MAX
    if ns.RequestRefresh and (not ns.GetOption("showTrivial") or highLevelLimitEnabled) then
        ns.RequestRefresh("quest-level")
    end
end

function ns.OnQuestDataLoadFailed(questID)
    if not questID then return end
    -- Retry on the next lookup, not from the failed event itself.
    requestedTitles[questID] = nil
    requestedLevels[questID] = nil
end

local function CacheNPCName(npcID, name)
    if issecretvalue and issecretvalue(name) then
        return nil
    end
    if npcID and type(name) == "string" and name ~= "" and name ~= "Unknown" then
        npcNameCache[npcID] = name
        return name
    end
    return nil
end

local function NPCNameFromTooltipInfo(npcID)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then
        return nil
    end
    local ok, info = pcall(C_TooltipInfo.GetHyperlink, "unit:Creature-0-0-0-0-" .. npcID .. "-0000000000")
    if not ok or type(info) ~= "table" then
        return nil
    end
    local lines = info.lines
    local first = lines and lines[1]
    local text = first and (first.leftText or first.LeftText)
    return CacheNPCName(npcID, text)
end

local function EnsureNPCNameScanner()
    if npcNameScanner then
        return npcNameScanner
    end
    local ok, tip = pcall(CreateFrame, "GameTooltip", "ForeverQuestPinsNpcTip", UIParent, "GameTooltipTemplate")
    if not ok then
        return nil
    end
    npcNameScanner = tip
    npcNameScanner:SetOwner(UIParent, "ANCHOR_NONE")
    return npcNameScanner
end

local function NPCNameFromScanner(npcID)
    local tip = EnsureNPCNameScanner()
    if not tip or not tip.SetHyperlink then
        return nil
    end
    tip:ClearLines()
    local ok = pcall(tip.SetHyperlink, tip, "unit:Creature-0-0-0-0-" .. npcID .. "-0000000000")
    if not ok then
        return nil
    end
    local fontString = _G["ForeverQuestPinsNpcTipTextLeft1"]
    local text = fontString and fontString.GetText and fontString:GetText()
    return CacheNPCName(npcID, text)
end

function ns.GetNPCName(npcID)
    if not npcID then
        return nil
    end
    if npcNameCache[npcID] then
        return npcNameCache[npcID]
    end
    return NPCNameFromTooltipInfo(npcID) or NPCNameFromScanner(npcID)
end

function ns.PrefetchQuestInfo(questID, data)
    ns.GetQuestTitle(questID)
    ns.GetQuestDifficultyLevel(questID)
    ns.RequestQuestTitle(questID)
    local qg = data and (data.qg or (data.qgs and data.qgs[1]))
    if qg then
        ns.GetNPCName(qg)
    end
end

function ns.GetPlayerRaceID()
    local _, _, raceID = UnitRace("player")
    return raceID
end

function ns.GetPlayerClassID()
    local _, _, classID = UnitClass("player")
    return classID
end

function ns.GetPlayerFaction()
    return UnitFactionGroup("player")
end

local knownProfessionSkills
local professionSkillsKnown = false

function ns.InvalidateProfessionCache()
    knownProfessionSkills = nil
    professionSkillsKnown = false
end

local function KnownProfessionSkills()
    if professionSkillsKnown then
        return knownProfessionSkills, true
    end
    if not GetProfessions or not GetProfessionInfo then
        return nil, false
    end
    local professionIndices = { GetProfessions() }
    local skills = {}
    for _, index in pairs(professionIndices) do
        if index then
            local _, _, _, _, _, _, skillLine = GetProfessionInfo(index)
            if type(skillLine) == "number" then
                skills[skillLine] = true
            end
        end
    end
    knownProfessionSkills = skills
    professionSkillsKnown = true
    return knownProfessionSkills, true
end

function ns.HasRequiredSkill(requiredSkill)
    if type(requiredSkill) ~= "number" then
        return true
    end
    if IsPlayerSpell and IsPlayerSpell(requiredSkill) then
        return true
    end
    if IsSpellKnown and IsSpellKnown(requiredSkill) then
        return true
    end
    local skills, known = KnownProfessionSkills()
    if not known then
        return true
    end
    return skills[requiredSkill] and true or false
end

function ns.IsEventActive(eventID)
    if not eventID then
        return false
    end
    if C_Calendar and C_Calendar.IsEventActive then
        local ok, active = pcall(C_Calendar.IsEventActive, eventID)
        if ok and active then
            return true
        end
    end
    if IsHolidayActive then
        local ok, active = pcall(IsHolidayActive, eventID)
        if ok and active then
            return true
        end
    end
    return false
end

-- sourceQuestGroup is AND; sourceQuestSingle is OR with sourceQuestNumRequired
-- (default 1). sourceQuests remains as a legacy fallback for saved/custom data.
--
-- Object-started prereqs (no quest-giver NPC) often never flag completed on
-- Forever. The Ravaged Caravan crate (751) is the gate for Morin Cloudstalker's
-- The Venture Co. (764) and Supervisor Fizsprocket (765). If that source is
-- not in the log and its own source quests are met, treat it as satisfied.
local SourceSatisfied, SourceQuestsMet, CountCompleted

CountCompleted = function(questIDs)
    local count = 0
    for i = 1, #questIDs do
        if SourceSatisfied(questIDs[i]) then
            count = count + 1
        end
    end
    return count
end

SourceSatisfied = function(questID)
    if ns.IsQuestFlaggedCompleted(questID) then
        return true
    end
    local data = ns.Quests and ns.Quests[questID]
    -- Breadcrumbs are skippable. Kaltunk's "Your Place in the World" (4641)
    -- must not hide Gornek's Cutting Teeth (788).
    if data and data.isBreadcrumb then
        return true
    end
    if not data or ns.HasQuestGiver(data) then
        return false
    end
    if ns.IsOnQuest(questID) then
        return false
    end
    local group = data.sourceQuestGroup
    local single = data.sourceQuestSingle
    local legacy = data.sourceQuests
    local hasGroup = group and #group > 0
    local hasSingle = single and #single > 0
    local hasLegacy = legacy and #legacy > 0
    if not (hasGroup or hasSingle or hasLegacy) then
        return false
    end
    return SourceQuestsMet(data)
end

local function PrereqListMet(questIDs, required)
    if not questIDs or #questIDs == 0 then
        return true, "no-prereq"
    end
    if not ns.HasQuestCompletionAPI() then
        return true, "prereq-unknown"
    end
    local completed = CountCompleted(questIDs)
    if required == 0 then
        return true, "prereq-none-required"
    end
    if required == nil then
        if completed < #questIDs then
            return false, "prereq-and"
        end
        return true, "prereq-and"
    end
    if completed < required then
        return false, "prereq-count"
    end
    return true, "prereq-count"
end

SourceQuestsMet = function(data)
    local group = data.sourceQuestGroup
    local single = data.sourceQuestSingle
    if group and #group > 0 then
        local ok, reason = PrereqListMet(group, nil)
        if not ok then
            return false, reason
        end
    end
    if single and #single > 0 then
        local required = data.sourceQuestNumRequired or 1
        local ok, reason = PrereqListMet(single, required)
        if not ok then
            return false, reason
        end
    end
    if (group and #group > 0) or (single and #single > 0) then
        return true, "prereq-split"
    end
    return PrereqListMet(data.sourceQuests, data.sourceQuestNumRequired)
end

function ns.IsSourceSatisfied(questID)
    return SourceSatisfied(questID)
end

ns.offeredQuestIDs = ns.offeredQuestIDs or {}
ns.lastOffer = nil

function ns.IsOffered(questID)
    return questID and ns.offeredQuestIDs[questID] and true or false
end

function ns.NpcListsQuestStarter(npcID, questID, data)
    if not npcID or not questID or not data then
        return false
    end
    if data.qg == npcID then
        return true
    end
    local qgs = data.qgs
    if qgs then
        for i = 1, #qgs do
            if qgs[i] == npcID then
                return true
            end
        end
    end
    return false
end

--- Whether this NPC may offer questID for accept tooltip rows (starter ids or session gossip).
function ns.NpcOffersQuestAccept(npcID, questID, data)
    if not npcID or not questID then
        return false
    end
    if ns.IsOffered(questID) then
        return true
    end
    data = data or (ns.Quests and ns.Quests[questID])
    if not data then
        return false
    end
    return ns.NpcListsQuestStarter(npcID, questID, data)
end

function ns.SetLastOfferNPC(qg, mapID, x, y)
    ns.lastOffer = { qg = qg, mapID = mapID, x = x, y = y }
end

local function AddQuestToMap(questID, mapID)
    if not mapID then
        return false
    end
    ns.ByMap = ns.ByMap or {}
    local list = ns.ByMap[mapID]
    if not list then
        list = {}
        ns.ByMap[mapID] = list
    end
    for index = 1, #list do
        if list[index] == questID then
            return false
        end
    end
    list[#list + 1] = questID
    return true
end

local function AddQuestStarter(data, qg)
    if not data or not qg then
        return false
    end
    if data.qg == qg then
        return false
    end
    for _, npcID in ipairs(data.qgs or {}) do
        if npcID == qg then
            return false
        end
    end
    if not data.qg then
        data.qg = qg
    else
        data.qgs = data.qgs or {}
        data.qgs[#data.qgs + 1] = qg
    end
    return true
end

local function FillOfferCoord(data, offer)
    if not data or not offer then
        return false
    end
    if data.mapID and data.x and data.y then
        return false
    end
    if offer.mapID and offer.x and offer.y then
        data.mapID = offer.mapID
        data.x = offer.x
        data.y = offer.y
        return true
    end
    return false
end

function ns.NoteOfferedQuest(questID)
    questID = tonumber(questID)
    if not questID then
        return
    end
    ns.offeredQuestIDs[questID] = true
    local offer = ns.lastOffer
    local data = ns.Quests and ns.Quests[questID]
    if data then
        local changed = AddQuestStarter(data, offer and offer.qg)
        if FillOfferCoord(data, offer) then
            AddQuestToMap(questID, data.mapID)
            changed = true
        end
        if changed and ns.NPCTooltips and ns.NPCTooltips.InvalidateStarterIndex then
            ns.NPCTooltips:InvalidateStarterIndex()
        end
        return
    end
    if not offer or not (offer.qg or (offer.mapID and offer.x and offer.y)) then
        return
    end
    ns.Quests = ns.Quests or {}
    ns.ByMap = ns.ByMap or {}
    ns.Quests[questID] = {
        mapID = offer.mapID,
        x = offer.x,
        y = offer.y,
        qg = offer.qg,
    }
    AddQuestToMap(questID, offer.mapID)
    if ns.NPCTooltips and ns.NPCTooltips.InvalidateStarterIndex then
        ns.NPCTooltips:InvalidateStarterIndex()
    end
end

--- Creature/Vehicle id from a unit GUID. Secret GUIDs (tainted execution cannot
--- index them) are ignored so gossip capture does not error.
function ns.NpcIDFromGUID(guid)
    if type(guid) ~= "string" then
        return nil
    end
    if issecretvalue and issecretvalue(guid) then
        return nil
    end
    local ok, npcID = pcall(function()
        return tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
            or tonumber(guid:match("Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    end)
    if ok then
        return npcID
    end
    return nil
end

function ns.CaptureOfferContext()
    local guid = UnitGUID and (UnitGUID("npc") or UnitGUID("questnpc") or UnitGUID("target"))
    local qg = ns.NpcIDFromGUID(guid)
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID and ns.GetViewedMapID then
        mapID = ns.GetViewedMapID()
    end
    local x, y
    if mapID and C_Map and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
        if ok and pos then
            if pos.GetXY then
                x, y = pos:GetXY()
            else
                x, y = pos.x, pos.y
            end
        end
    end
    if x and y and x <= 1 and y <= 1 then
        x, y = x * 100, y * 100
    end
    ns.SetLastOfferNPC(qg, mapID, x, y)
end

local function QuestLevelForTrivial(questID, data)
    local level = ns.GetQuestDifficultyLevel and ns.GetQuestDifficultyLevel(questID)
    if type(level) == "number" and level > 0 then
        return level, true
    end
    local minLevel = data and data.minLevel
    if minLevel then
        return minLevel, true
    end
    return nil, false
end

local INSTANCE_QUEST_TAGS = {
    [81] = true, -- Dungeon
    [62] = true, -- Raid
    [85] = true, -- Heroic
    [88] = true, -- Raid (10)
    [89] = true, -- Raid (25)
    [98] = true, -- Scenario
}

local instanceQuestCache = {}

local function QuestTagInfo(questID)
    local info
    if C_QuestLog and type(C_QuestLog.GetQuestTagInfo) == "function" then
        local ok, result = pcall(C_QuestLog.GetQuestTagInfo, questID)
        if ok then
            info = result
        end
    end
    if info == nil and type(GetQuestTagInfo) == "function" then
        local ok, result = pcall(GetQuestTagInfo, questID)
        if ok then
            info = result
        end
    end
    if type(info) == "table" then
        local tagID = info.tagID or info.tagId or info.TagID
        local tagName = info.tagName or info.TagName
        if tagID == 0 then
            tagID = nil
        end
        if tagName == "" or tagName == "None" then
            tagName = nil
        end
        return tagID, tagName
    end
    if type(info) == "number" then
        return info
    end
    if type(info) == "string" then
        return nil, info
    end
    return nil
end

local function IsInstanceTag(tagID, tagName)
    if type(tagID) == "number" and INSTANCE_QUEST_TAGS[tagID] then
        return true
    end
    if type(tagName) == "string" then
        local name = tagName:lower()
        return name == "dungeon"
            or name == "raid"
            or name == "heroic"
            or name == "scenario"
            or name:match("^raid %(") ~= nil
    end
    return false
end

--- Whether the client or Questie's static corrections classify a quest as instanced.
-- The client API wins when it has a definite tag. The generated corrections
-- rescue known-wrong client tags. A nil API result falls back to static data
-- and is not cached, so a later quest load can retry.
function ns.IsInstanceQuest(questID, data)
    questID = tonumber(questID)
    if not questID then
        return false
    end
    local cached = instanceQuestCache[questID]
    if cached ~= nil then
        return cached
    end
    local tagID, tagName = QuestTagInfo(questID)
    local correction = ns.QuestTagCorrections and ns.QuestTagCorrections[questID]
    local result
    if IsInstanceTag(tagID, tagName) then
        result = true
    elseif IsInstanceTag(correction, nil) then
        result = true
    elseif tagID ~= nil or tagName ~= nil then
        result = false
    else
        data = data or (ns.Quests and ns.Quests[questID])
        result = data ~= nil and data.isInstanceQuest == true
    end
    if tagID ~= nil or tagName ~= nil or correction ~= nil then
        instanceQuestCache[questID] = result
    end
    return result
end

function ns.InvalidateInstanceQuestCache(questID)
    questID = tonumber(questID)
    if questID then
        instanceQuestCache[questID] = nil
    else
        instanceQuestCache = {}
    end
end

local function IsTrivial(questID, data)
    local questLevel, reliable = QuestLevelForTrivial(questID, data)
    if not reliable or not questLevel then
        return false, false
    end
    local playerLevel = UnitLevel("player") or 1
    if (playerLevel - questLevel) >= ns.GetOption("trivialLevelGap") then
        return true, true
    end
    return false, true
end

--- Conservative availability check. Unknown restrictions keep the pin visible.
-- @return available boolean
-- @return reason string
function ns.IsQuestAvailable(questID, data)
    if not questID or not data then
        return false, "bad-data"
    end
    if ns.IsQuestFlaggedCompleted(questID) then
        return false, "completed"
    end
    if ns.IsOnQuest(questID) then
        return false, "in-log"
    end
    if ns.IsQuestHidden and ns.IsQuestHidden(questID) then
        return false, "user-hidden"
    end
    local category
    if ns.IsInstanceQuest(questID, data) then
        category = "showDungeon"
    elseif data.classes and #data.classes > 0 then
        category = "showClass"
    elseif data.requireSkill then
        category = "showProfession"
    elseif not (data.repeatable or data.isYearly or data.event
        or (ns.IsWarEffortQuest and ns.IsWarEffortQuest(questID, data))) then
        category = "showNormal"
    end
    if category and ns.GetOption(category) == false then
        return false, "category-hidden"
    end
    if data.repeatable and not ns.GetOption("showRepeatable") then
        return false, "repeatable"
    end
    if ns.IsOffered and ns.IsOffered(questID) then
        return true, "npc-offered"
    end

    if (data.isYearly or data.event) and not ns.GetOption("showSeasonal") then
        if not ns.IsEventActive(data.event) then
            return false, "seasonal"
        end
    end

    if ns.IsWarEffortQuest and ns.IsWarEffortQuest(questID, data) and not ns.GetOption("showWarEffort") then
        return false, "war-effort"
    end

    local altQuests = data.altQuests
    if altQuests then
        for i = 1, #altQuests do
            local altID = altQuests[i]
            if altID ~= questID and ns.IsQuestFlaggedCompleted(altID) then
                return false, "alt-completed"
            end
        end
    end

    local prereqOk, prereqReason = SourceQuestsMet(data)
    if not prereqOk then
        return false, prereqReason
    end

    local faction = data.faction
    if faction then
        local playerFaction = ns.GetPlayerFaction()
        if playerFaction and playerFaction ~= faction then
            return false, "faction"
        end
    end

    local races = data.races
    if races and #races > 0 then
        local raceID = ns.GetPlayerRaceID()
        if raceID then
            local match = false
            for i = 1, #races do
                if races[i] == raceID then
                    match = true
                    break
                end
            end
            if not match then
                return false, "race"
            end
        end
    end

    local classes = data.classes
    if classes and #classes > 0 then
        local classID = ns.GetPlayerClassID()
        if classID then
            local match = false
            for i = 1, #classes do
                if classes[i] == classID then
                    match = true
                    break
                end
            end
            if not match then
                return false, "class"
            end
        end
    end

    if data.requireSkill and not ns.HasRequiredSkill(data.requireSkill) then
        return false, "profession"
    end

    local minLevel = data.minLevel
    local playerLevel = UnitLevel("player") or 1
    if minLevel and playerLevel < minLevel then
        return false, "low-level"
    end

    if not ns.GetOption("showTrivial") then
        local trivial, reliable = IsTrivial(questID, data)
        if reliable and trivial then
            return false, "trivial"
        end
    end

    local highLevelGap = ns.GetOption("highLevelGap") or HIGH_LEVEL_GAP_MAX
    if type(highLevelGap) == "number" and highLevelGap < HIGH_LEVEL_GAP_MAX then
        local questLevel = ns.GetQuestDifficultyLevel and ns.GetQuestDifficultyLevel(questID)
        if questLevel and (questLevel - playerLevel) >= highLevelGap then
            return false, "high-level"
        end
    end

    return true, prereqReason or "ok"
end
