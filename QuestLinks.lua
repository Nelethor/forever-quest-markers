local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

local registered = false
local hoveredBlock
local POPUP = "FOREVER_QUEST_PINS_WOWHEAD_URL"

local function QuestURL(questID)
    if type(questID) ~= "number" or questID <= 0 or questID ~= math.floor(questID)
        or questID == math.huge then
        return nil
    end
    return "https://www.wowhead.com/forever/quest=" .. string.format("%d", questID)
end

function ns.ShowWowheadQuestURL(questID)
    local url = QuestURL(questID)
    if not url or not StaticPopupDialogs or not StaticPopup_Show then
        return false
    end
    StaticPopupDialogs[POPUP] = StaticPopupDialogs[POPUP] or {
        text = L["Copy Wowhead URL\nPress Cmd+C or Ctrl+C to copy the selected link."],
        button1 = CLOSE,
        hasEditBox = true,
        editBoxWidth = 350,
        maxLetters = 128,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(dialog, link)
            local editBox = dialog:GetEditBox()
            editBox:SetText(link)
            editBox:SetFocus()
            editBox:HighlightText()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
    }
    return StaticPopup_Show(POPUP, nil, nil, url) ~= nil
end

function ns.TryRegisterQuestLinks()
    if registered then
        return true
    end
    local tracker = QuestObjectiveTracker
    if not tracker or type(tracker.OnBlockHeaderEnter) ~= "function"
        or type(tracker.OnBlockHeaderLeave) ~= "function"
        or type(tracker.GetContextMenuParent) ~= "function"
        or not Menu or type(Menu.ModifyMenu) ~= "function"
        or type(hooksecurefunc) ~= "function" then
        return false
    end

    -- Forever's menu tag has no quest context. The header hover identifies the
    -- clicked block without replacing Blizzard's click handler.
    hooksecurefunc(tracker, "OnBlockHeaderEnter", function(_, block)
        hoveredBlock = block
    end)
    hooksecurefunc(tracker, "OnBlockHeaderLeave", function(_, block)
        if hoveredBlock == block then
            hoveredBlock = nil
        end
    end)
    Menu.ModifyMenu("MENU_QUEST_OBJECTIVE_TRACKER", function(owner, root)
        if owner ~= tracker:GetContextMenuParent() then
            return
        end
        local questID = hoveredBlock and hoveredBlock.id
        if not QuestURL(questID) then
            return
        end
        root:CreateDivider()
        root:CreateButton(L["Copy Wowhead URL"], function()
            ns.ShowWowheadQuestURL(questID)
        end)
    end)
    registered = true
    return true
end
