local ADDON_NAME, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

-- Per-character hidden quest pins live in the account store
-- (ForeverQuestPinsDB.hiddenQuests["Name-Realm"]) because Forever can drop
-- per-character SavedVariables and the settings repair only covers the
-- account file. Keep hiddenQuests out of ns.defaults: the settings sync only
-- copies default keys, so this table is never overwritten by it.

local function Print(message)
    print("|cffffd100Forever Quest Pins:|r " .. tostring(message))
end

local function CharacterKey()
    local name = UnitName and UnitName("player")
    local realm = GetRealmName and GetRealmName()
    if type(name) ~= "string" or name == "" or type(realm) ~= "string" or realm == "" then
        return nil
    end
    return name .. "-" .. realm
end

local function Bucket(create)
    local db = ns.db
    local key = CharacterKey()
    if type(db) ~= "table" or not key then
        return nil
    end
    local all = db.hiddenQuests
    if type(all) ~= "table" then
        if not create then
            return nil
        end
        all = {}
        db.hiddenQuests = all
    end
    local bucket = all[key]
    if type(bucket) ~= "table" then
        if not create then
            return nil
        end
        bucket = {}
        all[key] = bucket
    end
    return bucket, all, key
end

local function Changed()
    if ns.SyncSettingsCheckboxes then
        ns.SyncSettingsCheckboxes()
    end
    if ns.RequestRefresh then
        ns.RequestRefresh("quest-hidden")
    end
end

function ns.IsQuestHidden(questID)
    local bucket = Bucket(false)
    return bucket ~= nil and questID ~= nil and bucket[questID] == true
end

--- Hide every quest ID in the list for the current character.
-- @return number of quests that were not already hidden
function ns.HideQuests(questIDs)
    if type(questIDs) ~= "table" then
        return 0
    end
    local bucket = Bucket(true)
    if not bucket then
        return 0
    end
    local count = 0
    for i = 1, #questIDs do
        local questID = tonumber(questIDs[i])
        if questID and questID > 0 and not bucket[questID] then
            bucket[questID] = true
            count = count + 1
        end
    end
    if count > 0 then
        Changed()
    end
    return count
end

function ns.UnhideQuest(questID)
    questID = tonumber(questID)
    local bucket = Bucket(false)
    if not bucket or not questID or not bucket[questID] then
        return false
    end
    bucket[questID] = nil
    Changed()
    return true
end

--- Restore every hidden quest for the current character only.
-- @return number of quests restored
function ns.UnhideAllQuests()
    local bucket, all, key = Bucket(false)
    if not bucket then
        return 0
    end
    local count = 0
    for _ in pairs(bucket) do
        count = count + 1
    end
    all[key] = nil
    if count > 0 then
        Changed()
    end
    return count
end

function ns.HiddenQuestIDs()
    local ids = {}
    local bucket = Bucket(false)
    if bucket then
        for questID in pairs(bucket) do
            ids[#ids + 1] = questID
        end
        table.sort(ids)
    end
    return ids
end

function ns.ResetHiddenQuestPins()
    local count = ns.UnhideAllQuests()
    Print((L["Restored %d hidden quest pin(s)."]):format(count))
    return count
end

function ns.PrintHiddenQuests()
    local ids = ns.HiddenQuestIDs()
    if #ids == 0 then
        Print(L["No hidden quest pins on this character."])
        return
    end
    Print((L["Hidden quest pins on this character (%d):"]):format(#ids))
    for i = 1, #ids do
        local title = ns.GetQuestTitle and ns.GetQuestTitle(ids[i])
        print(("  %d %s"):format(ids[i], title or ""))
    end
    print(L["  /fqp unhide <id> or /fqp unhide all to restore"])
end

function ns.UnhideFromSlash(arg)
    if arg == "all" then
        ns.ResetHiddenQuestPins()
        return
    end
    local questID = tonumber(arg)
    if not questID then
        Print(L["Usage: /fqp unhide <id> or /fqp unhide all"])
        return
    end
    if ns.UnhideQuest(questID) then
        Print((L["Restored quest %d."]):format(questID))
    else
        Print((L["Quest %d is not hidden on this character."]):format(questID))
    end
end
