local cases = {}
cases["eligibility_runtime.test_completed_id_list_wins_over_account_completion"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            C_QuestLog.GetAllCompletedQuestIDs = function() return { [1] = 3090 } end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.IsQuestFlaggedCompletedOnAccount = function()
                error('account completion must not be consulted')
            end
            assert(ns.IsQuestFlaggedCompleted(3090) == true)
            assert(ns.IsQuestFlaggedCompleted(2953) == false)

end
cases["eligibility_runtime.test_empty_completed_id_list_is_authoritative"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
            C_QuestLog.IsQuestFlaggedCompleted = function() return true end
            assert(ns.IsQuestFlaggedCompleted(2953) == false)

end
cases["eligibility_runtime.test_session_turn_in_hides_pin_when_completed_list_lags"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.IsOnQuest = function() return false end
            UnitLevel = function() return 60 end
            ns.GetOption = function() return true end
            local available = ns.IsQuestAvailable(2953, { minLevel = 1 })
            assert(available == true)
            ns.NoteQuestCompleted(2953)
            ns.InvalidateCompletionCache()
            assert(ns.IsQuestFlaggedCompleted(2953) == true)
            available, reason = ns.IsQuestAvailable(2953, { minLevel = 1 })
            assert(available == false and reason == 'completed')

end
cases["eligibility_runtime.test_session_accept_hides_offered_pin_when_log_lags"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.IsOnQuest = function() return false end
            UnitLevel = function() return 60 end
            ns.GetOption = function() return true end
            ns.NoteOfferedQuest(92499)
            local available, reason = ns.IsQuestAvailable(92499, { minLevel = 1 })
            assert(available == true and reason == 'npc-offered')
            ns.NoteQuestAccepted(92499)
            assert(ns.IsOffered(92499) == false)
            assert(ns.IsOnQuest(92499) == true)
            available, reason = ns.IsQuestAvailable(92499, { minLevel = 1 })
            assert(available == false and reason == 'in-log')
            ns.NoteQuestRemoved(92499)
            assert(ns.IsOnQuest(92499) == false)

end
cases["eligibility_runtime.test_legacy_completed_list_and_single_quest_fallback"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            GetQuestsCompleted = function()
                return { [2953] = true, [2966] = 1, [2970] = 2970 }
            end
            assert(ns.IsQuestFlaggedCompleted(2953) == true)
            assert(ns.IsQuestFlaggedCompleted(2966) == true)
            assert(ns.IsQuestFlaggedCompleted(2970) == true)
            assert(ns.IsQuestFlaggedCompleted(3090) == false)

end
cases["eligibility_runtime.test_single_quest_api_is_used_only_without_a_completed_list"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            C_QuestLog.IsQuestFlaggedCompleted = function(questID)
                return questID == 2953
            end
            assert(ns.IsQuestFlaggedCompleted(2953) == true)
            assert(ns.IsQuestFlaggedCompleted(3090) == false)

end
cases["eligibility_runtime.test_trivial_pins_hidden_when_nine_or_more_levels_below_player"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.GetOption = function(key)
                if key == 'trivialLevelGap' then return 9 end
                return key == 'showTrivial' and false or nil
            end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            local available, reason = ns.IsQuestAvailable(1, { minLevel = 21 })
            assert(available == false and reason == 'trivial')
            available, reason = ns.IsQuestAvailable(2, { minLevel = 22 })
            assert(available == true)
            assert(reason == 'ok' or reason == 'no-prereq')

end
cases["eligibility_runtime.test_trivial_pins_use_client_quest_level_without_db_min_level"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.GetOption = function(key)
                if key == 'trivialLevelGap' then return 9 end
                return key == 'showTrivial' and false or nil
            end
            UnitLevel = function() return 20 end
            UnitFactionGroup = function() return 'Horde' end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.GetQuestDifficultyLevel = function(questID)
                return questID == 8 and 5 or nil
            end
            local available, reason = ns.IsQuestAvailable(8, { faction = 'Horde' })
            assert(available == false and reason == 'trivial')

end
cases["eligibility_runtime.test_trivial_gap_uses_configured_option"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.GetOption = function(key)
                if key == 'trivialLevelGap' then return 5 end
                return key == 'showTrivial' and false or nil
            end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            local available, reason = ns.IsQuestAvailable(1, { minLevel = 25 })
            assert(available == false and reason == 'trivial')
            available = ns.IsQuestAvailable(2, { minLevel = 26 })
            assert(available == true)

end
cases["eligibility_runtime.test_hidden_quest_is_unavailable_even_when_offered"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.GetOption = function() return true end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            ns.IsQuestHidden = function(questID) return questID == 5 end
            ns.NoteOfferedQuest(5)
            local available, reason = ns.IsQuestAvailable(5, { minLevel = 1 })
            assert(available == false and reason == 'user-hidden')
            available, reason = ns.IsQuestAvailable(6, { minLevel = 1 })
            assert(available == true)

end
cases["eligibility_runtime.test_trivial_pins_shown_when_option_enabled"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.GetOption = function(key) return key == 'showTrivial' and true or nil end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            local available, reason = ns.IsQuestAvailable(1, { minLevel = 1 })
            assert(available == true)
            assert(reason == 'ok' or reason == 'no-prereq')

end
cases["eligibility_runtime.test_secret_unit_guid_does_not_crash_offer_capture"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            local secretGuid = 'Creature-0-0-0-0-3139-0000000000'
            issecretvalue = function(value) return value == secretGuid end
            UnitGUID = function(unit)
                if unit == 'npc' then return secretGuid end
            end
            C_Map = {
                GetBestMapForUnit = function() return 1 end,
                GetPlayerMapPosition = function()
                    return { x = 0.5, y = 0.25 }
                end,
            }
            ns.CaptureOfferContext()
            assert(ns.lastOffer ~= nil)
            assert(ns.lastOffer.qg == nil)
            assert(ns.lastOffer.mapID == 1)
            assert(ns.lastOffer.x == 50)
            assert(ns.lastOffer.y == 25)

            issecretvalue = function() return false end
            assert(ns.NpcIDFromGUID('Creature-0-0-0-0-3139-0000000000') == 3139)
            assert(ns.NpcIDFromGUID('Vehicle-0-0-0-0-417-0000000000') == 417)

end
cases["eligibility_runtime.test_secret_npc_name_is_ignored_without_being_cached"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            local secretName = 'secret npc name'
            issecretvalue = function(value) return value == secretName end
            C_TooltipInfo = {
                GetHyperlink = function()
                    return { lines = { { leftText = secretName } } }
                end,
            }
            assert(ns.GetNPCName(3139) == nil)

            C_TooltipInfo.GetHyperlink = function()
                return { lines = { { leftText = "Gar'Thok" } } }
            end
            assert(ns.GetNPCName(3139) == "Gar'Thok")

end
cases["pin_filters_runtime.test_category_defaults_and_saved_false_values"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            C_Map = { GetMapInfo = function() return { mapType = 3 } end }
            WorldMapFrame = { GetMapID = function() return 1 end }
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            for _, key in ipairs({ "showNormal", "showClass", "showProfession", "showDungeon" }) do
                assert(ns.GetOption(key) == true)
                ns.SetOption(key, false)
            end
            ns.db = nil
            ns.InitSettings()
            for _, key in ipairs({ "showNormal", "showClass", "showProfession", "showDungeon" }) do
                assert(ns.GetOption(key) == false)
            end

end
cases["pin_filters_runtime.test_category_filters_apply_to_offered_quests_and_preserve_other_categories"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.IsOffered = function() return true end
            local examples = {
                { "showNormal", {} },
                { "showClass", { classes = { 1 } } },
                { "showProfession", { requireSkill = 164 } },
                { "showDungeon", { isInstanceQuest = true } },
            }
            for _, example in ipairs(examples) do
                assert(ns.IsQuestAvailable(101, example[2]))
                ns.SetOption(example[1], false)
                local available, reason = ns.IsQuestAvailable(101, example[2])
                assert(not available and reason == "category-hidden")
                ns.SetOption(example[1], true)
            end
            ns.QuestTagCorrections = { [102] = 81 }
            assert(ns.IsQuestAvailable(102, {}))
            ns.SetOption("showDungeon", false)
            local available, reason = ns.IsQuestAvailable(102, {})
            assert(not available and reason == "category-hidden")
            ns.SetOption("showDungeon", true)
            ns.QuestTagCorrections = nil
            ns.InvalidateInstanceQuestCache()
            C_QuestLog.GetQuestTagInfo = function(questID)
                if questID == 103 then
                    return { tagID = 81, tagName = "Dungeon" }
                end
            end
            assert(ns.IsInstanceQuest(103, {}))
            C_QuestLog.GetQuestTagInfo = nil
            ns.InvalidateInstanceQuestCache()
            ns.SetOption("showNormal", false)
            for _, data in ipairs({ { repeatable = true }, { event = 1 },
                { isYearly = true }, { classes = { 1 } }, { requireSkill = 164 },
                { isInstanceQuest = true } }) do
                assert(ns.IsQuestAvailable(101, data))
            end
            ns.SetOption("showClass", false)
            assert(ns.IsQuestAvailable(101, { classes = { 1 }, isInstanceQuest = true }))
            ns.SetOption("showProfession", false)
            ns.SetOption("showClass", true)
            assert(ns.IsQuestAvailable(101, { classes = { 1 }, requireSkill = 164 }))

end
cases["pin_filters_runtime.test_map_menu_controls_share_saved_settings"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.MapPins.Clear = function() cleared = true end
            local modify
            Menu = { ModifyMenu = function(_, callback) modify = callback end }
            MenuUtil = { CreateCheckbox = function(label, selected, click)
                return { label = label, selected = selected, click = click,
                    SetEnabled = function(self, predicate) self.enabled = predicate end }
            end }
            assert(ns.TryRegisterWorldMapDropdown())
            local buttons = {}
            modify(nil, { CreateDivider = function() end, CreateTitle = function() end,
                Insert = function(_, button) table.insert(buttons, button) end })
            assert(#buttons == 10)
            assert(buttons[1].enabled == nil)
            assert(buttons[10].label == "Click pins to track quest starts")
            assert(buttons[10].enabled == nil)
            for i = 2, 9 do assert(buttons[i].enabled()) end
            ns.SetOption("enabled", false)
            for i = 2, 9 do assert(not buttons[i].enabled()) end
            ns.SetOption("enabled", true)
            for i = 2, 9 do assert(buttons[i].enabled()) end
            local keys = { "enabled", "showWorldMapPins", "showNormal", "showClass", "showDungeon",
                "showProfession", "showSeasonal", "showWarEffort", "showRepeatable", "enablePinTracking" }
            for i, button in ipairs(buttons) do
                assert(not button.label:find("Show", 1, true))
                local before = ns.GetOption(keys[i])
                assert(button.selected() == before)
                button.click()
                assert(ns.GetOption(keys[i]) == not before)
                assert(button.selected() == not before)
            end

end
cases["pin_filters_runtime.test_options_category_controls_disable_without_losing_selections"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            local controls = {}
            local function newRegion()
                return setmetatable({ SetAlpha = function(self, value) self.alpha = value end },
                    { __index = function() return function() end end })
            end
            CreateFrame = function(kind)
                local frame = { built = false, scripts = {}, Text = newRegion(), Low = newRegion(), High = newRegion() }
                frame.SetScript = function(self, name, callback) self.scripts[name] = callback end
                frame.GetScript = function(self, name) return self.scripts[name] end
                frame.SetEnabled = function(self, value) self.enabled = value end
                frame.SetChecked = function(self, value) self.checked = value end
                frame.CreateFontString = function() return newRegion() end
                setmetatable(frame, { __index = function() return function() end end })
                table.insert(controls, frame)
                return frame
            end
            Settings = {
                RegisterCanvasLayoutCategory = function() return {} end,
                RegisterAddOnCategory = function() end,
            }
            assert(ns.TryRegisterSettings())
            controls[1].scripts.OnShow(controls[1])
            ns.MapPins.Clear = function() end
            local categories = { showWorldMapPins = true, showNormal = true, showClass = true, showDungeon = true,
                showProfession = true, showSeasonal = true, showWarEffort = true, showRepeatable = true }
            ns.SetOption("showClass", false)
            ns.SetOption("enabled", false)
            local count = 0
            for _, control in ipairs(controls) do
                if categories[control.optionKey] then
                    count = count + 1
                    assert(control.enabled == false and control.Text.alpha == 0.5)
                    assert(control.checked == ns.GetOption(control.optionKey))
                end
            end
            assert(count == 8)
            ns.SetOption("enabled", true)
            for _, control in ipairs(controls) do
                if categories[control.optionKey] then
                    assert(control.enabled == true and control.Text.alpha == 1)
                end
            end
            assert(ns.GetOption("showClass") == false)

end
cases["pin_filters_runtime.test_world_map_option_survives_settings_reload"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            assert(ns.GetOption("showWorldMapPins"))
            ns.SetOption("showWorldMapPins", false)
            ns.db = nil
            ns.InitSettings()
            assert(ns.GetOption("showWorldMapPins") == false)

end
cases["pin_filters_runtime.test_gamepad_pin_callbacks_run_after_map_input_handling"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            C_Map = { GetMapInfo = function() return { mapType = 3 } end }
            WorldMapFrame = { GetMapID = function() return 1 end }
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            SoftCursor = { IsShown = function() return true end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function(frameType)
                if frameType == "GameTooltip" then
                    return {
                        Hide = function() gamepadTooltipHidden = (gamepadTooltipHidden or 0) + 1 end,
                        SetOwner = function() gamepadTooltipOwners = (gamepadTooltipOwners or 0) + 1 end,
                        SetText = function() end,
                        AddLine = function() end,
                        Show = function() gamepadTooltipShown = (gamepadTooltipShown or 0) + 1 end,
                    }
                end
                return { SetScript = function() end }
            end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.GetQuestTitle = function() return "Test quest" end
            ns.TrackQuest = function(questID) tracked = questID end
            local pin = { questID = 41, data = {}, IsShown = function() return true end }
            gamepadEnabled = true

            ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
            assert(#timerQueue == 0 and gamepadTooltipShown == nil,
                "gamepad tooltip display must wait for the cursor poll")
            ForeverQuestPinsMapPinMixin.OnMouseLeave(pin)
            assert(#timerQueue == 0)
            assert(tooltipOwners == nil and tooltipHidden == nil)
            assert(gamepadTooltipHidden == nil)

            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == nil)
            assert(type(timerQueue[1]) == "function")
            pin.questID = 42
            timerQueue[1]()
            table.remove(timerQueue, 1)
            assert(tracked == nil)
            pin.questID = 41

            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == nil)
            timerQueue[1]()
            table.remove(timerQueue, 1)
            assert(tracked == 41)

            gamepadEnabled = true
            SoftCursor.IsShown = function() return false end
            ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
            assert(tooltipOwners == nil and gamepadTooltipShown == nil,
                "Gamepad UI mouse hover must defer to the cursor poll when the soft cursor is hidden")
            ForeverQuestPinsMapPinMixin.OnMouseLeave(pin)
            assert(tooltipHidden == nil, "Gamepad UI mouse leave must leave tooltip cleanup to the cursor poll")

            gamepadEnabled = false
            SoftCursor = nil
            tracked = nil
            ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
            assert(tooltipOwners == 1, "mouse hover must continue to use the native GameTooltip outside Gamepad UI")
            ForeverQuestPinsMapPinMixin.OnMouseLeave(pin)
            assert(tooltipHidden == 1, "mouse leave must continue to hide the native GameTooltip outside Gamepad UI")
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == 41 and #timerQueue == 0)

end
cases["pin_filters_runtime.test_map_levels_and_missing_metadata"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            wipe = function(t) for k in pairs(t) do t[k] = nil end end
            WorldMapFrame = { GetMapID = function() return 947 end, IsShown = function() return true end }
            C_Map = { GetMapInfo = function() return mapInfo end }
            -- No usable canvas distinguishes allowed maps from filtered maps.
            ns.SetOption("showWorldMapPins", false)
            for _, mapType in ipairs({1, 2}) do
                mapInfo = { mapType = mapType }
                ns.MapPins:Refresh()
                assert(ns.MapPins:GetStatus().mode == "map-level-hidden")
                assert(ns.MapPins:GetStatus().count == 0)
            end
            for _, mapType in ipairs({0, 3, 4, 5, 6}) do
                mapInfo = { mapType = mapType }
                ns.MapPins:Refresh()
                assert(ns.MapPins:GetStatus().mode == "no-canvas")
            end
            mapInfo = nil
            ns.MapPins:Refresh()
            assert(ns.MapPins:GetStatus().mode == "no-canvas")
            C_Map.GetMapInfo = nil
            ns.MapPins:Refresh()
            assert(ns.MapPins:GetStatus().mode == "no-canvas")
            C_Map.GetMapInfo = function() return {mapType = 1} end
            ns.SetOption("showWorldMapPins", true)
            ns.MapPins:Refresh()
            assert(ns.MapPins:GetStatus().mode == "no-canvas")
            ns.SetOption("showWorldMapPins", false)
            InCombatLockdown = function() return true end
            ns.MapPins:Refresh()
            assert(ns.MapPins:GetStatus().mode == "combat-deferred")

end
cases["pin_filters_runtime.test_trivial_gap_restores_from_mirror_and_clamps"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end
use_mirror("revision=42;waypointProvider=blizzard;trivialLevelGap=5;enabled=1")

            assert(ns.InitSettings().trivialLevelGap == 5)
            ns.SetOption("trivialLevelGap", 1)
            assert(ns.GetOption("trivialLevelGap") == 3)
            ns.SetOption("trivialLevelGap", 99)
            assert(ns.GetOption("trivialLevelGap") == 15)
            ns.SetOption("trivialLevelGap", 6)
            assert(ForeverQuestPinsDB.trivialLevelGap == 6)
            assert(ForeverQuestPinsCharDB.trivialLevelGap == 6)
            assert(ForeverQuestPinsDB_Settings.trivialLevelGap == 6)
            assert(ForeverQuestPinsCharacterSettings.trivialLevelGap == 6)
            assert(mirror:find("trivialLevelGap=6", 1, true))

end
cases["pin_filters_runtime.test_out_of_range_mirror_gap_falls_back_to_default"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end
use_mirror("revision=42;waypointProvider=blizzard;trivialLevelGap=40;enabled=1")

            assert(ns.InitSettings().trivialLevelGap == 9)

end
cases["pin_filters_runtime.test_slash_trivial_sets_gap_and_bare_command_toggles"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.SlashCommand("trivial 5")
            assert(ns.GetOption("trivialLevelGap") == 5)
            assert(said("hiding quests 5+ levels below you"))
            ns.SlashCommand("trivial 40")
            assert(ns.GetOption("trivialLevelGap") == 15)
            assert(ns.GetOption("showTrivial") == false)
            ns.SlashCommand("trivial")
            assert(ns.GetOption("showTrivial") == true)
            assert(ns.GetOption("trivialLevelGap") == 15)

end
cases["pin_filters_runtime.test_hidden_quests_are_per_character_in_account_db"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            assert(ns.HideQuests({ 101, 102, 101 }) == 2)
            assert(ns.IsQuestHidden(101) and ns.IsQuestHidden(102))
            assert(ForeverQuestPinsDB.hiddenQuests["Thrall-Forever"][101] == true)
            assert(refreshes[#refreshes] == "quest-hidden")

            playerName = "Jaina"
            assert(not ns.IsQuestHidden(101))
            assert(ForeverQuestPinsDB.hiddenQuests["Jaina-Forever"] == nil)
            ns.HideQuests({ 201 })
            playerName = "Thrall"
            assert(not ns.IsQuestHidden(201))

            playerName = nil
            assert(ns.HideQuests({ 301 }) == 0)
            assert(not ns.IsQuestHidden(301))

end
cases["pin_filters_runtime.test_hidden_quests_survive_init_and_wipe_settings"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.HideQuests({ 101 })
            ns.SetOption("showTrivial", true)
            ns.WipeSettings()
            assert(ns.IsQuestHidden(101))

            ForeverQuestPinsCharDB._revision = 999
            ns.db = nil
            ns.InitSettings()
            assert(ns.db == ForeverQuestPinsDB)
            assert(ns.IsQuestHidden(101))

end
cases["pin_filters_runtime.test_reset_hidden_quest_pins_clears_only_current_character"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.HideQuests({ 101, 102 })
            playerName = "Jaina"
            ns.HideQuests({ 201 })
            playerName = "Thrall"
            assert(ns.ResetHiddenQuestPins() == 2)
            assert(not ns.IsQuestHidden(101) and not ns.IsQuestHidden(102))
            assert(ForeverQuestPinsDB.hiddenQuests["Thrall-Forever"] == nil)
            assert(said("Restored 2 hidden quest pin(s)."))
            playerName = "Jaina"
            assert(ns.IsQuestHidden(201))
            playerName = "Thrall"
            assert(ns.ResetHiddenQuestPins() == 0)

end
cases["pin_filters_runtime.test_unhide_one_and_slash_list"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.GetQuestTitle = function(questID) return questID == 101 and "Sharptusk" or nil end
            ns.HideQuests({ 102, 101 })
            local ids = ns.HiddenQuestIDs()
            assert(#ids == 2 and ids[1] == 101 and ids[2] == 102)
            ns.SlashCommand("hidden")
            assert(said("101 Sharptusk"))
            ns.SlashCommand("unhide 101")
            assert(not ns.IsQuestHidden(101) and ns.IsQuestHidden(102))
            ns.SlashCommand("unhide 999")
            assert(said("Quest 999 is not hidden"))
            ns.SlashCommand("unhide")
            assert(said("Usage: /fqp unhide"))
            ns.SlashCommand("unhidden")
            assert(said("Unknown command"))
            ns.SlashCommand("unhide all")
            assert(#ns.HiddenQuestIDs() == 0)
            ns.SlashCommand("hidden")
            assert(said("No hidden quest pins"))

end
cases["pin_filters_runtime.test_shift_click_hides_every_quest_on_stacked_pin"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            C_Map = { GetMapInfo = function() return { mapType = 3 } end }
            WorldMapFrame = { GetMapID = function() return 1 end }
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            local pin = { questID = 101, quests = { { id = 101 }, { id = 102 }, { id = 103 } } }
            pin.Hide = function(self) self.hidden = true end
            shift = true
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == nil)
            assert(ns.IsQuestHidden(101) and ns.IsQuestHidden(102) and ns.IsQuestHidden(103))
            assert(tooltipHidden and pin.hidden)
            assert(said("Hid 3 quest(s)."))
            assert(refreshes[#refreshes] == "quest-hidden")
            local available, reason = ns.IsQuestAvailable(102, { minLevel = 1 })
            assert(available == false and reason == "user-hidden")

end
cases["pin_filters_runtime.test_plain_click_still_tracks"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            C_Map = { GetMapInfo = function() return { mapType = 3 } end }
            WorldMapFrame = { GetMapID = function() return 1 end }
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            local pin = { questID = 101, quests = { { id = 101 }, { id = 102 } } }
            ForeverQuestPinsMapPinMixin.OnClick(pin, "RightButton")
            assert(tracked == nil)
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == 101)
            assert(not ns.IsQuestHidden(101) and not ns.IsQuestHidden(102))
            tracked = nil
            ns.SetOption("enablePinTracking", false)
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == nil)
            ns.SetOption("enablePinTracking", true)
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == 101)

end
cases["quest_info_runtime.test_offered_quests_repair_starters_without_map_coordinates"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.Quests[1]={qg=200, qgs={300}, mapID=1, x=10, y=20}
            ns.SetLastOfferNPC(100,nil,nil,nil)
            for id=1,3 do ns.NoteOfferedQuest(id) end
            assert(ns.IsOffered(1) and ns.IsOffered(2) and ns.IsOffered(3))
            assert(ns.Quests[1].qg==200 and ns.Quests[1].qgs[1]==300)
            assert(ns.Quests[1].mapID==1 and ns.Quests[1].x==10)
            assert(ns.Quests[1].qgs[2]==100)
            ns.NoteOfferedQuest(1)
            assert(#ns.Quests[1].qgs==2)
            assert(next(ns.ByMap)==nil)
            ns.SetLastOfferNPC(nil,nil,nil,nil)
            ns.NoteOfferedQuest(4)
            assert(ns.Quests[4]==nil)
            ns.SetLastOfferNPC(nil,1,25,30)
            ns.NoteOfferedQuest(5)
            assert(ns.ByMap[1][1]==5 and ns.Quests[5].qg==nil)

end
cases["quest_info_runtime.test_offered_quests_fill_coordless_records"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.Quests[7]={turnIns={100}}
            ns.SetLastOfferNPC(200,2521,42,23)
            ns.NoteOfferedQuest(7)
            assert(ns.Quests[7].qg==200)
            assert(ns.Quests[7].mapID==2521 and ns.Quests[7].x==42 and ns.Quests[7].y==23)
            assert(#ns.ByMap[2521]==1 and ns.ByMap[2521][1]==7)
            ns.NoteOfferedQuest(7)
            assert(#ns.ByMap[2521]==1)

end
cases["quest_info_runtime.test_npc_tooltip_deduplicates_accept_and_turn_in"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.options={showNPCTooltips=true}
            function ns.GetQuestDifficultyLevel(id) return 5 end
            function ns.GetQuestDifficultyRGB() return 1,1,1 end
            UnitGUID=function() return 'Creature-0-0-0-0-100-0000000000' end
            ns.NPCTooltips.GetAcceptRows=function()
                return { { id=20, text='[5] Quest 20', level=5, marker='!' } }
            end
            ns.NPCTooltips.GetTurnInRows=function()
                return { { id=20, text='[5] Quest 20', level=5, marker='?' } }
            end
            local lines={}
            GameTooltip={ AddLine=function(_, text) lines[#lines+1]=text end, Show=function() end }
            ns.NPCTooltips:AppendAcceptRows(GameTooltip, 'target')
            assert(#lines==1 and lines[1]=='! [5] Quest 20')

end
cases["quest_info_runtime.test_npc_tooltip_coordless_turn_in"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showNPCTooltips=true}
            ns.Quests={ [20]={ turnIns={100}, title='Coordless' } }
            ns.active={ [20]=true }
            ns.complete={ [20]=true }
            function ns.GetOption(key) return ns.options[key] end
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] and true or false end,
                IsQuestFlaggedCompleted=function() return false end,
                IsComplete=function(id) return ns.complete[id] and true or false end,
            }
            UnitLevel=function() return 20 end
            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.NPCTooltips:InvalidateStarterIndex()
            assert(#ns.NPCTooltips:GetTurnInRows(100)==1)

end
cases["quest_info_runtime.test_npc_tooltip_skips_instances"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.options={showNPCTooltips=true}
            function ns.GetOption(key) return ns.options[key] end
            UnitGUID=function() return 'Creature-0-0-0-0-100-0000000000' end
            IsInInstance=function() return true, 'party' end
            local lines={}
            GameTooltip={ AddLine=function(_, text) lines[#lines+1]=text end, Show=function() end }
            ns.NPCTooltips.GetAcceptRows=function() error('accept lookup must not run in an instance') end
            ns.NPCTooltips.GetTurnInRows=function() error('turn-in lookup must not run in an instance') end
            ns.NPCTooltips:AppendAcceptRows(GameTooltip, 'target')
            assert(#lines==0)

end
cases["quest_info_runtime.test_npc_tooltip_multiple_turn_in_npcs"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showNPCTooltips=true}
            ns.Quests={ [20]={ turnIns={100,101} } }
            ns.active={ [20]=true }
            ns.complete={ [20]=true }
            function ns.GetOption(key) return ns.options[key] end
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] and true or false end,
                IsQuestFlaggedCompleted=function() return false end,
                IsComplete=function(id) return ns.complete[id] and true or false end,
            }
            UnitLevel=function() return 20 end
            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.NPCTooltips:InvalidateStarterIndex()
            assert(#ns.NPCTooltips:GetTurnInRows(100)==1)
            assert(#ns.NPCTooltips:GetTurnInRows(101)==1)

end
cases["quest_info_runtime.test_instance_classification_prefers_runtime_tag"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.QuestTagCorrections={ [104]=81 }
            assert(ns.IsInstanceQuest(104, {}))
            C_QuestLog.GetQuestTagInfo=function()
                return { tagID=0, tagName="None" }
            end
            assert(ns.IsInstanceQuest(104, {}))
            ns.InvalidateInstanceQuestCache()
            C_QuestLog.GetQuestTagInfo=function()
                return { tagID=0, tagName="None" }
            end
            assert(ns.IsInstanceQuest(105, { isInstanceQuest=true }))
            assert(not ns.IsInstanceQuest(106, {}))

end
cases["quest_info_runtime.test_new_offered_quest_hides_when_accepted"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.SetLastOfferNPC(100,2521,42,23)
            ns.NoteOfferedQuest(92499)
            ns.NoteOfferedQuest(92499)
            assert(#ns.ByMap[2521]==1 and ns.ByMap[2521][1]==92499)
            assert(ns.IsQuestAvailable(92499, ns.Quests[92499]) == true)
            C_QuestLog.IsOnQuest=function() return true end
            local available, reason=ns.IsQuestAvailable(92499, ns.Quests[92499])
            assert(available == false and reason == 'in-log')

end
cases["quest_info_runtime.test_data_title_fallback_when_client_has_no_title"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.Quests = {
                [8171] = { title = "The Battle for Arathi Basin!" },
            }
            assert(ns.GetQuestTitle(8171) == "The Battle for Arathi Basin!")

end
cases["quest_info_runtime.test_client_title_wins_over_data_fallback"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.Quests = { [1] = { title = "Questie name" } }
            C_QuestLog.GetTitleForQuestID = function() return "Client name" end
            assert(ns.GetQuestTitle(1) == "Client name")

end
cases["quest_info_runtime.fallback_title_is_not_client_ready"] = function()
    dofile("tests/fixtures/quest_info.lua")
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    ns.Quests = { [1] = { title = "English title" } }
    local clientTitle
    local requests = 0
    C_QuestLog.RequestLoadQuestByID = function() requests = requests + 1 end
    C_QuestLog.GetTitleForQuestID = function() return clientTitle end
    local title, ready = ns.GetQuestTitle(1)
    assert(title == "English title" and not ready)
    assert(requests == 1)
    ns.OnQuestDataLoadFailed(1)
    for _ = 1, 5 do
        title, ready = ns.GetQuestTitle(1, true)
        assert(title == "English title" and not ready)
    end
    assert(requests == 1)
    clientTitle = "Título en español"
    title, ready = ns.GetQuestTitle(1)
    assert(title == "Título en español" and ready)
end
cases["quest_info_runtime.test_failed_title_load_retries_on_lookup_and_recovers"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            CreateFrame=function()
                frame={}
                function frame:SetScript(name,fn) self[name]=fn end
                function frame:RegisterEvent() end
                return frame
            end
            requests=0
            C_QuestLog.RequestLoadQuestByID=function() requests=requests+1 end
            assert(ns.GetQuestTitle(1)==nil and requests==1)

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,false)
            assert(requests==1)
            assert(ns.GetQuestTitle(1)==nil and requests==2)
            assert(ns.GetQuestTitle(1)==nil and requests==2)
            C_QuestLog.GetTitleForQuestID=function() return 'Loaded quest' end
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,true)
            assert(ns.GetQuestTitle(1)=='Loaded quest')

end
cases["quest_info_runtime.test_level_lookup_requests_data_once_and_never_uses_minimum"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            local requests=0
            C_QuestLog.GetQuestDifficultyLevel=function() return nil end
            C_QuestLog.RequestLoadQuestByID=function() requests=requests+1 end
            ns.Quests[1]={minLevel=5}
            assert(ns.GetQuestDifficultyLevel(1)==nil)
            assert(ns.GetQuestDifficultyLevel(1)==nil and requests==1)
            C_QuestLog.GetQuestDifficultyLevel=function() return 12 end
            assert(ns.GetQuestDifficultyLevel(1)==12)

end
cases["quest_info_runtime.test_required_profession_filters_only_when_skill_data_is_known"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            UnitRace=function() return 'Orc','Orc',2 end
            UnitClass=function() return 'Druid','DRUID',11 end
            UnitFactionGroup=function() return 'Horde' end
            UnitLevel=function() return 13 end
            IsPlayerSpell=function(spellID) return spellID == 9788 end
            GetProfessions=function() return 1,nil,nil,2 end
            GetProfessionInfo=function(index)
                local skillLine = index == 1 and 197 or 356
                return 'Profession',nil,1,75,nil,nil,skillLine
            end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            assert(ns.IsQuestAvailable(1,{requireSkill=197}) == true)
            assert(ns.IsQuestAvailable(5,{requireSkill=9788}) == true)
            local available, reason = ns.IsQuestAvailable(2,{requireSkill=164})
            assert(available == false and reason == 'profession')
            assert(ns.IsQuestAvailable(3,{requireSkill='NEW_PROFESSION'}) == true)
            GetProfessions=nil
            GetProfessionInfo=nil
            ns.InvalidateProfessionCache()
            assert(ns.IsQuestAvailable(4,{requireSkill=164}) == true)

end
cases["quest_info_runtime.test_skyborne_race_restrictions_filter_the_opposite_faction"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            UnitRace=function() return 'Skyborne','Skyborne',96 end
            UnitClass=function() return 'Hunter','HUNTER',3 end
            UnitFactionGroup=function() return 'Horde' end
            UnitLevel=function() return 10 end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            assert(ns.IsQuestAvailable(92598,{races={96}}) == true)
            local available, reason = ns.IsQuestAvailable(92597,{races={95}})
            assert(available == false and reason == 'race')

end
cases["quest_info_runtime.test_npc_offers_quest_accept_respects_starter_and_offered"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.Quests[7]={qg=197}
            assert(ns.NpcOffersQuestAccept(197, 7, ns.Quests[7]) == true)
            assert(ns.NpcOffersQuestAccept(198, 7, ns.Quests[7]) == false)
            ns.offeredQuestIDs[99]=true
            assert(ns.NpcOffersQuestAccept(555, 99, nil) == true)

end
cases["quest_info_runtime.test_npc_tooltip_accept_rows_skip_in_log_quests"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showNPCTooltips=true,showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            ns.Quests={}
            ns.active={}
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] end,
                IsQuestFlaggedCompleted=function() return false end,
            }
            UnitLevel=function() return 20 end
            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end
            function ns.GetQuestDifficultyRGB() return 1,1,1 end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.Quests[10]={qg=100}
            ns.NPCTooltips:InvalidateStarterIndex()
            local rows=ns.NPCTooltips:GetAcceptRows(100)
            assert(#rows==1 and rows[1].id==10)
            ns.active[10]=true
            rows=ns.NPCTooltips:GetAcceptRows(100)
            assert(#rows==0)

end
cases["quest_info_runtime.test_npc_tooltip_shows_in_log_turn_ins_and_accepts"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showNPCTooltips=true,showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            ns.Quests={}
            ns.active={}
            ns.complete={}
            function ns.GetOption(key) return ns.options[key] end
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] and true or false end,
                IsQuestFlaggedCompleted=function() return false end,
                IsComplete=function(id) return ns.complete[id] and true or false end,
            }
            UnitLevel=function() return 20 end
            UnitGUID=function() return 'Creature-0-0-0-0-100-0000000000' end
            lines={}
            GameTooltip={
                AddLine=function(_, text) lines[#lines+1]=text end,
                Show=function() end,
            }

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end
            function ns.GetQuestDifficultyRGB() return 1,0.8,0 end
            ns.Quests[10]={qg=100}
            ns.Quests[20]={turnIns={100}}
            ns.active[20]=true
            ns.complete[20]=true
            ns.NPCTooltips:InvalidateStarterIndex()
            ns.NPCTooltips:AppendAcceptRows(GameTooltip, 'target')
            assert(lines[1]=='! [5] Quest 10')
            assert(lines[2]=='? [5] Quest 20')
            assert(#lines==2)

            lines={}
            GameTooltip.fqpQuestRows=nil
            ns.Quests[10]=nil
            ns.active[20]=true
            ns.complete[20]=true
            ns.NPCTooltips:InvalidateStarterIndex()
            ns.NPCTooltips:AppendAcceptRows(GameTooltip, 'target')
            assert(#lines==1 and lines[1]=='? [5] Quest 20')

end
cases["quest_info_runtime.test_npc_tooltip_turn_ins_need_ready_state"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showNPCTooltips=true,showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            ns.Quests={ [20]={ turnIns={100} } }
            ns.active={ [20]=true }
            ns.complete={ [20]=false }
            function ns.GetOption(key) return ns.options[key] end
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] and true or false end,
                IsQuestFlaggedCompleted=function() return false end,
                IsComplete=function(id) return ns.complete[id] and true or false end,
            }
            UnitLevel=function() return 20 end
            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.NPCTooltips:InvalidateStarterIndex()
            assert(#ns.NPCTooltips:GetTurnInRows(100)==0)
            ns.complete[20]=true
            local rows=ns.NPCTooltips:GetTurnInRows(100)
            assert(#rows==1 and rows[1].marker=='?')

end
cases["quest_info_runtime.test_yearly_quests_stay_hidden_until_seasonal_pins_are_on"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showRepeatable=true,showSeasonal=false,showWarEffort=true,showTrivial=true}
            function ns.GetOption(key) return ns.options[key] end
            UnitLevel=function() return 60 end
            C_QuestLog={
                IsOnQuest=function() return false end,
                IsQuestFlaggedCompleted=function() return false end,
            }

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            local available, reason = ns.IsQuestAvailable(8673, {isYearly=true, minLevel=1})
            assert(available == false and reason == 'seasonal')
            available, reason = ns.IsQuestAvailable(155, {minLevel=14})
            assert(available == true and reason == 'no-prereq')

end
cases["quest_info_runtime.test_npc_id_from_secret_guid_returns_nil"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            issecretvalue=function() return true end
            assert(ns.NpcIDFromGUID('secret-guid')==nil)

end
cases["quest_info_runtime.test_failed_data_event_does_not_trigger_success_handler"] = function()
dofile("tests/fixtures/quest_info.lua")

            CreateFrame=function()
                frame={}
                function frame:SetScript(name, fn) self[name]=fn end
                function frame:RegisterEvent() end
                return frame
            end
            dataLoads=0
            ns.OnQuestDataLoad=function() dataLoads=dataLoads+1 end

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,false)
            assert(dataLoads==0)
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,true)
            frame.OnEvent(frame,'QUEST_DATA_LOAD',1)
            assert(dataLoads==2)

end
cases["quest_info_runtime.test_combat_hides_without_layout_changes_and_restores_original_alpha"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            assert(tracker.alpha == 0 and tracker.collapsed == false)
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.65 and tracker.collapsed == false)
            tracker.collapsed = true
            tracker.alpha = 0
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0 and tracker.collapsed == true)

end
cases["quest_info_runtime.test_disabling_option_during_combat_restores_tracker"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            inCombat = true
            ns.SyncQuestTrackerCombatVisibility()
            assert(tracker.alpha == 0)
            ns.hideTracker = false
            ns.SyncQuestTrackerCombatVisibility()
            assert(tracker.alpha == 0.65)
            tracker.alpha = 0.8
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.8)

end
cases["quest_info_runtime.test_disabled_option_leaves_tracker_untouched"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            ns.hideTracker = false
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.65)

end
cases["quest_info_runtime.test_missing_tracker_can_be_retried_and_original_frame_is_restored"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            ObjectiveTrackerFrame = nil
            ns.ApplyQuestTrackerCombatHide(true)
            ObjectiveTrackerFrame = {}
            ns.ApplyQuestTrackerCombatHide(true)
            ObjectiveTrackerFrame = tracker
            ns.ApplyQuestTrackerCombatHide(true)
            ObjectiveTrackerFrame = nil
            ns.ApplyQuestTrackerCombatHide(false)
            assert(tracker.alpha == 0.65)

end
cases["quest_info_runtime.test_quest_completion_and_level_up_refresh_leave_collapse_unchanged"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            refreshes = 0
            ns.MapPins = {Refresh=function(_, reason)
                assert(reason == 'PLAYER_LEVEL_UP' or reason == 'QUEST_TURNED_IN')
                refreshes = refreshes + 1
            end}
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'QUEST_TURNED_IN', 1)
            frame.OnUpdate(frame, 0.2)
            frame.OnEvent(frame, 'PLAYER_LEVEL_UP')
            frame.OnUpdate(frame, 0.2)
            assert(refreshes == 2 and tracker.alpha == 0)
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.65 and tracker.collapsed == false)

end
cases["quest_info_runtime.test_map_refresh_skips_quest_state_cache_invalidation"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            completion = 0
            profession = 0
            starter = 0
            ns.InvalidateCompletionCache = function() completion = completion + 1 end
            ns.InvalidateProfessionCache = function() profession = profession + 1 end
            ns.NPCTooltips = {InvalidateStarterIndex=function() starter = starter + 1 end}
            ns.MapPins = {Refresh=function() end}
            ns.RefreshNow('map-show')
            ns.RefreshNow('map-changed')
            ns.RefreshNow('canvas-zero')
            assert(completion == 0 and profession == 0 and starter == 0)
            ns.RefreshNow('QUEST_TURNED_IN')
            assert(completion == 1 and profession == 1 and starter == 0)

end
cases["quest_links_runtime.test_url_selection_and_validation"] = function()

            ns = {}
            CLOSE = "Close"
            StaticPopupDialogs = {}
            editBox = {
                SetText = function(_, text) copiedText = text end,
                SetFocus = function() focused = true end,
                HighlightText = function() selected = true end,
            }
            StaticPopup_Show = function(name, _, _, data)
                local dialog = { GetEditBox = function() return editBox end }
                StaticPopupDialogs[name].OnShow(dialog, data)
                return dialog
            end

assert(loadfile("QuestLinks.lua"))("ForeverQuestPins", ns)

            assert(ns.ShowWowheadQuestURL(8383))
            assert(copiedText == "https://www.wowhead.com/forever/quest=8383")
            assert(focused and selected)
            for _, id in ipairs({ 0, -1, 1.5, "8383", math.huge, 0/0 }) do
                assert(not ns.ShowWowheadQuestURL(id))
            end
            assert(not ns.ShowWowheadQuestURL(nil))
            assert(ns.ShowWowheadQuestURL(6))
            assert(copiedText == "https://www.wowhead.com/forever/quest=6")

end
cases["quest_links_runtime.test_delayed_registration_menu_scope_and_captured_quest"] = function()

            ns = {}
            CLOSE = "Close"
            StaticPopupDialogs = {}
            editBox = {
                SetText = function(_, text) copiedText = text end,
                SetFocus = function() focused = true end,
                HighlightText = function() selected = true end,
            }
            StaticPopup_Show = function(name, _, _, data)
                local dialog = { GetEditBox = function() return editBox end }
                StaticPopupDialogs[name].OnShow(dialog, data)
                return dialog
            end

assert(loadfile("QuestLinks.lua"))("ForeverQuestPins", ns)

            assert(not ns.TryRegisterQuestLinks())
            local owner = {}
            local hooks = {}
            local registrations = 0
            QuestObjectiveTracker = {
                OnBlockHeaderEnter = function() end,
                OnBlockHeaderLeave = function() end,
                GetContextMenuParent = function() return owner end,
            }
            hooksecurefunc = function(_, name, callback) hooks[name] = callback end
            Menu = { ModifyMenu = function(tag, callback)
                assert(tag == "MENU_QUEST_OBJECTIVE_TRACKER")
                registrations = registrations + 1
                modify = callback
            end }
            assert(ns.TryRegisterQuestLinks())
            assert(ns.TryRegisterQuestLinks() and registrations == 1)
            local buttons = {}
            local root = {
                CreateDivider = function() end,
                CreateButton = function(_, label, callback)
                    assert(label == "Copy Wowhead URL")
                    table.insert(buttons, callback)
                end,
            }
            modify(owner, root)
            assert(#buttons == 0)
            local block = { id = 8383 }
            hooks.OnBlockHeaderEnter(QuestObjectiveTracker, block)
            modify({}, root)
            assert(#buttons == 0)
            modify(owner, root)
            assert(#buttons == 1)
            block.id = 6
            hooks.OnBlockHeaderLeave(QuestObjectiveTracker, block)
            buttons[1]()
            assert(copiedText == "https://www.wowhead.com/forever/quest=8383")
            modify(owner, root)
            assert(#buttons == 1)
            hooks.OnBlockHeaderEnter(QuestObjectiveTracker, block)
            modify(owner, root)
            buttons[2]()
            assert(copiedText == "https://www.wowhead.com/forever/quest=6")

end
cases["waypoints_runtime.test_start_coordinates_and_native_accept_handoff"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            assert(ns.TrackQuest(1))
            assert(waypoint.uiMapID==1412 and waypoint.position.x==54.4/100)
            assert(waypoint.position.y==60.4/100 and userTracked)
            onQuest=true
            ns.UpdateWaypoint()
            assert(waypoint==nil and trackedQuest==1 and added==0)
            ns.UpdateWaypoint()
            assert(added==0)
            ns.OnWaypointQuestEnded(1)
            assert(trackedQuest==0)

end
cases["waypoints_runtime.test_manual_pin_and_quest_changes_are_respected"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            ns.TrackQuest(1)
            waypoint=UiMapPoint.CreateFromCoordinates(1,0.2,0.3)
            onQuest=true
            ns.UpdateWaypoint()
            assert(trackedQuest==nil and waypoint.uiMapID==1)
            ns.ClearWaypoint()
            assert(waypoint.uiMapID==1)
            assert(ns.TrackQuest(1))
            trackedQuest=2
            ns.ClearWaypoint()
            assert(trackedQuest==2)

end
cases["waypoints_runtime.test_other_quest_tracking_cancels_accept_handoff"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            ns.TrackQuest(1)
            C_SuperTrack.SetSuperTrackedQuestID(2)
            onQuest=true
            ns.UpdateWaypoint()
            assert(trackedQuest==2)

end
cases["waypoints_runtime.test_tomtom_updates_objective_turnin_and_removes_only_owned_uid"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            provider="tomtom"
            assert(ns.TrackQuest(1))
            assert(added==1 and not last.opts.persistent and last.opts.crazy)
            local start=last
            onQuest=true; nextMap=1411; nextX=0.4; nextY=0.5
            ns.UpdateWaypoint()
            assert(added==2 and removedUID==start and last.map==1411)
            ns.UpdateWaypoint()
            assert(added==2)
            nextX=0.6
            ns.UpdateWaypoint()
            assert(added==3 and last.x==0.6)
            ns.OnWaypointQuestEnded(2)
            assert(removed==2)
            ns.OnWaypointQuestEnded(1)
            assert(removed==3)

end
cases["waypoints_runtime.test_missing_objective_does_not_reuse_start_and_recovers"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            provider="tomtom"; ns.TrackQuest(1); onQuest=true
            ns.UpdateWaypoint()
            assert(removed==1 and added==1)
            nextMap=1412; nextX=0.3; nextY=0.4
            ns.UpdateWaypoint()
            assert(added==2)

end
cases["waypoints_runtime.test_missing_provider_unsupported_map_and_invalid_location"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            provider="tomtom"; TomTom=nil
            assert(not ns.TrackQuest(1) and #messages==1)
            provider="blizzard"; C_Map.CanSetUserWaypointOnMap=function() return false end
            assert(not ns.TrackQuest(1) and waypoint==nil)
            C_Map.SetUserWaypoint=nil
            assert(not ns.TrackQuest(1))
            ns.Quests[1].x=101
            assert(not ns.TrackQuest(1))
            assert(not ns.TrackQuest(nil))

end
cases["waypoints_runtime.test_provider_setting_persists_and_validates"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)
assert(loadfile("Config.lua"))("ForeverQuestPins", ns)

            assert(ns.InitSettings().waypointProvider=="blizzard")
            ns.SetOption("waypointProvider","tomtom")
            assert(ForeverQuestPinsCharDB.waypointProvider=="tomtom")
            assert(ForeverQuestPinsDB_Settings.waypointProvider=="tomtom")
            ns.SetOption("waypointProvider","invalid")
            assert(ns.GetOption("waypointProvider")=="tomtom")
            ns.WipeSettings()
            assert(ns.GetOption("waypointProvider")=="blizzard")

end
cases["waypoints_runtime.test_provider_recovers_from_cvar_mirror"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            mirror="revision=42;waypointProvider=tomtom;enabled=1"
            C_CVar={GetCVar=function() return mirror end,
                SetCVar=function(_,text) mirror=text end, RegisterCVar=function() end}

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)

            assert(ns.InitSettings().waypointProvider=="tomtom")
            assert(mirror:find("waypointProvider=tomtom",1,true))
            ns.SetOption("waypointProvider","blizzard")
            assert(mirror:find("waypointProvider=blizzard",1,true))

end
cases["waypoints_runtime.test_navigation_checkbox_uses_shared_cvar_without_overriding_it"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            navigation="0"
            C_CVar={GetCVar=function(key)
                    if key=="showInGameNavigation" then return navigation end
                    return ""
                end,
                SetCVar=function(key,value)
                    if key=="showInGameNavigation" then navigation=value end
                end,
                RegisterCVar=function() end}

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)

            ns.InitSettings()
            assert(navigation=="0" and not ns.GetOption("showInGameNavigation"))
            ns.SetOption("showInGameNavigation",true)
            assert(navigation=="1" and ns.GetOption("showInGameNavigation"))
            navigation="0"
            assert(not ns.GetOption("showInGameNavigation"))
            ns.SetOption("showInGameNavigation",false)
            assert(navigation=="0")
            C_CVar=nil
            assert(not ns.GetOption("showInGameNavigation"))
            ns.SetOption("showInGameNavigation",true)
            assert(#messages==1)

end
local function tooltipHas(text)
    for _, line in ipairs(tooltipLines or {}) do
        if line == text then
            return true
        end
    end
    return false
end

local function setupPinRendering()
    options = { enabled = true, showWorldMapPins = true, showRepeatable = true,
        showNormal = true, showClass = true, showProfession = true, showDungeon = true,
        showSeasonal = true, showWarEffort = true, showTrivial = true, showSpawnClusters = true,
        iconScale = 100 }
    local function texture()
        return {
            SetAllPoints = function() end, Hide = function(self) self.shown = false end,
            Show = function(self) self.shown = true end,
            IsShown = function(self) return self.shown == true end,
            ClearAllPoints = function() end,
            SetPoint = function(self, ...) self.point = { ... } end,
            SetSize = function(self, width, height) self.width, self.height = width, height end,
            SetAtlas = function(self, name) self.atlas = name end,
            SetTexture = function(self, name) self.file = name end,
            SetColorTexture = function(self, r, g, b, a) self.colorTexture = { r, g, b, a } end,
            SetDesaturated = function(self, value) self.desaturated = value end,
            SetVertexColor = function(self, r, g, b, a) self.color = { r, g, b, a } end,
            SetDrawLayer = function() end, SetBlendMode = function() end,
            SetAlpha = function(self, value) self.alpha = value end, SetTexCoord = function() end,
        }
    end
    local function fontString()
        return {
            SetPoint = function() end, SetJustifyH = function() end,
            SetShadowColor = function() end, SetShadowOffset = function() end,
            SetTextColor = function() end, SetDrawLayer = function() end,
            SetScale = function() end, SetAlpha = function() end,
            SetText = function(self, text) self.text = text end,
            GetText = function(self) return self.text end,
            Show = function(self) self.shown = true end,
            Hide = function(self) self.shown = false end,
            IsShown = function(self) return self.shown == true end,
        }
    end
    local function frame()
        return {
            SetScript = function(self, event, fn) self.scripts = self.scripts or {}; self.scripts[event] = fn end,
            RegisterForClicks = function() end,
            EnableMouse = function(self, enabled) self.mouseEnabled = enabled; self.clickEnabled = enabled end,
            SetMouseClickEnabled = function(self, enabled) self.clickEnabled = enabled end, SetParent = function(self, parent) self.parent = parent end,
            CreateTexture = function(self)
                local created = texture()
                self.textures = self.textures or {}
                self.textures[#self.textures + 1] = created
                return created
            end,
            CreateFontString = function() return fontString() end,
            SetSize = function(self, width, height) self.width, self.height = width, height end,
            SetScale = function(self, scale) self.scale = scale end,
            GetScale = function(self) return self.scale or 1 end,
            GetEffectiveScale = function(self) return self.scale or 1 end,
            GetCenter = function(self) return self.centerX, self.centerY end,
            GetLeft = function(self) return self.left or 0 end,
            GetTop = function(self) return self.top or 0 end,
            SetIgnoreParentScale = function() end, SetFrameLevel = function() end,
            SetFrameStrata = function(self, strata) self.strata = strata end, SetAlpha = function() end,
            Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
            IsShown = function(self) return self.shown == true end,
            ClearAllPoints = function() end,
            SetPoint = function(self, ...) self.point = { ... } end, GetParent = function(self) return self.parent end,
            GetFrameLevel = function() return 1 end, GetFrameStrata = function() return "LOW" end,
        }
    end
    local canvas = frame()
    canvas.GetWidth = function() return 1000 end
    canvas.GetHeight = function() return 800 end
    UIParent = frame()
    UIParent.GetEffectiveScale = function() return 1 end
    cloudFrames = {}
    mapCanvas = canvas
    local map = frame()
    map.GetCanvas = function() return canvas end
    map.GetMapID = function() return 1 end
    map.IsShown = function() return true end
    map.ScrollContainer = {}
    WorldMapFrame = map
    CreateFrame = function(_, _, parent)
        local created = frame()
        created.parent = parent
        if parent == UIParent then
            cloudFrames[#cloudFrames + 1] = created
        elseif parent then
            pin = created
            created.centerX, created.centerY = 500, 400
        end
        return created
    end
    C_QuestLog = {
        GetAllCompletedQuestIDs = function() return {} end,
        IsOnQuest = function() return false end,
    }
    C_Map = {
        GetMapInfo = function() return { mapType = 3 } end,
        GetPlayerMapPosition = function()
            return { GetXY = function() return 0.5, 0.5 end }
        end,
    }
    tooltipLines = {}
    GameTooltip = {
        SetOwner = function() end,
        SetText = function(_, text) tooltipLines = { text } end,
        AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
        Show = function() end, Hide = function() end,
    }
    UnitLevel = function() return 60 end
    wipe = function(value) for key in pairs(value) do value[key] = nil end end
    trackedQuestID = nil
    trackedData = nil
    ns = {
        Quests = { [101] = { mapID = 1, x = 50, y = 50, repeatable = true } },
        ByMap = { [1] = { 101 } },
        GetOption = function(key) return options[key] end,
        GetQuestTitle = function() return "Repeatable test quest" end,
        PrefetchQuestInfo = function() end,
        RequestRefresh = function() end,
        IsQuestHidden = function() return false end,
        TrackQuest = function(questID, data) trackedQuestID, trackedData = questID, data end,
    }
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)
end

cases["map_pins_runtime.tracking_respects_map_level"] = function()
    setupPinRendering()
    local mapType = 3
    C_Map.GetMapInfo = function() return { mapType = mapType } end
    ns.MapPins:Refresh("zone")
    assert(pin.mouseEnabled == true and pin.clickEnabled == true)
    pin.scripts.OnClick(pin, "LeftButton")
    assert(trackedQuestID == 101)
    trackedQuestID = nil
    for _, value in ipairs({ 1, 2 }) do
        mapType = value
        ns.MapPins:Refresh("world")
        assert(pin.mouseEnabled == true and pin.clickEnabled == false)
        pin.scripts.OnClick(pin, "LeftButton")
        assert(trackedQuestID == nil)
    end
    options.trackOnWorldMaps = true
    ns.MapPins:Refresh("allowed")
    assert(pin.mouseEnabled == true and pin.clickEnabled == true)
    pin.scripts.OnClick(pin, "LeftButton")
    assert(trackedQuestID == 101)
    options.enablePinTracking = false
    ns.MapPins:Refresh("disabled")
    assert(pin.mouseEnabled == true and pin.clickEnabled == false)
    pin.scripts.OnEnter(pin)
    assert(tooltipLines[1] == "Quest")
    for _, line in ipairs(tooltipLines) do
        assert(not line:find("Click to track", 1, true))
    end
end

cases["map_pins_runtime.delayed_title_updates_hover_without_request_loop"] = function()
    setupPinRendering()
    ns.Quests[101].title = "English title"
    local clientTitle
    local requests = 0
    C_QuestLog.GetTitleForQuestID = function() return clientTitle end
    C_QuestLog.RequestLoadQuestByID = function() requests = requests + 1 end
    ns.MapPins:Refresh("title")
    pin.scripts.OnEnter(pin)
    assert(tooltipHas("English title"))
    ns.OnQuestDataLoadFailed(101)
    local previousRequests = requests
    for _ = 1, 5 do ns.MapPins:SnapToQuestGivers() end
    assert(requests == previousRequests)
    clientTitle = "Título en español"
    ns.MapPins:SnapToQuestGivers()
    assert(tooltipHas("Título en español"))
end

cases["map_pins_runtime.icon_scale_changes_rendered_pin_size"] = function()
    setupPinRendering()
    local acquiredPin = {
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        SetAlpha = function() end,
    }
    ForeverQuestPinsMapPinMixin.OnAcquired(acquiredPin)
    assert(acquiredPin.width == 24 and acquiredPin.height == 24)
    options.iconScale = 50
    ForeverQuestPinsMapPinMixin.OnAcquired(acquiredPin)
    assert(acquiredPin.width == 12 and acquiredPin.height == 12)
    options.iconScale = 150
    ForeverQuestPinsMapPinMixin.OnAcquired(acquiredPin)
    assert(acquiredPin.width == 36 and acquiredPin.height == 36)
end

cases["map_pins_runtime.gamepad_cursor_cannot_read_addon_pin_centers"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    pin._fqpGetCenter = function() return 320, 240 end
    WorldMapFrame.ScrollContainer.GetGamepadCursorPosition = function() return 325, 240 end
    SoftCursor = { IsShown = function() return true end }
    assert(ns.MapPins:FindGamepadCursorPin() == pin, "addon hover lookup must still find the pin")
    local gamepadTooltipShown, gamepadTooltipHidden = 0, 0
    CreateFrame = function(frameType)
        if frameType == "GameTooltip" then
            return {
                SetOwner = function() end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() gamepadTooltipShown = gamepadTooltipShown + 1 end,
                Hide = function() gamepadTooltipHidden = gamepadTooltipHidden + 1 end,
            }
        end
        return { SetScript = function() end }
    end
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    ns.MapPins:UpdateGamepadHover()
    assert(gamepadTooltipShown == 1, "gamepad hover must display the private quest tooltip")
    WorldMapFrame.ScrollContainer.GetGamepadCursorPosition = function() return 400, 240 end
    assert(ns.MapPins:FindGamepadCursorPin() == nil, "cursor lookup must ignore pins outside Blizzard's hover radius")
    ns.MapPins:UpdateGamepadHover()
    assert(gamepadTooltipHidden == 1, "leaving the pin must hide the private quest tooltip")
    WorldMapFrame.ScrollContainer.GetGamepadCursorPosition = function() return 320, 240 end
    SoftCursor.IsShown = function() return false end
    assert(ns.MapPins:FindGamepadCursorPin() == nil, "cursor lookup must stop when the soft cursor is hidden")
    SoftCursor.IsShown = function() return true end
    GetCVarBool = function() return true end
    assert(ns.MapPins:FindGamepadCursorPin() == pin, "addon map tooltips must remain available when Blizzard suppresses its gamepad tooltips")
    GetCVarBool = nil
    local acquiredPin = {
        GetCenter = function() return 320, 240 end,
        UseFrameLevelType = function() end,
        SetScalingLimits = function() end,
        SetSize = function() end,
        SetAlpha = function() end,
        Texture = { ClearAllPoints = function() end, SetAllPoints = function() end },
    }
    ForeverQuestPinsMapPinMixin.OnLoad(acquiredPin)
    assert(acquiredPin:GetCenter() == nil, "gamepad cursor must not discover addon pin")
    assert(acquiredPin._fqpGetCenter(acquiredPin) == 320)
end

cases["map_pins_runtime.gamepad_hover_uses_normalized_world_map_cursor"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    SoftCursor = { IsShown = function() return false end }
    WorldMapFrame.GetNormalizedGamepadCursorPosition = function() return 0.5, 0.5 end

    assert(WorldMapFrame.ScrollContainer.GetGamepadCursorPosition == nil,
        "the Forever client exposes normalized cursor position on WorldMapFrame")
    assert(ns.MapPins:FindGamepadCursorPin() == pin,
        "gamepad hover must resolve a pin using the normalized map cursor")
end

cases["map_pins_runtime.gamepad_ui_mouse_hover_uses_map_cursor"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    SoftCursor = { IsShown = function() return true end, IsMoving = function() return false end }
    WorldMapFrame.GetNormalizedGamepadCursorPosition = function() return 0.8, 0.8 end
    WorldMapFrame.GetNormalizedCursorPosition = function() return 0.5, 0.5 end
    WorldMapFrame.ScrollContainer.IsMouseOver = function() return true end
    GetCVarBool = function() return true end

    local tooltipShown = 0
    CreateFrame = function(frameType)
        if frameType == "GameTooltip" then
            return {
                SetOwner = function() end,
                SetFrameStrata = function() end,
                SetAnchorType = function() end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() tooltipShown = tooltipShown + 1 end,
                Hide = function() end,
            }
        end
        return { SetScript = function() end }
    end

    ns.MapPins:UpdateGamepadHover()
    assert(tooltipShown == 1, "mouse hover inside the map must show an addon tooltip while Gamepad UI is enabled")
end

cases["map_pins_runtime.gamepad_ui_mouse_enter_defers_to_private_tooltip_poll"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    SoftCursor = { IsShown = function() return false end, IsMoving = function() return false end }
    WorldMapFrame.GetNormalizedGamepadCursorPosition = function() return 0.8, 0.8 end
    WorldMapFrame.GetNormalizedCursorPosition = function() return 0.5, 0.5 end
    WorldMapFrame.ScrollContainer.IsMouseOver = function() return true end

    local globalTooltipOwners, privateTooltipShown = 0, 0
    GameTooltip = {
        SetOwner = function() globalTooltipOwners = globalTooltipOwners + 1 end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
    }
    CreateFrame = function(frameType)
        if frameType == "GameTooltip" then
            return {
                SetOwner = function() end,
                SetFrameStrata = function() end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() privateTooltipShown = privateTooltipShown + 1 end,
                Hide = function() end,
            }
        end
        return { SetScript = function() end }
    end

    ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
    assert(globalTooltipOwners == 0,
        "Gamepad UI must defer mouse-enter tooltips even when the soft cursor is hidden")
    ns.MapPins:UpdateGamepadHover()
    assert(privateTooltipShown == 1,
        "the cursor poll must show the private tooltip after the mouse-enter event")
end

cases["map_pins_runtime.gamepad_mode_transition_replaces_existing_mouse_tooltip"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    local gamepadEnabled = false
    InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
    SoftCursor = { IsShown = function() return false end, IsMoving = function() return false end }
    WorldMapFrame.GetNormalizedGamepadCursorPosition = function() return 0.8, 0.8 end
    WorldMapFrame.GetNormalizedCursorPosition = function() return 0.5, 0.5 end
    WorldMapFrame.ScrollContainer.IsMouseOver = function() return true end

    local privateTooltipShown = 0
    CreateFrame = function(frameType)
        if frameType == "GameTooltip" then
            return {
                SetOwner = function() end,
                SetFrameStrata = function() end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() privateTooltipShown = privateTooltipShown + 1 end,
                Hide = function() end,
            }
        end
        return { SetScript = function() end }
    end

    ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
    gamepadEnabled = true
    ns.MapPins:UpdateGamepadHover()
    assert(privateTooltipShown == 1,
        "the gamepad poll must replace an existing mouse tooltip when the input mode changes")
end

cases["map_pins_runtime.gamepad_mode_keeps_pins_out_of_blizzard_pin_pool"] = function()
    setupPinRendering()
    local previousMixin = MapCanvasPinMixin
    local previousAcquirePin = WorldMapFrame.AcquirePin
    local previousRemovePin = WorldMapFrame.RemovePin
    local previousInputUtil = InputUtil
    local acquireCalls, removeCalls = 0, 0
    MapCanvasPinMixin = { GetCenter = function(self) return self.centerX, self.centerY end }
    WorldMapFrame.AcquirePin = function()
        acquireCalls = acquireCalls + 1
        error("gamepad pins must not use WorldMapFrame:AcquirePin")
    end
    WorldMapFrame.RemovePin = function() removeCalls = removeCalls + 1 end
    InputUtil = { IsGamepadUIEnabled = function() return true end }

    ns.MapPins:Refresh("gamepad-test")
    assert(acquireCalls == 0, "gamepad pins must bypass Blizzard's MapCanvas pin pool")
    assert(pin and pin.parent == mapCanvas and not pin.managed,
        "gamepad pins must be ordinary frames parented to the map canvas")
    assert(pin.scripts.OnClick == ForeverQuestPinsMapPinMixin.OnClick,
        "ordinary gamepad-mode pins must keep the addon's click handler")

    ns.MapPins:Clear()
    assert(removeCalls == 0, "ordinary gamepad-mode pins must not call WorldMapFrame:RemovePin")

    MapCanvasPinMixin = previousMixin
    WorldMapFrame.AcquirePin = previousAcquirePin
    WorldMapFrame.RemovePin = previousRemovePin
    InputUtil = previousInputUtil
end

cases["map_pins_runtime.pin_center_is_hidden_when_map_canvas_acquires_a_pin"] = function()
    setupPinRendering()
    local acquiredPin = {
        GetCenter = function() return 320, 240 end,
        SetSize = function() end,
        SetAlpha = function() end,
    }
    ForeverQuestPinsMapPinMixin.OnAcquired(acquiredPin)
    assert(acquiredPin:GetCenter() == nil, "the gamepad cursor must not discover an acquired addon pin")
    assert(acquiredPin._fqpGetCenter(acquiredPin) == 320, "addon hover detection must retain the real center")
end

cases["map_pins_runtime.gamepad_cursor_poll_owns_tooltip_lifecycle"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    local tooltipShown, tooltipHidden, tooltipOwner, tooltipName = 0, 0, nil, nil
    CreateFrame = function(frameType, name)
        if frameType == "GameTooltip" then
            tooltipName = name
            return {
                SetOwner = function(_, owner, anchor)
                    tooltipOwner = { owner = owner, anchor = anchor }
                end,
                SetFrameStrata = function() end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() tooltipShown = tooltipShown + 1 end,
                Hide = function() tooltipHidden = tooltipHidden + 1 end,
            }
        end
        return { SetScript = function() end }
    end
    local timerQueue = {}
    C_Timer = { After = function(_, callback) timerQueue[#timerQueue + 1] = callback end }
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    SoftCursor = { IsShown = function() return true end }
    local pinX, pinY = pin._fqpGetCenter(pin)
    WorldMapFrame.ScrollContainer.GetGamepadCursorPosition = function() return pinX, pinY end
    ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
    assert(#timerQueue == 0 and tooltipShown == 0,
        "gamepad pin enter must leave tooltip ownership to the cursor poll")
    ns.MapPins:UpdateGamepadHover()
    assert(tooltipShown == 1, "the cursor poll must show the quest tooltip for the pin under the cursor")
    assert(tooltipOwner and tooltipOwner.owner == pin and tooltipOwner.anchor == "ANCHOR_RIGHT",
        "the private gamepad tooltip must be anchored to the hovered pin")
    assert(tooltipName == "ForeverQuestPinsGamepadTooltip",
        "the private tooltip must have a frame name so its template text regions are created")
    ForeverQuestPinsMapPinMixin.OnMouseLeave(pin)
    assert(tooltipHidden == 0, "pin leave must not immediately hide the gamepad tooltip")
    ns.MapPins:UpdateGamepadHover()
    assert(tooltipShown == 1, "the cursor poll must not duplicate the active pin tooltip")
    WorldMapFrame.ScrollContainer.GetGamepadCursorPosition = function() return 300, 300 end
    ns.MapPins:UpdateGamepadHover()
    assert(tooltipHidden == 1, "moving the gamepad cursor off the pin must hide the tooltip")
end

cases["map_pins_runtime.repeatable_pin_is_blue_and_hidden_when_opted_out"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("test")
    assert(ns.MapPins:GetStatus().count == 1)
    assert(ns.MapPins:GetStatus().icon == "atlas:QuestNormal:blue")
    assert(pin.Texture.desaturated == true)
    assert(pin.Texture.color[1] == 0.12 and pin.Texture.color[2] == 0.72 and pin.Texture.color[3] == 1.00)
    options.showRepeatable = false
    ns.MapPins:Refresh("test-filter")
    assert(ns.MapPins:GetStatus().count == 0)
    assert(ns.MapPins:GetStatus().paintedIDs[101] == nil)
end

cases["map_pins_runtime.nearby_spawn_points_share_one_counted_pin_and_hover_cloud"] = function()
    setupPinRendering()
    ns.Quests = {
        [101] = {
            mapID = 1, x = 50, y = 50, title = "Spawn test",
            coords = { { 50, 50, 1 }, { 50.4, 50.1, 1 }, { 50.8, 50.2, 1 } },
        },
    }
    ns.ByMap = { [1] = { 101 } }
    options.showSpawnClusters = true

    ns.MapPins:Refresh("spawn-cluster")
    local status = ns.MapPins:GetStatus()
    assert(status.count == 1, "cluster pins " .. tostring(status.count))
    assert(pin.spawnCount == 3, "spawn count " .. tostring(pin.spawnCount))
    assert(pin.Badge == nil, "count badge should not be drawn")
    assert(status.cloudCount == 0, "cloud before hover " .. tostring(status.cloudCount))

    pin.scripts.OnEnter(pin)
    assert(status.cloudCount == 3, "cloud after hover " .. tostring(status.cloudCount))
    assert(tooltipHas("3 possible spawn locations"), "tooltip count line")
    pin.scripts.OnLeave(pin)
    assert(status.cloudCount == 0, "cloud after leave " .. tostring(status.cloudCount))
end

cases["pin_filters_runtime.spawn_cluster_option_defaults_on_and_persists_off"] = function()
    ns = {}
    C_CVar = nil
    ForeverQuestPinsDB = nil
    ForeverQuestPinsCharDB = nil
    ForeverQuestPinsDB_Settings = nil
    ForeverQuestPinsCharacterSettings = nil
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    ns.InitSettings()
    assert(ns.GetOption("showSpawnClusters") == true)
    ns.SetOption("showSpawnClusters", false)
    ns.db = nil
    ns.InitSettings()
    assert(ns.GetOption("showSpawnClusters") == false)
end

cases["map_pins_runtime.spawn_cloud_dots_use_map_pixels"] = function()
    setupPinRendering()
    -- Zoomed canvas: the map scales the canvas, so cloud dots must keep using
    -- plain map pixels instead of the pin's counter-scale.
    mapCanvas.scale = 2
    ns.Quests = {
        [101] = {
            mapID = 1, x = 50, y = 50, title = "Spawn test",
            coords = { { 50, 50, 1 }, { 50.4, 50, 1 } },
        },
    }
    ns.ByMap = { [1] = { 101 } }
    options.showSpawnClusters = true

    ns.MapPins:Refresh("spawn-cloud")
    -- The hovered pin sits at the canvas point for (0.5, 0.5) at zoom 2.
    pin.centerX, pin.centerY = 1000, 0
    pin.scripts.OnEnter(pin)
    assert(#cloudFrames == 2, "cloud dots " .. tostring(#cloudFrames))
    assert(cloudFrames[1].strata == "FULLSCREEN_DIALOG", "dot strata " .. tostring(cloudFrames[1].strata))
    local anchor = cloudFrames[1]
    local second = cloudFrames[2]
    assert(anchor.point[2] == UIParent and anchor.point[3] == "BOTTOMLEFT")
    assert(math.abs(anchor.point[4] - 1000) < 0.001, "anchor dot x " .. tostring(anchor.point[4]))
    assert(math.abs(anchor.point[5] - 0) < 0.001, "anchor dot y " .. tostring(anchor.point[5]))
    assert(math.abs(second.point[4] - 1008) < 0.001, "second dot x " .. tostring(second.point[4]))
    assert(math.abs(second.point[5] - 0) < 0.001, "second dot y " .. tostring(second.point[5]))
end

cases["map_pins_runtime.stacked_quests_keep_separate_spawn_counts"] = function()
    setupPinRendering()
    local coords = { { 50, 50, 1 }, { 50.4, 50.1, 1 }, { 50.8, 50.2, 1 } }
    ns.Quests = {
        [101] = { mapID = 1, x = 50, y = 50, title = "First quest", coords = coords },
        [102] = { mapID = 1, x = 50, y = 50, title = "Second quest", coords = coords },
    }
    ns.ByMap = { [1] = { 101, 102 } }
    options.showSpawnClusters = true

    ns.MapPins:Refresh("spawn-stack")
    local status = ns.MapPins:GetStatus()
    assert(status.count == 1, "stacked pins " .. tostring(status.count))
    assert(status.paintedIDs[101] and status.paintedIDs[102])
    assert(pin.spawnCount == 3, "stacked spawn count " .. tostring(pin.spawnCount))
    assert(pin.Badge == nil, "count badge should not be drawn")
end

cases["map_pins_runtime.spawn_cluster_count_is_capped_per_quest"] = function()
    setupPinRendering()
    local coords = {}
    for i = 1, 10 do
        coords[i] = { 5 + (i * 10), 50, 1 }
    end
    ns.Quests = {
        [101] = { mapID = 1, x = 5, y = 50, title = "Spawn test", coords = coords },
    }
    ns.ByMap = { [1] = { 101 } }
    options.showSpawnClusters = true

    ns.MapPins:Refresh("spawn-cap")
    assert(ns.MapPins:GetStatus().count == 6, "capped cluster pins " .. tostring(ns.MapPins:GetStatus().count))
end

cases["map_pins_runtime.distant_spawn_points_cluster_or_collapse_to_one_pin"] = function()
    setupPinRendering()
    ns.Quests = {
        [101] = {
            mapID = 1, x = 20, y = 50, title = "Spawn test",
            coords = { { 20, 50, 1 }, { 50, 50, 1 }, { 80, 50, 1 } },
        },
    }
    ns.ByMap = { [1] = { 101 } }

    options.showSpawnClusters = true
    ns.MapPins:Refresh("spawn-clusters")
    assert(ns.MapPins:GetStatus().count == 3, "distant cluster pins " .. tostring(ns.MapPins:GetStatus().count))
    assert(pin.spawnCount == 1)
    assert(pin.Badge == nil)

    options.showSpawnClusters = false
    ns.MapPins:Refresh("spawn-single")
    assert(ns.MapPins:GetStatus().count == 1, "single pin count " .. tostring(ns.MapPins:GetStatus().count))
    assert(pin.spawnCount == 3, "single pin spawn count " .. tostring(pin.spawnCount))
    assert(pin.Badge == nil)
    assert(pin.nx == 0.5 and pin.ny == 0.5, "anchor " .. tostring(pin.nx) .. "," .. tostring(pin.ny))

    pin.scripts.OnEnter(pin)
    assert(ns.MapPins:GetStatus().cloudCount == 0)
    assert(tooltipHas("3 possible spawn locations"), "single pin tooltip count line")
    pin.scripts.OnClick(pin, "LeftButton")
    assert(trackedQuestID == 101)
    assert(trackedData.mapID == 1 and trackedData.x == 50 and trackedData.y == 50)
end

cases["localization.client_locale_and_fallback"] = function()
    for _, locale in ipairs({ "enUS", "esES", "esMX", "frFR" }) do
        local localNS = {}
        GetLocale = function() return locale end
        assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
        if locale == "esES" or locale == "esMX" then
            assert(localNS.L["Show quest start pins"] == "Mostrar marcadores de inicio de misión")
            assert(localNS.L["Quest %d (title unavailable)"]:format(123) == "Misión 123 (título no disponible)")
            local festival = localNS.L["Lunar Festival elders, Darkmoon Faire, and other event quests."]
            assert(festival:find("Ancestros del Festival Lunar, Feria de la Luna Negra", 1, true))
            assert(localNS.L["Dungeon / raid quest"]:find(locale == "esES" and "mazmorra" or "calabozo", 1, true))
            for english, spanish in pairs(localNS.L) do
                local function formats(value)
                    local found = {}
                    for token in value:gmatch("%%[%+%-%.%d]*[a-zA-Z%%]") do found[#found + 1] = token end
                    return table.concat(found, ",")
                end
                assert(formats(english) == formats(spanish), english)
            end
        else
            assert(localNS.L["Show quest start pins"] == "Show quest start pins")
        end
        assert(localNS.L["Missing translation"] == "Missing translation")
    end
end

cases["quest_info_runtime.localized_tag_uses_static_classification"] = function()
    dofile("tests/fixtures/quest_info.lua")
    GetLocale = function() return "esES" end
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    C_QuestLog.GetQuestTagInfo = function() return { tagName = "Mazmorra" } end
    assert(ns.IsInstanceQuest(101, { isInstanceQuest = true }))
    assert(not ns.IsInstanceQuest(102, {}))
end

cases["localization.spanish_command_output"] = function()
    GetLocale = function() return "esMX" end
    local localNS = {}
    assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
    assert(loadfile("Config.lua"))("ForeverQuestPins", localNS)
    local lines = {}
    print = function(line) lines[#lines + 1] = line end
    localNS.SlashCommand("help")
    assert(table.concat(lines, "\n"):find("Comandos:", 1, true))
    lines = {}
    localNS.Quests = { [1] = { mapID = 1, x = 10, y = 20 } }
    localNS.IsQuestAvailable = function() return true, "ok" end
    localNS.IsQuestFlaggedCompleted = function() return false end
    localNS.IsOnQuest = function() return false end
    localNS.PrintQuestWhy(1)
    assert(table.concat(lines, "\n"):find("Misión 1: se mostraría (ok)", 1, true))
end

local name = assert(os.getenv("FQP_LUA_CASE"), "FQP_LUA_CASE is required")
assert(cases[name], "unknown LuaJIT case: " .. name)()
print("PASS " .. name)
