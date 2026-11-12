package questdb

import (
	"strings"
	"testing"

	"github.com/TylerAkins/forever-quest-markers/internal/questiepolicy"
)

func testEventWindow(startMonth, startDay, startHour, startMinute, endMonth, endDay, endHour, endMinute int) questiepolicy.EventWindow {
	return questiepolicy.EventWindow{
		Start: questiepolicy.MonthDayTime{Month: startMonth, Day: startDay, Hour: startHour, Minute: startMinute},
		End:   questiepolicy.MonthDayTime{Month: endMonth, Day: endDay, Hour: endHour, Minute: endMinute},
	}
}

func testEventPolicy() *questiepolicy.Policy {
	return &questiepolicy.Policy{
		HolidayNames: map[int]string{
			100: "Winter Veil",
			200: "Lunar Festival",
			300: "Darkmoon Faire",
		},
		EventWindows: map[string]questiepolicy.EventWindow{
			"Winter Veil": testEventWindow(12, 15, 10, 0, 1, 2, 10, 0),
		},
		EventOverrides: map[int]questiepolicy.EventWindow{
			100: testEventWindow(12, 25, 0, 0, 1, 2, 23, 59),
			999: testEventWindow(1, 1, 0, 0, 1, 2, 0, 0),
		},
		DisabledEvents: map[string]bool{},
		LunarWindows: map[int]questiepolicy.EventWindow{
			2026: testEventWindow(2, 16, 6, 0, 3, 9, 6, 0),
		},
		LunarYearFirst:    2026,
		LunarYearLast:     2028,
		WarEffortQuestIDs: map[int]bool{8811: true, 8792: true},
	}
}

func TestBuildEventScheduleReconcilesQuestsAndEvents(t *testing.T) {
	records := []Record{
		{QuestID: 100, IsYearly: true},
		{QuestID: 200, IsYearly: true},
		{QuestID: 300, IsYearly: true},
		{QuestID: 400},
	}
	schedule, err := BuildEventSchedule(testEventPolicy(), records)
	if err != nil {
		t.Fatal(err)
	}
	if schedule.ByQuest[100] != "Winter Veil" || schedule.ByQuest[200] != "Lunar Festival" || schedule.ByQuest[300] != "Darkmoon Faire" {
		t.Fatalf("byQuest = %v", schedule.ByQuest)
	}
	if _, exists := schedule.ByQuest[400]; exists {
		t.Fatal("non-yearly quest must not enter byQuest")
	}
	if schedule.Events["Winter Veil"] != testEventWindow(12, 15, 10, 0, 1, 2, 10, 0) {
		t.Fatalf("Winter Veil window = %+v", schedule.Events["Winter Veil"])
	}
	if !schedule.Disabled["Darkmoon Faire"] {
		t.Fatal("Darkmoon Faire should be disabled")
	}
	if schedule.Lunar[2026] != testEventWindow(2, 16, 6, 0, 3, 9, 6, 0) {
		t.Fatalf("lunar window = %+v", schedule.Lunar[2026])
	}
	if schedule.LunarFirst != 2026 || schedule.LunarLast != 2028 {
		t.Fatalf("lunar years = %d..%d", schedule.LunarFirst, schedule.LunarLast)
	}
	if !schedule.WarEffort[8811] || !schedule.WarEffort[8792] {
		t.Fatalf("war effort = %v", schedule.WarEffort)
	}
	if _, exists := schedule.Overrides[999]; exists {
		t.Fatal("override for a quest outside this database must be dropped")
	}
}

func TestRenderEventPolicyIsDeterministic(t *testing.T) {
	schedule, err := BuildEventSchedule(testEventPolicy(), []Record{
		{QuestID: 100, IsYearly: true},
		{QuestID: 200, IsYearly: true},
		{QuestID: 300, IsYearly: true},
	})
	if err != nil {
		t.Fatal(err)
	}
	first := string(renderEventPolicy(schedule, Metadata{PolicyCommit: "abc123"}))
	second := string(renderEventPolicy(schedule, Metadata{PolicyCommit: "abc123"}))
	if first != second {
		t.Fatal("event policy rendering is not deterministic")
	}
	for _, needle := range []string{
		"-- AUTO-GENERATED FILE",
		"-- Policy commit: abc123",
		`local ADDON_NAME, ns = ...`,
		`[100] = "Winter Veil",`,
		`["Winter Veil"] = { { 12, 15, 10, 0 }, { 1, 2, 10, 0 } }, -- 15 Dec 10:00 to 2 Jan 10:00`,
		`[100] = { { 12, 25, 0, 0 }, { 1, 2, 23, 59 } }, -- 25 Dec 00:00 to 2 Jan 23:59`,
		`[2026] = { { 2, 16, 6, 0 }, { 3, 9, 6, 0 } }, -- 16 Feb 06:00 to 9 Mar 06:00`,
		`lunarYears = { first = 2026, last = 2028 },`,
		`["Darkmoon Faire"] = true,`,
		`[8792] = true,`,
		`[8811] = true,`,
	} {
		if !strings.Contains(first, needle) {
			t.Errorf("event policy missing %q:\n%s", needle, first)
		}
	}
}

func TestBuildEventScheduleRejectsIncompletePolicy(t *testing.T) {
	t.Run("yearly quest without event", func(t *testing.T) {
		policy := testEventPolicy()
		delete(policy.HolidayNames, 100)
		if _, err := BuildEventSchedule(policy, []Record{{QuestID: 100, IsYearly: true}}); err == nil {
			t.Fatal("expected a yearly quest without an event name to fail")
		}
	})
	t.Run("event without window or disabled marker", func(t *testing.T) {
		policy := testEventPolicy()
		policy.DisabledEvents = map[string]bool{}
		policy.HolidayNames[300] = "Unknown Event"
		if _, err := BuildEventSchedule(policy, []Record{{QuestID: 300, IsYearly: true}}); err == nil {
			t.Fatal("expected an event without a window to fail")
		}
	})
	t.Run("lunar quests without a year table", func(t *testing.T) {
		policy := testEventPolicy()
		policy.LunarWindows = map[int]questiepolicy.EventWindow{}
		if _, err := BuildEventSchedule(policy, []Record{{QuestID: 200, IsYearly: true}}); err == nil {
			t.Fatal("expected Lunar Festival without a year table to fail")
		}
	})
}
