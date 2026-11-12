package questiepolicy

import (
	"os"
	"path/filepath"
	"testing"
)

func writePolicyFile(t *testing.T, root, relative, content string) {
	t.Helper()
	path := filepath.Join(root, relative)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

const minimalEventPolicy = `
QuestieEvent.eventDates = {
    ["Test Event"] = { startDate = "1/1", startHour = 0, startMinute = 0, endDate = "2/1", endHour = 0, endMinute = 0 },
}
QuestieEvent.eventDateCorrections = { ["CLASSIC"] = {} }
QuestieEvent.lunarFestival = {
    DEFAULT = {
        ["26"] = { startDate = "16/2", startHour = 6, startMinute = 0, endDate = "9/3", endHour = 6, endMinute = 0 },
    },
}
`

const minimalWarEffort = `QuestieQuestBlacklist.AQWarEffortQuests = { [8811] = true }`

func writeMinimalEventPolicy(t *testing.T, root string) {
	t.Helper()
	writePolicyFile(t, root, "Database/Corrections/Holidays/QuestieEvent.lua", minimalEventPolicy)
	writePolicyFile(t, root, "Database/Corrections/QuestieQuestBlacklist.lua", minimalWarEffort)
}

func TestLoadHolidayAndTagPolicy(t *testing.T) {
	root := t.TempDir()
	writePolicyFile(t, root, "Database/Corrections/Holidays/quests/Test.lua", `
tinsert(eventQuests, { "Test Event", 100, "25/12", "2/1" })
tinsert(eventQuests, { "Test Event", 101, nil, nil, nil, nil, true })
`)
	writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `
function _QuestieDB.InitializeQuestTagInfoCorrections()
    _QuestieDB.questTagCorrections = {
        [100] = (Expansions.Current == Expansions.Era and { 81, l10n("Dungeon") }) or nil,
        [101] = (Expansions.Current == Expansions.Cata and { 81, l10n("Dungeon") }) or nil,
        [102] = { 5, l10n("Group") },
    }
end
`)
	writeMinimalEventPolicy(t, root)
	policy, err := Load(root)
	if err != nil {
		t.Fatal(err)
	}
	if policy.HolidayEntries != 2 || len(policy.HolidayQuestIDs) != 1 {
		t.Fatalf("holiday entries=%d included=%d, want 2/1", policy.HolidayEntries, len(policy.HolidayQuestIDs))
	}
	if !policy.HolidayQuestIDs[100] || policy.HolidayQuestIDs[101] {
		t.Fatalf("unexpected holiday IDs: %v", policy.HolidayQuestIDs)
	}
	if policy.HiddenEntries != 1 {
		t.Fatalf("hidden entries = %d, want 1", policy.HiddenEntries)
	}
	override, ok := policy.EventOverrides[100]
	if !ok {
		t.Fatal("quest 100 should have a per-quest date override")
	}
	want := EventWindow{
		Start: MonthDayTime{Month: 12, Day: 25, Hour: 0, Minute: 0},
		End:   MonthDayTime{Month: 1, Day: 2, Hour: 23, Minute: 59},
	}
	if override != want {
		t.Fatalf("override = %+v, want %+v", override, want)
	}
	if _, exists := policy.EventOverrides[101]; exists {
		t.Fatal("hidden quest 101 must not keep an override")
	}
	if policy.TagEntries != 2 {
		t.Fatalf("tag entries = %d, want 2", policy.TagEntries)
	}
	if !policy.InstanceQuestIDs[100] {
		t.Fatal("quest 100 should be an instance quest")
	}
	if policy.InstanceQuestIDs[101] {
		t.Fatal("Cata-only correction must not apply to Forever")
	}
	if !IsInstanceTag(98) || IsInstanceTag(5) {
		t.Fatal("instance tag set is wrong")
	}
}

func TestLoadEventWindowsAndWarEffortUnderEraPolicy(t *testing.T) {
	root := t.TempDir()
	writePolicyFile(t, root, "Database/Corrections/Holidays/quests/Test.lua", `tinsert(eventQuests, { "Winter Veil", 1 })`)
	writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `_QuestieDB.questTagCorrections = {}`)
	writePolicyFile(t, root, "Database/Corrections/Holidays/QuestieEvent.lua", `
QuestieEvent.eventDates = {
    ["Winter Veil"] = not Questie.IsTitanReforged and {
        startDate = "15/12", startHour = 10, startMinute = 0,
        endDate = "2/1", endHour = 10, endMinute = 0,
    } or {
        startDate = "15/12", startHour = 6, startMinute = 0,
        endDate = "2/1", endHour = 6, endMinute = 0,
    },
    ["Brewfest"] = { startDate = "20/9", startHour = 10, startMinute = 0, endDate = "6/10", endHour = 10, endMinute = 0 },
    ["Love is in the Air"] = { startDate = "9/2", startHour = 10, startMinute = 0, endDate = "23/2", endHour = 10, endMinute = 0 },
    ["Hallow's End"] = { startDate = "18/10", startHour = 10, startMinute = 0, endDate = "1/11", endHour = 11, endMinute = 0 },
}
QuestieEvent.eventDateCorrections = {
    ["CLASSIC"] = {
        ["Brewfest"] = false,
        ["Pilgrim's Bounty"] = false,
        ["Pirates' Day"] = false,
        ["Love is in the Air"] = { startDate = "11/2", startHour = 10, startMinute = 0, endDate = "15/2", endHour = 10, endMinute = 0 },
        ["Hallow's End"] = { startDate = "18/10", startHour = 4, startMinute = 0, endDate = "1/11", endHour = 4, endMinute = 0 },
    },
    ["TBC"] = {
        ["Winter Veil"] = { startDate = "15/12", startHour = 6, startMinute = 0, endDate = "2/1", endHour = 6, endMinute = 0 },
    },
}
QuestieEvent.lunarFestival = {
    DEFAULT = {
        ["26"] = { startDate = "16/2", startHour = 6, startMinute = 0, endDate = "9/3", endHour = 6, endMinute = 0 },
        ["27"] = { startDate = "5/2", startHour = 6, startMinute = 0, endDate = "19/2", endHour = 6, endMinute = 0 },
        ["28"] = { startDate = "24/1", startHour = 6, startMinute = 0, endDate = "14/2", endHour = 6, endMinute = 0 },
    },
    TITAN = {
        ["26"] = { startDate = "29/1", startHour = 6, startMinute = 0, endDate = "25/2", endHour = 6, endMinute = 0 },
    },
}
`)
	writePolicyFile(t, root, "Database/Corrections/QuestieQuestBlacklist.lua", `
QuestieQuestBlacklist.AQWarEffortQuests = {
    [8811] = true,
    [8792] = true,
}
`)

	policy, err := Load(root)
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"Brewfest", "Pilgrim's Bounty", "Pirates' Day"} {
		if !policy.DisabledEvents[name] {
			t.Errorf("%s should be disabled on Era", name)
		}
		if _, exists := policy.EventWindows[name]; exists {
			t.Errorf("%s should not keep an enabled window", name)
		}
	}
	winterVeil := policy.EventWindows["Winter Veil"]
	if winterVeil.Start.Hour != 10 {
		t.Errorf("Winter Veil should use the non-Titan window, got %+v", winterVeil)
	}
	love := policy.EventWindows["Love is in the Air"]
	wantLove := EventWindow{
		Start: MonthDayTime{Month: 2, Day: 11, Hour: 10, Minute: 0},
		End:   MonthDayTime{Month: 2, Day: 15, Hour: 10, Minute: 0},
	}
	if love != wantLove {
		t.Errorf("Love is in the Air = %+v, want %+v", love, wantLove)
	}
	hallow := policy.EventWindows["Hallow's End"]
	wantHallow := EventWindow{
		Start: MonthDayTime{Month: 10, Day: 18, Hour: 4, Minute: 0},
		End:   MonthDayTime{Month: 11, Day: 1, Hour: 4, Minute: 0},
	}
	if hallow != wantHallow {
		t.Errorf("Hallow's End = %+v, want %+v", hallow, wantHallow)
	}
	start := policy.LunarWindows[2026].Start
	end := policy.LunarWindows[2026].End
	if start.Month != 2 || start.Day != 16 || start.Hour != 6 || end.Month != 3 || end.Day != 9 || end.Hour != 6 {
		t.Errorf("Lunar Festival 2026 = %+v", policy.LunarWindows[2026])
	}
	if _, exists := policy.LunarWindows[2029]; exists {
		t.Error("Lunar Festival 2029 must not resolve from the pinned year table")
	}
	if policy.LunarYearFirst != 2026 || policy.LunarYearLast != 2028 {
		t.Errorf("lunar years = %d..%d, want 2026..2028", policy.LunarYearFirst, policy.LunarYearLast)
	}
	if policy.EventWindowEntries != 3 {
		t.Errorf("event windows = %d, want 3 enabled events", policy.EventWindowEntries)
	}
	if !policy.WarEffortQuestIDs[8811] || !policy.WarEffortQuestIDs[8792] {
		t.Error("AQ war effort list is missing known quests")
	}
	if policy.WarEffortQuestIDs[8789] {
		t.Error("8789 is not in Questie's AQ war effort list")
	}
	if policy.WarEffortEntries != 2 {
		t.Errorf("war effort entries = %d, want 2", policy.WarEffortEntries)
	}
}

func TestLoadRejectsMalformedEventPolicy(t *testing.T) {
	for name, source := range map[string]string{
		"invalid date": `
QuestieEvent.eventDates = { ["Bad"] = { startDate = "40/13", startHour = 0, startMinute = 0, endDate = "1/1", endHour = 0, endMinute = 0 } }
QuestieEvent.eventDateCorrections = { ["CLASSIC"] = {} }
QuestieEvent.lunarFestival = { DEFAULT = { ["26"] = { startDate = "16/2", startHour = 6, startMinute = 0, endDate = "9/3", endHour = 6, endMinute = 0 } } }
`,
		"missing classic corrections": `
QuestieEvent.eventDates = {}
QuestieEvent.eventDateCorrections = {}
QuestieEvent.lunarFestival = { DEFAULT = { ["26"] = { startDate = "16/2", startHour = 6, startMinute = 0, endDate = "9/3", endHour = 6, endMinute = 0 } } }
`,
		"unknown event correction": `
QuestieEvent.eventDates = {}
QuestieEvent.eventDateCorrections = { ["CLASSIC"] = { ["Brewfest"] = true } }
QuestieEvent.lunarFestival = { DEFAULT = { ["26"] = { startDate = "16/2", startHour = 6, startMinute = 0, endDate = "9/3", endHour = 6, endMinute = 0 } } }
`,
	} {
		t.Run(name, func(t *testing.T) {
			root := t.TempDir()
			writePolicyFile(t, root, "Database/Corrections/Holidays/quests/Test.lua", `tinsert(eventQuests, { "Test", 1 })`)
			writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `_QuestieDB.questTagCorrections = {}`)
			writePolicyFile(t, root, "Database/Corrections/Holidays/QuestieEvent.lua", source)
			writePolicyFile(t, root, "Database/Corrections/QuestieQuestBlacklist.lua", minimalWarEffort)
			if _, err := Load(root); err == nil {
				t.Fatal("expected malformed event policy to fail")
			}
		})
	}
}

func TestLoadRejectsMissingPolicyInputs(t *testing.T) {
	for name, setup := range map[string]func(t *testing.T, root string){
		"event file": func(t *testing.T, root string) {
			writePolicyFile(t, root, "Database/Corrections/Holidays/quests/Test.lua", `tinsert(eventQuests, { "Test", 1 })`)
			writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `_QuestieDB.questTagCorrections = {}`)
			writePolicyFile(t, root, "Database/Corrections/QuestieQuestBlacklist.lua", minimalWarEffort)
		},
		"war effort file": func(t *testing.T, root string) {
			writePolicyFile(t, root, "Database/Corrections/Holidays/quests/Test.lua", `tinsert(eventQuests, { "Test", 1 })`)
			writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `_QuestieDB.questTagCorrections = {}`)
			writePolicyFile(t, root, "Database/Corrections/Holidays/QuestieEvent.lua", minimalEventPolicy)
		},
	} {
		t.Run(name, func(t *testing.T) {
			root := t.TempDir()
			setup(t, root)
			if _, err := Load(root); err == nil {
				t.Fatal("expected a missing policy input to fail")
			}
		})
	}
}

func TestLoadRejectsUnknownHolidaySyntax(t *testing.T) {
	root := t.TempDir()
	writePolicyFile(t, root, "Database/Corrections/Holidays/quests/Test.lua", `
tinsert(eventQuests, { "Test Event", 100, unknownSyntax(1) })
`)
	writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `
_QuestieDB.questTagCorrections = {}
`)
	writeMinimalEventPolicy(t, root)
	if _, err := Load(root); err == nil {
		t.Fatal("expected unknown holiday syntax to fail")
	}
}

func TestLoadRejectsMissingHolidayFiles(t *testing.T) {
	root := t.TempDir()
	writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `_QuestieDB.questTagCorrections = {}`)
	writeMinimalEventPolicy(t, root)
	if _, err := Load(root); err == nil {
		t.Fatal("expected missing holiday files to fail")
	}
}

func TestLoadRejectsMalformedTagEntry(t *testing.T) {
	root := t.TempDir()
	writePolicyFile(t, root, "Database/Corrections/Holidays/quests/Test.lua", `tinsert(eventQuests, { "Test", 1 })`)
	writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `_QuestieDB.questTagCorrections = { [1] = "Dungeon" }`)
	writeMinimalEventPolicy(t, root)
	if _, err := Load(root); err == nil {
		t.Fatal("expected malformed tag entry to fail")
	}
}
