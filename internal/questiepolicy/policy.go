package questiepolicy

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/TylerAkins/forever-quest-markers/internal/questiedb"
)

// InstanceTagIDs are the Questie quest tags that mark instanced content.
var InstanceTagIDs = map[int]bool{
	81: true, // Dungeon
	62: true, // Raid
	85: true, // Heroic
	88: true, // Raid (10)
	89: true, // Raid (25)
	98: true, // Scenario
}

// IsInstanceTag reports whether a Questie quest tag describes instanced content.
func IsInstanceTag(tagID int) bool {
	return InstanceTagIDs[tagID]
}

// MonthDayTime is a year-less calendar point from Questie event data.
type MonthDayTime struct {
	Month  int
	Day    int
	Hour   int
	Minute int
}

// EventWindow is an inclusive year-less event range. Windows that cross New
// Year have a start stamp later than their end stamp.
type EventWindow struct {
	Start MonthDayTime
	End   MonthDayTime
}

// Policy is the Questie event and quest-tag policy evaluated for Forever.
type Policy struct {
	HolidayQuestIDs    map[int]bool
	HolidayNames       map[int]string
	EventWindows       map[string]EventWindow
	EventOverrides     map[int]EventWindow
	DisabledEvents     map[string]bool
	LunarWindows       map[int]EventWindow
	LunarYearFirst     int
	LunarYearLast      int
	WarEffortQuestIDs  map[int]bool
	QuestTags          map[int]int
	QuestTagNames      map[int]string
	InstanceQuestIDs   map[int]bool
	HolidayEntries     int
	HiddenEntries      int
	EventWindowEntries int
	WarEffortEntries   int
	TagEntries         int
	Conflicts          []string
}

var foreverVars = map[string]any{
	"Expansions.Current":      1,
	"Expansions.Era":          1,
	"Expansions.Tbc":          2,
	"Expansions.Wotlk":        3,
	"Expansions.Cata":         4,
	"Expansions.MoP":          5,
	"Questie.IsSoD":           false,
	"Questie.IsEURegion":      false,
	"Questie.IsTitanReforged": false,
}

// Load parses Questie's holiday quest files, event dates, AQ war effort list,
// and quest-tag corrections under Forever (Era) semantics.
func Load(root string) (*Policy, error) {
	policy := &Policy{
		HolidayQuestIDs:   map[int]bool{},
		HolidayNames:      map[int]string{},
		EventWindows:      map[string]EventWindow{},
		EventOverrides:    map[int]EventWindow{},
		DisabledEvents:    map[string]bool{},
		LunarWindows:      map[int]EventWindow{},
		WarEffortQuestIDs: map[int]bool{},
		QuestTags:         map[int]int{},
		QuestTagNames:     map[int]string{},
		InstanceQuestIDs:  map[int]bool{},
	}
	if err := policy.loadHolidays(root); err != nil {
		return nil, err
	}
	if err := policy.loadEvents(root); err != nil {
		return nil, err
	}
	if err := policy.loadWarEffort(root); err != nil {
		return nil, err
	}
	if err := policy.loadTags(root); err != nil {
		return nil, err
	}
	return policy, nil
}

func (policy *Policy) loadHolidays(root string) error {
	pattern := filepath.Join(root, "Database", "Corrections", "Holidays", "quests", "*.lua")
	files, err := filepath.Glob(pattern)
	if err != nil {
		return err
	}
	if len(files) == 0 {
		return fmt.Errorf("no Questie holiday quest files under %s", pattern)
	}
	sort.Strings(files)
	seen := map[int]string{}
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return err
		}
		source := questiedb.StripLuaComments(string(data))
		position := 0
		for {
			index := strings.Index(source[position:], "tinsert(eventQuests,")
			if index < 0 {
				break
			}
			start := position + index + len("tinsert(eventQuests,")
			for start < len(source) && (source[start] == ' ' || source[start] == '\t' || source[start] == '\r' || source[start] == '\n') {
				start++
			}
			if start >= len(source) || source[start] != '{' {
				return fmt.Errorf("%s: tinsert(eventQuests) is missing a table", file)
			}
			expression, err := questiedb.ExtractLuaValue(source, start)
			if err != nil {
				return fmt.Errorf("%s: %w", file, err)
			}
			value, err := questiedb.ParseLuaExpression(expression, foreverVars)
			if err != nil {
				return fmt.Errorf("%s: parse event quest: %w", file, err)
			}
			table, ok := value.(*questiedb.LuaTable)
			if !ok {
				return fmt.Errorf("%s: event quest entry is %T, not a table", file, value)
			}
			eventName, ok := table.Get(1).(string)
			if !ok || eventName == "" {
				return fmt.Errorf("%s: event quest entry has no event name", file)
			}
			questID, ok := questiedb.Int(table.Get(2))
			if !ok || questID <= 0 {
				return fmt.Errorf("%s: event quest entry %q has no quest ID", file, eventName)
			}
			override, hasOverride, err := eventOverride(table)
			if err != nil {
				return fmt.Errorf("%s: event quest %d: %w", file, questID, err)
			}
			policy.HolidayEntries++
			hidden, err := policy.hideCondition(table.Get(7))
			if err != nil {
				return fmt.Errorf("%s: event quest %d: %w", file, questID, err)
			}
			if hidden {
				policy.HiddenEntries++
			} else {
				if previous, exists := seen[questID]; exists {
					policy.Conflicts = append(policy.Conflicts, fmt.Sprintf("holiday quest %d appears in %s and %s", questID, previous, eventName))
				}
				seen[questID] = eventName
				policy.HolidayQuestIDs[questID] = true
				policy.HolidayNames[questID] = eventName
				if hasOverride {
					policy.EventOverrides[questID] = override
				}
			}
			position = start + len(expression)
		}
	}
	return nil
}

func (policy *Policy) hideCondition(value any) (bool, error) {
	switch typed := value.(type) {
	case nil:
		return false, nil
	case bool:
		return typed, nil
	default:
		return false, fmt.Errorf("unsupported hide condition %T", value)
	}
}

// eventOverride reads Questie's optional per-quest date and time fields. Questie
// uses DD/MM dates and HH:MM times, and ignores times when only one is present.
func eventOverride(table *questiedb.LuaTable) (EventWindow, bool, error) {
	startDate, hasStartDate, err := optionalString(table.Get(3), "start date")
	if err != nil {
		return EventWindow{}, false, err
	}
	endDate, hasEndDate, err := optionalString(table.Get(4), "end date")
	if err != nil {
		return EventWindow{}, false, err
	}
	if !hasStartDate && !hasEndDate {
		return EventWindow{}, false, nil
	}
	if !hasStartDate || !hasEndDate {
		return EventWindow{}, false, fmt.Errorf("start and end dates must appear together")
	}
	startMonth, startDay, err := parseEventDate(startDate)
	if err != nil {
		return EventWindow{}, false, err
	}
	endMonth, endDay, err := parseEventDate(endDate)
	if err != nil {
		return EventWindow{}, false, err
	}
	window := EventWindow{
		Start: MonthDayTime{Month: startMonth, Day: startDay, Hour: 0, Minute: 0},
		End:   MonthDayTime{Month: endMonth, Day: endDay, Hour: 23, Minute: 59},
	}
	startTime, hasStartTime, err := optionalString(table.Get(5), "start time")
	if err != nil {
		return EventWindow{}, false, err
	}
	endTime, hasEndTime, err := optionalString(table.Get(6), "end time")
	if err != nil {
		return EventWindow{}, false, err
	}
	if hasStartTime && hasEndTime {
		window.Start.Hour, window.Start.Minute, err = parseEventTime(startTime)
		if err != nil {
			return EventWindow{}, false, err
		}
		window.End.Hour, window.End.Minute, err = parseEventTime(endTime)
		if err != nil {
			return EventWindow{}, false, err
		}
	}
	return window, true, nil
}

func optionalString(value any, field string) (string, bool, error) {
	if value == nil {
		return "", false, nil
	}
	text, ok := value.(string)
	if !ok {
		return "", false, fmt.Errorf("%s is %T, not a string", field, value)
	}
	return text, true, nil
}

func parseEventDate(value string) (month, day int, err error) {
	dayText, monthText, ok := strings.Cut(value, "/")
	if !ok {
		return 0, 0, fmt.Errorf("event date %q is not day/month", value)
	}
	day, err = strconv.Atoi(strings.TrimSpace(dayText))
	if err != nil {
		return 0, 0, fmt.Errorf("event date %q has an invalid day", value)
	}
	month, err = strconv.Atoi(strings.TrimSpace(monthText))
	if err != nil {
		return 0, 0, fmt.Errorf("event date %q has an invalid month", value)
	}
	if month < 1 || month > 12 || day < 1 || day > 31 {
		return 0, 0, fmt.Errorf("event date %q is out of range", value)
	}
	return month, day, nil
}

func parseEventTime(value string) (hour, minute int, err error) {
	hourText, minuteText, ok := strings.Cut(value, ":")
	if !ok {
		return 0, 0, fmt.Errorf("event time %q is not hour:minute", value)
	}
	hour, err = strconv.Atoi(strings.TrimSpace(hourText))
	if err != nil {
		return 0, 0, fmt.Errorf("event time %q has an invalid hour", value)
	}
	minute, err = strconv.Atoi(strings.TrimSpace(minuteText))
	if err != nil {
		return 0, 0, fmt.Errorf("event time %q has an invalid minute", value)
	}
	if hour < 0 || hour > 23 || minute < 0 || minute > 59 {
		return 0, 0, fmt.Errorf("event time %q is out of range", value)
	}
	return hour, minute, nil
}

func parseEventWindow(table *questiedb.LuaTable) (EventWindow, error) {
	startDate, ok := table.GetString("startDate").(string)
	if !ok {
		return EventWindow{}, fmt.Errorf("missing startDate")
	}
	endDate, ok := table.GetString("endDate").(string)
	if !ok {
		return EventWindow{}, fmt.Errorf("missing endDate")
	}
	startHour, ok := questiedb.Int(table.GetString("startHour"))
	if !ok {
		return EventWindow{}, fmt.Errorf("missing startHour")
	}
	startMinute, ok := questiedb.Int(table.GetString("startMinute"))
	if !ok {
		return EventWindow{}, fmt.Errorf("missing startMinute")
	}
	endHour, ok := questiedb.Int(table.GetString("endHour"))
	if !ok {
		return EventWindow{}, fmt.Errorf("missing endHour")
	}
	endMinute, ok := questiedb.Int(table.GetString("endMinute"))
	if !ok {
		return EventWindow{}, fmt.Errorf("missing endMinute")
	}
	startMonth, startDay, err := parseEventDate(startDate)
	if err != nil {
		return EventWindow{}, err
	}
	endMonth, endDay, err := parseEventDate(endDate)
	if err != nil {
		return EventWindow{}, err
	}
	if startHour < 0 || startHour > 23 || endHour < 0 || endHour > 23 ||
		startMinute < 0 || startMinute > 59 || endMinute < 0 || endMinute > 59 {
		return EventWindow{}, fmt.Errorf("event window time is out of range")
	}
	return EventWindow{
		Start: MonthDayTime{Month: startMonth, Day: startDay, Hour: startHour, Minute: startMinute},
		End:   MonthDayTime{Month: endMonth, Day: endDay, Hour: endHour, Minute: endMinute},
	}, nil
}

func parsePolicyTable(source string, pattern *regexp.Regexp, label string) (*questiedb.LuaTable, error) {
	match := pattern.FindStringIndex(source)
	if match == nil {
		return nil, fmt.Errorf("%s table not found", label)
	}
	expression, err := questiedb.ExtractLuaValue(source, match[1]-1)
	if err != nil {
		return nil, err
	}
	value, err := questiedb.ParseLuaExpression(expression, foreverVars)
	if err != nil {
		return nil, fmt.Errorf("parse %s: %w", label, err)
	}
	table, ok := value.(*questiedb.LuaTable)
	if !ok {
		return nil, fmt.Errorf("%s is %T, not a table", label, value)
	}
	return table, nil
}

var (
	eventDatesPattern       = regexp.MustCompile(`\bQuestieEvent\.eventDates\s*=\s*\{`)
	eventCorrectionsPattern = regexp.MustCompile(`\bQuestieEvent\.eventDateCorrections\s*=\s*\{`)
	lunarFestivalPattern    = regexp.MustCompile(`\bQuestieEvent\.lunarFestival\s*=\s*\{`)
	warEffortPattern        = regexp.MustCompile(`\bQuestieQuestBlacklist\.AQWarEffortQuests\s*=\s*\{`)
)

func (policy *Policy) loadEvents(root string) error {
	file := filepath.Join(root, "Database", "Corrections", "Holidays", "QuestieEvent.lua")
	data, err := os.ReadFile(file)
	if err != nil {
		return err
	}
	source := questiedb.StripLuaComments(string(data))

	dates, err := parsePolicyTable(source, eventDatesPattern, "eventDates")
	if err != nil {
		return fmt.Errorf("%s: %w", file, err)
	}
	for _, name := range dates.StringKeys() {
		entry, ok := dates.GetString(name).(*questiedb.LuaTable)
		if !ok {
			return fmt.Errorf("%s: event %q dates are %T, not a table", file, name, dates.GetString(name))
		}
		window, err := parseEventWindow(entry)
		if err != nil {
			return fmt.Errorf("%s: event %q: %w", file, name, err)
		}
		policy.EventWindows[name] = window
	}

	corrections, err := parsePolicyTable(source, eventCorrectionsPattern, "eventDateCorrections")
	if err != nil {
		return fmt.Errorf("%s: %w", file, err)
	}
	classic, ok := corrections.GetString("CLASSIC").(*questiedb.LuaTable)
	if !ok {
		return fmt.Errorf("%s: CLASSIC event corrections are missing", file)
	}
	for _, name := range classic.StringKeys() {
		switch typed := classic.GetString(name).(type) {
		case bool:
			if typed {
				return fmt.Errorf("%s: event correction for %q must be false or a window", file, name)
			}
			policy.DisabledEvents[name] = true
			delete(policy.EventWindows, name)
		case *questiedb.LuaTable:
			window, err := parseEventWindow(typed)
			if err != nil {
				return fmt.Errorf("%s: event correction for %q: %w", file, name, err)
			}
			policy.EventWindows[name] = window
			delete(policy.DisabledEvents, name)
		default:
			return fmt.Errorf("%s: event correction for %q is %T, not false or a table", file, name, typed)
		}
	}
	policy.EventWindowEntries = len(policy.EventWindows)

	festival, err := parsePolicyTable(source, lunarFestivalPattern, "lunarFestival")
	if err != nil {
		return fmt.Errorf("%s: %w", file, err)
	}
	defaults, ok := festival.GetString("DEFAULT").(*questiedb.LuaTable)
	if !ok {
		return fmt.Errorf("%s: DEFAULT lunar festival dates are missing", file)
	}
	for _, key := range defaults.StringKeys() {
		year, err := strconv.Atoi(key)
		if err != nil || year < 0 || year > 99 {
			return fmt.Errorf("%s: lunar festival year %q is not a two-digit year", file, key)
		}
		entry, ok := defaults.GetString(key).(*questiedb.LuaTable)
		if !ok {
			return fmt.Errorf("%s: lunar festival year %q is %T, not a table", file, key, defaults.GetString(key))
		}
		window, err := parseEventWindow(entry)
		if err != nil {
			return fmt.Errorf("%s: lunar festival year %q: %w", file, key, err)
		}
		policy.LunarWindows[2000+year] = window
	}
	if len(policy.LunarWindows) == 0 {
		return fmt.Errorf("%s: DEFAULT lunar festival dates are empty", file)
	}
	for year := range policy.LunarWindows {
		if policy.LunarYearFirst == 0 || year < policy.LunarYearFirst {
			policy.LunarYearFirst = year
		}
		if year > policy.LunarYearLast {
			policy.LunarYearLast = year
		}
	}
	return nil
}

func (policy *Policy) loadWarEffort(root string) error {
	file := filepath.Join(root, "Database", "Corrections", "QuestieQuestBlacklist.lua")
	data, err := os.ReadFile(file)
	if err != nil {
		return err
	}
	source := questiedb.StripLuaComments(string(data))
	table, err := parsePolicyTable(source, warEffortPattern, "AQWarEffortQuests")
	if err != nil {
		return fmt.Errorf("%s: %w", file, err)
	}
	for _, questID := range table.IntKeys() {
		if table.Get(questID) == true {
			policy.WarEffortQuestIDs[questID] = true
		}
	}
	if len(policy.WarEffortQuestIDs) == 0 {
		return fmt.Errorf("%s: AQWarEffortQuests is empty", file)
	}
	policy.WarEffortEntries = len(policy.WarEffortQuestIDs)
	return nil
}

var tagTablePattern = regexp.MustCompile(`\b_QuestieDB\.questTagCorrections\s*=\s*\{`)

func (policy *Policy) loadTags(root string) error {
	file := filepath.Join(root, "Database", "Corrections", "questTagInfoCorrections.lua")
	data, err := os.ReadFile(file)
	if err != nil {
		return err
	}
	source := questiedb.StripLuaComments(string(data))
	match := tagTablePattern.FindStringIndex(source)
	if match == nil {
		return fmt.Errorf("%s: questTagCorrections table not found", file)
	}
	expression, err := questiedb.ExtractLuaValue(source, match[1]-1)
	if err != nil {
		return fmt.Errorf("%s: %w", file, err)
	}
	value, err := questiedb.ParseLuaExpression(expression, foreverVars)
	if err != nil {
		return fmt.Errorf("%s: parse questTagCorrections: %w", file, err)
	}
	table, ok := value.(*questiedb.LuaTable)
	if !ok {
		return fmt.Errorf("%s: questTagCorrections is %T, not a table", file, value)
	}
	for _, questID := range table.IntKeys() {
		entry := table.Numbers[questID]
		if entry == nil {
			continue
		}
		tagTable, ok := entry.(*questiedb.LuaTable)
		if !ok {
			return fmt.Errorf("%s: tag correction for quest %d is %T, not a table", file, questID, entry)
		}
		tagID, ok := questiedb.Int(tagTable.Get(1))
		if !ok {
			return fmt.Errorf("%s: tag correction for quest %d has no tag ID", file, questID)
		}
		name, _ := tagTable.Get(2).(string)
		policy.TagEntries++
		policy.QuestTags[questID] = tagID
		policy.QuestTagNames[questID] = name
		if IsInstanceTag(tagID) {
			policy.InstanceQuestIDs[questID] = true
		}
	}
	return nil
}
