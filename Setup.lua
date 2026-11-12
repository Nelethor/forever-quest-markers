local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

local pages = {
    { title = "Map pins", options = {
        { "enabled", "Show quest start pins" },
        { "showWorldMapPins", "Show quest pins on world and continent maps" },
        { "showRepeatable", "Show repeatable quest pins" },
        { "showSeasonal", "Show seasonal / holiday quest pins" },
        { "showWarEffort", "Show AQ war effort pins" },
        { "showTrivial", "Show low-level quests" },
    } },
    { title = "Quest categories", options = {
        { "showNormal", "Show normal quest start pins" },
        { "showClass", "Show class quest pins" },
        { "showDungeon", "Show dungeon / raid quest pins" },
        { "showProfession", "Show profession quest pins" },
        { "showWarEffortAlways", "Always show AQ war effort pins" },
    } },
    { title = "Navigation", options = {
        { "enablePinTracking", "Click pins to track quest starts" },
        { "trackOnWorldMaps", "Track from world and continent maps" },
        { "showNPCTooltips", "Show quests on NPC tooltips" },
        { "showSpawnClusters", "Show spawn clusters" },
        { "highlightNewQuests", "Show tint for quests new in WoW Forever" },
    } },
    { title = "Quest automation", options = {
        { "autoAccept", "Auto-accept quests" },
        { "autoAcceptRangeEnabled", "Limit auto-accept quest level" },
        { "autoTurnIn", "Auto-turn in quests" },
        { "hideQuestTrackerInCombat", "Hide quest tracker in combat" },
    } },
}

local frame
local function Complete()
    ns.SaveWelcomeState(true)
    frame:Hide()
end

local function MakeButton(parent, label, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("BOTTOMLEFT", x, y)
    button:SetText(L[label])
    button:SetScript("OnClick", callback)
    return button
end

local function CreateSetup()
    local panel = CreateFrame("Frame", "ForeverQuestPinsSetup", UIParent, "BackdropTemplate")
    panel:SetSize(500, 400)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    panel:SetBackdropBorderColor(0.8, 0.61, 0.3, 1)
    local background = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetPoint("TOPLEFT", 12, -12)
    background:SetPoint("BOTTOMRIGHT", -12, 12)
    background:SetColorTexture(0.055, 0.045, 0.035, 1)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 30, -26)
    title:SetText("|cffffd100Forever|r |cff65b9ffQuest Pins|r")
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 30, -65)
    local progress = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    progress:SetPoint("TOPRIGHT", -30, -67)
    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    help:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
    help:SetWidth(440)
    help:SetJustifyH("LEFT")
    local checks = {}
    local offsetSlider
    local function UpdateOffsetEnabled()
        local enabled = panel.pending.autoAccept and panel.pending.autoAcceptRangeEnabled
        offsetSlider:EnableMouse(enabled)
        offsetSlider:SetAlpha(enabled and 1 or 0.5)
    end
    for i = 1, 6 do
        local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        box:SetSize(26, 26)
        box:SetPoint("TOPLEFT", 28, -135 - (i - 1) * 31)
        if not box.Text then
            box.Text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            box.Text:SetPoint("LEFT", box, "RIGHT", 4, 1)
        end
        box.Text:SetWidth(410)
        box.Text:SetJustifyH("LEFT")
        box:SetScript("OnClick", function(self)
            panel.pending[self.key] = not not self:GetChecked()
            if self.key == "autoAccept" or self.key == "autoAcceptRangeEnabled" then
                UpdateOffsetEnabled()
            end
        end)
        checks[i] = box
    end
    offsetSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    offsetSlider:SetPoint("TOPLEFT", 46, -225)
    offsetSlider:SetSize(240, 16)
    offsetSlider:SetMinMaxValues(-5, 5)
    offsetSlider:SetValueStep(1)
    if offsetSlider.Low then offsetSlider.Low:SetText(L["-5 levels"]) end
    if offsetSlider.High then offsetSlider.High:SetText(L["+5 levels"]) end
    local offsetLabel = offsetSlider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    offsetLabel:SetPoint("BOTTOM", offsetSlider, "TOP", 0, 4)
    offsetSlider:SetScript("OnValueChanged", function(self, value)
        if self.syncing then return end
        value = math.max(-5, math.min(5, math.floor(value + 0.5)))
        panel.pending.autoAcceptLevelOffset = value
        offsetLabel:SetText((L["Maximum quest level: yours %+d"]):format(value))
    end)
    local back, nextButton
    local function Render()
        local page = panel.page
        local guided = page > 0
        panel:SetHeight(guided and 400 or 200)
        progress:SetText(guided and (page .. " / " .. #pages) or "")
        heading:SetText(guided and L[pages[page].title] or L["Choose your options"])
        help:SetText(guided and L["Choose what works for you. You can change these later in the addon options."]
            or L["Set up quest pins, use the defaults, or keep your current settings."])
        for i, box in ipairs(checks) do
            local option = guided and pages[page].options[i]
            if option then
                box:ClearAllPoints()
                local extra = page == #pages and i >= 3 and 64 or 0
                box:SetPoint("TOPLEFT", 28, -135 - (i - 1) * 31 - extra)
                box.key = option[1]
                box.Text:SetText(L[option[2]])
                box:SetChecked(panel.pending[box.key])
                box:Show()
            else
                box:Hide()
            end
        end
        offsetSlider:SetShown(page == #pages)
        if page == #pages then
            offsetSlider.syncing = true
            offsetSlider:SetValue(panel.pending.autoAcceptLevelOffset)
            offsetSlider.syncing = false
            offsetLabel:SetText((L["Maximum quest level: yours %+d"]):format(panel.pending.autoAcceptLevelOffset))
            UpdateOffsetEnabled()
        end
        panel.keep:SetShown(not guided)
        panel.defaults:SetShown(not guided)
        panel.guide:SetShown(not guided)
        back:SetShown(guided)
        nextButton:SetShown(guided)
        nextButton:SetText(L[page == #pages and "Apply" or "Next"])
    end
    panel.keep = MakeButton(panel, "Use Current Settings", 25, 30, 140, Complete)
    panel.defaults = MakeButton(panel, "Use Defaults", 180, 30, 140, function()
        ns.WipeSettings()
        if ns.SyncQuestTrackerCombatVisibility then ns.SyncQuestTrackerCombatVisibility() end
        if ns.RequestRefresh then ns.RequestRefresh("settings") end
        Complete()
    end)
    panel.guide = MakeButton(panel, "Choose Options", 335, 30, 140, function()
        panel.page = 1
        Render()
    end)
    back = MakeButton(panel, "Back", 25, 30, 140, function()
        panel.page = panel.page - 1
        Render()
    end)
    nextButton = MakeButton(panel, "Next", 335, 30, 140, function()
        if panel.page < #pages then
            panel.page = panel.page + 1
            Render()
            return
        end
        for key, value in pairs(panel.pending) do
            if value ~= panel.original[key] then ns.SetOption(key, value) end
        end
        Complete()
    end)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", Complete)
    panel.Begin = function(self)
        self.page, self.pending, self.original = 0, {}, {}
        for _, page in ipairs(pages) do
            for _, option in ipairs(page.options) do
                local value = not not ns.GetOption(option[1])
                self.pending[option[1]], self.original[option[1]] = value, value
            end
        end
        self.pending.autoAcceptLevelOffset = ns.GetOption("autoAcceptLevelOffset")
        self.original.autoAcceptLevelOffset = self.pending.autoAcceptLevelOffset
        Render()
        self:Show()
    end
    panel:Hide()
    return panel
end

function ns.ShowSetup()
    if not frame then frame = CreateSetup() end
    frame:Begin()
end

local function VersionNumber(version)
    if type(version) ~= "string" then return 0 end
    local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major then return 0 end
    return tonumber(major) * 100000000 + tonumber(minor) * 10000 + tonumber(patch)
end

function ns.StartWelcome()
    local news = ns.WhatsNew
    if news and VersionNumber(news.version) > VersionNumber(ns.db._newsVersion) then
        print("|cffffd100Forever Quest Pins:|r What is new in " .. news.version .. ":")
        for _, line in ipairs(news.lines) do print("  - " .. line) end
        ns.SaveWelcomeState(false, news.version)
    end
    if not ns.db._setupComplete then ns.ShowSetup() end
end
