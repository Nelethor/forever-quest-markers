package questdb

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/TylerAkins/forever-quest-markers/internal/questiedb"
	"github.com/TylerAkins/forever-quest-markers/internal/questiepolicy"
)

// Options configures a QuestieDB Forever database build.
type Options struct {
	ArtifactPath string
	ArtifactSHA  string
	ArtifactRef  string
	PolicyPath   string
	PolicyCommit string
	OutputDir    string
	ReportPath   string
	BaselinePath string
}

// BuildResult contains the generated records and report.
type BuildResult struct {
	Report  Report
	Records []Record
	Meta    Metadata
}

// Build reads a pinned QuestieDB artifact and Questie policy checkout, then
// writes the addon database, tag corrections, metadata, and build report.
func Build(options Options) (*BuildResult, error) {
	if options.ArtifactPath == "" {
		return nil, fmt.Errorf("QuestieDB artifact path is required")
	}
	if options.PolicyPath == "" {
		return nil, fmt.Errorf("Questie policy path is required")
	}
	if options.OutputDir == "" {
		return nil, fmt.Errorf("output directory is required")
	}
	if options.ReportPath == "" {
		options.ReportPath = filepath.Join(options.OutputDir, "build_report.json")
	}
	actualSHA := ""
	if options.ArtifactSHA != "" {
		digest, err := questiedb.VerifyArtifactSHA256(options.ArtifactPath, options.ArtifactSHA)
		if err != nil {
			return nil, err
		}
		actualSHA = digest
	} else {
		digest, err := questiedb.ArtifactSHA256(options.ArtifactPath)
		if err != nil {
			return nil, err
		}
		actualSHA = digest
	}
	artifact, err := questiedb.OpenArtifact(options.ArtifactPath)
	if err != nil {
		return nil, err
	}
	defer artifact.Close()
	zones, err := questiedb.LoadZones(artifact)
	if err != nil {
		return nil, err
	}
	policy, err := questiepolicy.Load(options.PolicyPath)
	if err != nil {
		return nil, err
	}
	var baseline map[int]baselineQuest
	if options.BaselinePath != "" {
		baseline, err = parseBaseline(options.BaselinePath)
		if err != nil {
			return nil, err
		}
	}
	questIDs, err := artifact.IDs("Quest")
	if err != nil {
		return nil, err
	}
	builder := &recordBuilder{
		artifact:  artifact,
		zones:     zones,
		policy:    policy,
		gaps:      map[int]string{},
		conflicts: map[string]bool{},
	}
	records := make([]Record, 0, len(questIDs))
	for _, questID := range questIDs {
		quest, err := artifact.Quest(questID)
		if err != nil {
			return nil, err
		}
		if quest == nil {
			builder.conflicts[fmt.Sprintf("quest %d is listed but missing", questID)] = true
			continue
		}
		record, err := builder.build(quest)
		if err != nil {
			return nil, err
		}
		records = append(records, record)
	}
	sort.Slice(records, func(i, j int) bool { return records[i].QuestID < records[j].QuestID })
	schedule, err := BuildEventSchedule(policy, records)
	if err != nil {
		return nil, err
	}
	meta := Metadata{
		Source:          "QuestieDB-Forever",
		Artifact:        options.ArtifactRef,
		ArtifactCommit:  artifact.BuildCommit,
		ArtifactSHA256:  actualSHA,
		PolicySource:    "Questie/Questie",
		PolicyCommit:    options.PolicyCommit,
		Version:         artifact.Version,
		Flavor:          artifact.Flavor,
		ContractVersion: artifact.ContractVersion,
		BuildTime:       artifact.BuildTime,
		QuestCount:      len(records),
	}
	report := builder.report(meta, policy, baseline, records, schedule)
	meta.QuestCount = report.Counts.Quests
	meta.CoordCount = report.Counts.CoordPins
	meta.TurnInCount = report.Counts.QuestsWithTurnIns
	meta.InstanceCount = report.Counts.InstanceQuests
	meta.YearlyCount = report.Counts.YearlyQuests
	instanceTags := map[int]int{}
	for questID, tagID := range policy.QuestTags {
		if questiepolicy.IsInstanceTag(tagID) {
			instanceTags[questID] = tagID
		}
	}
	if err := EmitDatabase(options.OutputDir, records, meta, instanceTags, schedule); err != nil {
		return nil, err
	}
	if err := WriteReport(options.ReportPath, report); err != nil {
		return nil, err
	}
	return &BuildResult{Report: report, Records: records, Meta: meta}, nil
}

type recordBuilder struct {
	artifact  *questiedb.Artifact
	zones     *questiedb.Zones
	policy    *questiepolicy.Policy
	gaps      map[int]string
	conflicts map[string]bool
}

func (builder *recordBuilder) build(quest *questiedb.Quest) (Record, error) {
	record := Record{
		QuestID:    quest.ID,
		Title:      quest.Name,
		MinLevel:   quest.RequiredLevel,
		Races:      nil,
		Classes:    nil,
		IsYearly:   builder.policy.HolidayQuestIDs[quest.ID],
		Repeatable: quest.SpecialFlags&1 != 0,
		IsMonthly:  quest.SpecialFlags&4 != 0,
		// Questie's `breadcrumbs` field lists other quests that lead here; only
		// `breadcrumbForQuestId` means this quest is itself a breadcrumb.
		IsBreadcrumb:    quest.BreadcrumbFor > 0,
		IsInstanceQuest: builder.policy.InstanceQuestIDs[quest.ID],
	}
	npcStarters := uniqueSorted(quest.StartedBy.NPCs)
	switch {
	case len(npcStarters) == 1:
		record.QG = npcStarters[0]
	case len(npcStarters) > 1:
		record.QGs = npcStarters
	}
	record.TurnIns = uniqueSorted(quest.FinishedBy.NPCs)
	record.TurnInObjects = uniqueSorted(quest.FinishedBy.Objects)
	record.SourceQuestGroup = uniqueSorted(quest.PreQuestGroup)
	// Questie's `breadcrumbs` are optional prerequisite routes that lead to
	// this quest, so keep them as the OR list rather than marking this quest
	// itself as a breadcrumb.
	single := append(append([]int{}, quest.PreQuestSingle...), quest.Breadcrumbs...)
	record.SourceQuestSingle = uniqueSorted(single)
	if len(record.SourceQuestSingle) > 0 {
		record.SourceQuestNumRequired = 1
	}
	record.AltQuests = uniqueSorted(quest.ExclusiveTo)
	if quest.RequiredSkill != nil {
		skill := *quest.RequiredSkill
		record.RequireSkill = &skill
	}
	races, unknownRaces := raceMaskToRaces(quest.RequiredRaces)
	record.Races = races
	record.Faction = raceMaskToFaction(quest.RequiredRaces)
	if unknownRaces != 0 {
		builder.conflicts[fmt.Sprintf("quest %d has unknown race mask bits %d", quest.ID, unknownRaces)] = true
	}
	classes, unknownClasses := classMaskToClasses(quest.RequiredClasses)
	record.Classes = classes
	if unknownClasses != 0 {
		builder.conflicts[fmt.Sprintf("quest %d has unknown class mask bits %d", quest.ID, unknownClasses)] = true
	}
	coords, reason, err := builder.resolveStarts(quest)
	if err != nil {
		return Record{}, err
	}
	if len(coords) == 0 {
		builder.gaps[quest.ID] = reason
	}
	record.Coords = coords
	return record, nil
}

func (builder *recordBuilder) resolveStarts(quest *questiedb.Quest) ([]questiedb.Coord, string, error) {
	groups := quest.StartedBy
	hasStarter := len(groups.NPCs) > 0 || len(groups.Objects) > 0 || len(groups.Items) > 0
	sawStarterNoSpawn := false
	sawItemNoDrop := false
	sawItemNoSpawn := false
	sawMissing := false
	sawUnmapped := false
	sawNoDungeon := false
	coords := []questiedb.Coord{}
	seen := map[string]bool{}
	addSpawns := func(spawns []questiedb.Spawn) {
		for _, spawn := range spawns {
			points := []questiedb.Coord{}
			if spawn.X == -1 && spawn.Y == -1 {
				entrances := builder.zones.ResolveDungeonEntrances(spawn.Zone)
				if len(entrances) == 0 {
					sawNoDungeon = true
					continue
				}
				points = entrances
			} else {
				mapID, ok := builder.zones.ResolveArea(spawn.Zone)
				if !ok {
					sawUnmapped = true
					continue
				}
				points = []questiedb.Coord{{MapID: mapID, X: spawn.X, Y: spawn.Y}}
			}
			for _, point := range points {
				point.X = roundCoordinate(point.X)
				point.Y = roundCoordinate(point.Y)
				key := fmt.Sprintf("%d:%.2f:%.2f", point.MapID, point.X, point.Y)
				if !seen[key] {
					seen[key] = true
					coords = append(coords, point)
				}
			}
		}
	}
	for _, npcID := range uniqueSorted(groups.NPCs) {
		npc, err := builder.artifact.NPC(npcID)
		if err != nil {
			return nil, "", err
		}
		if npc == nil {
			sawMissing = true
			continue
		}
		spawns := npc.Spawns
		if len(spawns) == 0 {
			spawns = npc.Waypoints
		}
		if len(spawns) == 0 {
			sawStarterNoSpawn = true
			continue
		}
		addSpawns(spawns)
	}
	for _, objectID := range uniqueSorted(groups.Objects) {
		object, err := builder.artifact.Object(objectID)
		if err != nil {
			return nil, "", err
		}
		if object == nil {
			sawMissing = true
			continue
		}
		spawns := object.Spawns
		if len(spawns) == 0 {
			spawns = object.Waypoints
		}
		if len(spawns) == 0 {
			sawStarterNoSpawn = true
			continue
		}
		addSpawns(spawns)
	}
	for _, itemID := range uniqueSorted(groups.Items) {
		item, err := builder.artifact.Item(itemID)
		if err != nil {
			return nil, "", err
		}
		if item == nil {
			sawMissing = true
			continue
		}
		spawns, reason := builder.resolveItem(item)
		switch reason {
		case "no-drop":
			sawItemNoDrop = true
		case "no-spawn":
			sawItemNoSpawn = true
		}
		if len(spawns) > 0 {
			addSpawns(spawns)
		}
	}
	sort.Slice(coords, func(i, j int) bool {
		left, right := coords[i], coords[j]
		if left.MapID != right.MapID {
			return left.MapID < right.MapID
		}
		if left.X != right.X {
			return left.X < right.X
		}
		return left.Y < right.Y
	})
	if len(coords) > 0 {
		return coords, "", nil
	}
	switch {
	case !hasStarter:
		return nil, "no_starter", nil
	case sawItemNoDrop:
		return nil, "item_no_drop_source", nil
	case sawItemNoSpawn:
		return nil, "item_drop_no_spawn", nil
	case sawStarterNoSpawn:
		return nil, "starter_no_spawn", nil
	case sawMissing:
		return nil, "missing_entity", nil
	case sawNoDungeon:
		return nil, "no_dungeon_entrance", nil
	case sawUnmapped:
		return nil, "unmapped_zone", nil
	default:
		return nil, "no_starter", nil
	}
}

func (builder *recordBuilder) resolveItem(item *questiedb.Item) ([]questiedb.Spawn, string) {
	if len(item.NPCDrops) == 0 && len(item.ObjectDrops) == 0 {
		return nil, "no-drop"
	}
	for _, npcID := range uniqueSorted(item.NPCDrops) {
		npc, err := builder.artifact.NPC(npcID)
		if err != nil || npc == nil {
			continue
		}
		spawns := npc.Spawns
		if len(spawns) == 0 {
			spawns = npc.Waypoints
		}
		if len(spawns) > 0 {
			return spawns, ""
		}
	}
	for _, objectID := range uniqueSorted(item.ObjectDrops) {
		object, err := builder.artifact.Object(objectID)
		if err != nil || object == nil {
			continue
		}
		spawns := object.Spawns
		if len(spawns) == 0 {
			spawns = object.Waypoints
		}
		if len(spawns) > 0 {
			return spawns, ""
		}
	}
	return nil, "no-spawn"
}

func roundCoordinate(value float64) float64 {
	return float64(int64(value*100+0.5)) / 100
}

func (builder *recordBuilder) report(meta Metadata, policy *questiepolicy.Policy, baseline map[int]baselineQuest, records []Record, schedule *EventSchedule) Report {
	report := Report{
		Artifact: ArtifactReport{
			Version:         meta.Version,
			Commit:          meta.ArtifactCommit,
			SHA256:          meta.ArtifactSHA256,
			Ref:             meta.Artifact,
			Flavor:          meta.Flavor,
			ContractVersion: meta.ContractVersion,
			BuildTime:       meta.BuildTime,
		},
		Policy: PolicyReport{
			Source:          meta.PolicySource,
			Commit:          meta.PolicyCommit,
			HolidayEntries:  policy.HolidayEntries,
			HolidayQuests:   len(policy.HolidayQuestIDs),
			HiddenEntries:   policy.HiddenEntries,
			EventWindows:    len(schedule.Events),
			EventOverrides:  len(schedule.Overrides),
			DisabledEvents:  len(schedule.Disabled),
			WarEffortQuests: len(schedule.WarEffort),
			LunarYears:      len(schedule.Lunar),
			TagEntries:      policy.TagEntries,
			InstanceQuests:  len(policy.InstanceQuestIDs),
		},
		Examples: map[string][]int{},
	}
	report.Coverage.YearlyBaseline = 0
	report.Coverage.InstanceBaseline = 0
	report.Coverage.YearlyMarked = 0
	report.Coverage.InstanceStatic = 0
	turnInNPCs := map[int]bool{}
	turnInObjects := map[int]bool{}
	gapExamples := map[string][]int{}
	npcQuestCount := 0
	objectOnlyQuestCount := 0
	for _, record := range records {
		report.Counts.Quests++
		if record.HasCoord() {
			report.Counts.QuestsWithCoords++
			report.Counts.CoordPins += len(record.Coords)
		}
		if record.IsYearly {
			report.Coverage.YearlyMarked++
		}
		if record.IsInstanceQuest {
			report.Coverage.InstanceStatic++
		}
		if len(record.TurnIns) > 0 || len(record.TurnInObjects) > 0 {
			report.Counts.QuestsWithTurnIns++
			if len(record.TurnIns) > 0 {
				npcQuestCount++
				for _, id := range record.TurnIns {
					turnInNPCs[id] = true
				}
			}
			if len(record.TurnInObjects) > 0 {
				if len(record.TurnIns) == 0 {
					objectOnlyQuestCount++
				}
				for _, id := range record.TurnInObjects {
					turnInObjects[id] = true
				}
			}
		}
		if record.IsInstanceQuest {
			report.Counts.InstanceQuests++
		}
		if record.IsYearly {
			report.Counts.YearlyQuests++
		}
		if record.Repeatable {
			report.Counts.RepeatableQuests++
		}
		if record.IsMonthly {
			report.Counts.MonthlyQuests++
		}
		if record.IsBreadcrumb {
			report.Counts.BreadcrumbQuests++
		}
		if len(record.Races) > 0 {
			report.Counts.QuestsWithRaces++
		}
		if len(record.Classes) > 0 {
			report.Counts.QuestsWithClasses++
		}
		if record.RequireSkill != nil {
			report.Counts.QuestsWithSkill++
		}
		if len(record.SourceQuestGroup) > 0 || len(record.SourceQuestSingle) > 0 {
			report.Counts.QuestsWithPrereqs++
		}
		if len(record.AltQuests) > 0 {
			report.Counts.QuestsWithAltQuests++
		}
		if reason, ok := builder.gaps[record.QuestID]; ok {
			addGap(&report.StartGaps, reason)
			if len(gapExamples[reason]) < 20 {
				gapExamples[reason] = append(gapExamples[reason], record.QuestID)
			}
		}
	}
	report.Counts.TurnInNPCs = len(turnInNPCs)
	report.Counts.TurnInObjects = len(turnInObjects)
	report.TurnIns = TurnInCounts{
		QuestsWithTurnIns: report.Counts.QuestsWithTurnIns,
		NPCs:              len(turnInNPCs),
		Objects:           len(turnInObjects),
		NPCQuests:         npcQuestCount,
		ObjectOnlyQuests:  objectOnlyQuestCount,
	}
	for reason, ids := range gapExamples {
		sort.Ints(ids)
		report.Examples[reason] = ids
	}
	if len(report.Examples) == 0 {
		report.Examples = nil
	}
	if len(baseline) > 0 {
		report.Baseline = compareBaseline(baseline, records, builder.gaps, &report)
	}
	conflicts := make([]string, 0, len(builder.conflicts)+len(policy.Conflicts))
	for conflict := range builder.conflicts {
		conflicts = append(conflicts, conflict)
	}
	conflicts = append(conflicts, policy.Conflicts...)
	sort.Strings(conflicts)
	report.Conflicts = conflicts
	report.Deviations = []string{
		"Era blacklist/quest-exclusion policy is not applied; applying it would hide 235 current baseline quests (191 true, 44 HIDE_ON_MAP; 231 otherwise pinnable). Season, class, and prerequisite availability are decided at runtime.",
		"Questie holiday quest files name their event instead of using event IDs; isYearly marks the record and EventPolicy.lua carries the event name.",
		"Questie `breadcrumbs` lists incoming breadcrumb routes, so it feeds sourceQuestSingle; only `breadcrumbForQuestId` sets isBreadcrumb.",
		"Darkmoon Faire is disabled because Questie has no Forever faire window and most of its records mix Mulgore and Elwynn coordinates.",
	}
	if schedule.LunarFirst != 0 {
		report.Deviations = append(report.Deviations, fmt.Sprintf(
			"Lunar Festival windows are pinned to Questie years %d through %d; later years hide with lunar-year-unknown.",
			schedule.LunarFirst, schedule.LunarLast))
	}
	return report
}

func addGap(counts *GapCounts, reason string) {
	switch reason {
	case "no_starter":
		counts.NoStarter++
	case "item_no_drop_source":
		counts.ItemNoDropSource++
	case "item_drop_no_spawn":
		counts.ItemDropNoSpawn++
	case "starter_no_spawn":
		counts.StarterNoSpawn++
	case "unmapped_zone":
		counts.UnmappedZone++
	case "no_dungeon_entrance":
		counts.NoDungeonEntrance++
	case "missing_entity":
		counts.MissingEntity++
	case "no_questie_quest":
		counts.NoQuestieQuest++
	}
}

func compareBaseline(baseline map[int]baselineQuest, records []Record, gaps map[int]string, report *Report) *BaselineReport {
	newRecords := make(map[int]Record, len(records))
	for _, record := range records {
		newRecords[record.QuestID] = record
	}
	baselineIDs := make([]int, 0, len(baseline))
	for id := range baseline {
		baselineIDs = append(baselineIDs, id)
	}
	sort.Ints(baselineIDs)
	result := &BaselineReport{Quests: len(baseline)}
	yearlyBaseline := []int{}
	instanceBaseline := []int{}
	for _, id := range baselineIDs {
		old := baseline[id]
		if old.HasCoord {
			result.BaselineWithCoords++
		}
		if old.Flags["isYearly"] {
			yearlyBaseline = append(yearlyBaseline, id)
		}
		if old.Flags["isInstanceQuest"] {
			instanceBaseline = append(instanceBaseline, id)
		}
		next, exists := newRecords[id]
		if !exists {
			result.MissingFromQuestie = append(result.MissingFromQuestie, id)
			if old.HasCoord {
				result.LostStartGaps.NoQuestieQuest++
			}
			if old.Flags["isYearly"] {
				report.Coverage.YearlyUnmarked = append(report.Coverage.YearlyUnmarked, id)
			}
			if old.Flags["isInstanceQuest"] {
				report.Coverage.InstanceUnmarked = append(report.Coverage.InstanceUnmarked, id)
			}
			continue
		}
		if next.HasCoord() {
			result.NewWithCoords++
		}
		if old.HasCoord && next.HasCoord() {
			result.StartsPreserved++
		} else if old.HasCoord && !next.HasCoord() {
			result.StartsLost = append(result.StartsLost, id)
			if reason, ok := gaps[id]; ok {
				addGap(&result.LostStartGaps, reason)
			}
		} else if !old.HasCoord && next.HasCoord() {
			result.StartsGained = append(result.StartsGained, id)
		}
		if old.Flags["isYearly"] {
			if !next.IsYearly {
				report.Coverage.YearlyUnmarked = append(report.Coverage.YearlyUnmarked, id)
			}
		}
		if old.Flags["isInstanceQuest"] {
			if !next.IsInstanceQuest {
				report.Coverage.InstanceUnmarked = append(report.Coverage.InstanceUnmarked, id)
			}
		}
	}
	report.Coverage.YearlyBaseline = len(yearlyBaseline)
	report.Coverage.InstanceBaseline = len(instanceBaseline)
	for _, flag := range []string{"isInstanceQuest", "isYearly", "repeatable", "isBreadcrumb", "isMonthly"} {
		comparison := FlagComparison{Name: flag}
		for _, id := range baselineIDs {
			old, exists := baseline[id]
			next, nextExists := newRecords[id]
			if !exists || !nextExists {
				continue
			}
			var after bool
			switch flag {
			case "isInstanceQuest":
				after = next.IsInstanceQuest
			case "isYearly":
				after = next.IsYearly
			case "repeatable":
				after = next.Repeatable
			case "isBreadcrumb":
				after = next.IsBreadcrumb
			case "isMonthly":
				after = next.IsMonthly
			}
			if old.Flags[flag] {
				comparison.Before++
				if !after {
					comparison.Lost = append(comparison.Lost, id)
				}
			}
			if after {
				comparison.After++
				if !old.Flags[flag] {
					comparison.Gained = append(comparison.Gained, id)
				}
			}
		}
		sort.Ints(comparison.Lost)
		sort.Ints(comparison.Gained)
		result.Flags = append(result.Flags, comparison)
	}
	sort.Ints(result.StartsLost)
	sort.Ints(result.StartsGained)
	sort.Ints(result.MissingFromQuestie)
	sort.Ints(report.Coverage.YearlyUnmarked)
	sort.Ints(report.Coverage.InstanceUnmarked)
	return result
}

// ParsePolicyCommit reads a git HEAD from a policy checkout when available.
func ParsePolicyCommit(policyPath, explicit string) string {
	if explicit != "" {
		return explicit
	}
	head, err := os.ReadFile(filepath.Join(policyPath, ".git", "HEAD"))
	if err == nil {
		value := strings.TrimSpace(string(head))
		if strings.HasPrefix(value, "ref: ") {
			ref := strings.TrimPrefix(value, "ref: ")
			if data, err := os.ReadFile(filepath.Join(policyPath, ".git", filepath.FromSlash(ref))); err == nil {
				return strings.TrimSpace(string(data))
			}
		} else if len(value) == 40 {
			return value
		}
	}
	return ""
}
