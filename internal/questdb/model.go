package questdb

import (
	"sort"

	"github.com/TylerAkins/forever-quest-markers/internal/questiedb"
)

// Record is one compact quest-start record written to ForeverQuests.lua.
type Record struct {
	QuestID                int
	Coords                 []questiedb.Coord
	QG                     int
	QGs                    []int
	TurnIns                []int
	TurnInObjects          []int
	SourceQuestGroup       []int
	SourceQuestSingle      []int
	SourceQuestNumRequired int
	AltQuests              []int
	Races                  []int
	Classes                []int
	RequireSkill           *questiedb.Skill
	Faction                string
	MinLevel               int
	IsYearly               bool
	Repeatable             bool
	IsMonthly              bool
	IsBreadcrumb           bool
	IsInstanceQuest        bool
	Title                  string
}

// HasCoord reports whether the record can produce a map pin.
func (record Record) HasCoord() bool {
	return len(record.Coords) > 0
}

var raceMasks = []struct {
	id  int
	bit uint64
}{
	{1, 1},
	{2, 2},
	{3, 4},
	{4, 8},
	{5, 16},
	{6, 32},
	{7, 64},
	{8, 128},
	{9, 256},
	{10, 512},
	{11, 1024},
	{22, 2097152},
	{24, 8388608},
	{25, 16777216},
	{26, 33554432},
	{95, 4294967296},
	{96, 8589934592},
}

const (
	allianceRaceMask = uint64(1)<<0 | uint64(1)<<2 | uint64(1)<<3 | uint64(1)<<6 | uint64(1)<<32
	hordeRaceMask    = uint64(1)<<1 | uint64(1)<<4 | uint64(1)<<5 | uint64(1)<<7 | uint64(1)<<33
)

func allKnownRaceMask() uint64 {
	var mask uint64
	for _, race := range raceMasks {
		mask |= race.bit
	}
	return mask
}

// raceMaskToRaces converts a Forever race mask to sorted race IDs.
func raceMaskToRaces(mask uint64) (races []int, unknown uint64) {
	if mask == 0 || mask == allKnownRaceMask() {
		return nil, 0
	}
	known := uint64(0)
	for _, race := range raceMasks {
		if mask&race.bit != 0 {
			races = append(races, race.id)
			known |= race.bit
		}
	}
	sort.Ints(races)
	return races, mask &^ known
}

// raceMaskToFaction derives a faction only for masks made solely of one side's
// Forever playable races. Mixed or unknown masks stay unrestricted.
func raceMaskToFaction(mask uint64) string {
	if mask == 0 || mask == allKnownRaceMask() {
		return ""
	}
	if mask&^allianceRaceMask == 0 {
		return "Alliance"
	}
	if mask&^hordeRaceMask == 0 {
		return "Horde"
	}
	return ""
}

var classMasks = []struct {
	id  int
	bit uint16
}{
	{1, 1},
	{2, 2},
	{3, 4},
	{4, 8},
	{5, 16},
	{6, 32},
	{7, 64},
	{8, 128},
	{9, 256},
	{10, 512},
	{11, 1024},
	{12, 2048},
	{13, 4096},
}

func classMaskToClasses(mask uint16) (classes []int, unknown uint16) {
	if mask == 0 {
		return nil, 0
	}
	known := uint16(0)
	for _, class := range classMasks {
		if mask&class.bit != 0 {
			classes = append(classes, class.id)
			known |= class.bit
		}
	}
	return classes, mask &^ known
}

func uniqueSorted(values []int) []int {
	if len(values) == 0 {
		return nil
	}
	seen := map[int]bool{}
	result := make([]int, 0, len(values))
	for _, value := range values {
		if value == 0 || seen[value] {
			continue
		}
		seen[value] = true
		result = append(result, value)
	}
	sort.Ints(result)
	if len(result) == 0 {
		return nil
	}
	return result
}
