package questdb

// Report is the deterministic build report written to Database/build_report.json.
type Report struct {
	Artifact   ArtifactReport   `json:"artifact"`
	Policy     PolicyReport     `json:"policy"`
	Counts     Counts           `json:"counts"`
	StartGaps  GapCounts        `json:"start_gaps"`
	Examples   map[string][]int `json:"start_gap_examples,omitempty"`
	TurnIns    TurnInCounts     `json:"turn_ins"`
	Coverage   PolicyCoverage   `json:"policy_coverage"`
	Baseline   *BaselineReport  `json:"baseline,omitempty"`
	Conflicts  []string         `json:"conflicts"`
	Deviations []string         `json:"deviations,omitempty"`
}

type ArtifactReport struct {
	Version         string `json:"version"`
	Commit          string `json:"commit"`
	SHA256          string `json:"sha256,omitempty"`
	Ref             string `json:"ref,omitempty"`
	Flavor          string `json:"flavor"`
	ContractVersion int    `json:"contract_version"`
	BuildTime       string `json:"build_time,omitempty"`
}

type PolicyReport struct {
	Source          string `json:"source"`
	Commit          string `json:"commit,omitempty"`
	HolidayEntries  int    `json:"holiday_entries"`
	HolidayQuests   int    `json:"holiday_quests"`
	HiddenEntries   int    `json:"hidden_entries"`
	EventWindows    int    `json:"event_windows"`
	EventOverrides  int    `json:"event_overrides"`
	DisabledEvents  int    `json:"disabled_events"`
	WarEffortQuests int    `json:"war_effort_quests"`
	LunarYears      int    `json:"lunar_years"`
	TagEntries      int    `json:"tag_entries"`
	InstanceQuests  int    `json:"instance_quests"`
}

type Counts struct {
	Quests              int `json:"quests"`
	QuestsWithCoords    int `json:"quests_with_coords"`
	CoordPins           int `json:"coord_pins"`
	QuestsWithTurnIns   int `json:"quests_with_turn_ins"`
	TurnInNPCs          int `json:"turn_in_npcs"`
	TurnInObjects       int `json:"turn_in_objects"`
	InstanceQuests      int `json:"instance_quests"`
	YearlyQuests        int `json:"yearly_quests"`
	RepeatableQuests    int `json:"repeatable_quests"`
	MonthlyQuests       int `json:"monthly_quests"`
	BreadcrumbQuests    int `json:"breadcrumb_quests"`
	QuestsWithRaces     int `json:"quests_with_races"`
	QuestsWithClasses   int `json:"quests_with_classes"`
	QuestsWithSkill     int `json:"quests_with_skill"`
	QuestsWithPrereqs   int `json:"quests_with_prereqs"`
	QuestsWithAltQuests int `json:"quests_with_alt_quests"`
}

type GapCounts struct {
	NoStarter         int `json:"no_starter"`
	ItemNoDropSource  int `json:"item_no_drop_source"`
	ItemDropNoSpawn   int `json:"item_drop_no_spawn"`
	StarterNoSpawn    int `json:"starter_no_spawn"`
	UnmappedZone      int `json:"unmapped_zone"`
	NoDungeonEntrance int `json:"no_dungeon_entrance"`
	MissingEntity     int `json:"missing_entity"`
	NoQuestieQuest    int `json:"no_questie_quest"`
}

type TurnInCounts struct {
	QuestsWithTurnIns int `json:"quests_with_turn_ins"`
	NPCs              int `json:"npcs"`
	Objects           int `json:"objects"`
	NPCQuests         int `json:"npc_quests"`
	ObjectOnlyQuests  int `json:"object_only_quests"`
}

type PolicyCoverage struct {
	YearlyBaseline   int   `json:"yearly_baseline,omitempty"`
	YearlyMarked     int   `json:"yearly_marked"`
	YearlyUnmarked   []int `json:"yearly_unmarked,omitempty"`
	InstanceBaseline int   `json:"instance_baseline,omitempty"`
	InstanceStatic   int   `json:"instance_static"`
	InstanceUnmarked []int `json:"instance_unmarked,omitempty"`
}

type BaselineReport struct {
	Quests             int              `json:"quests"`
	BaselineWithCoords int              `json:"baseline_with_coords"`
	NewWithCoords      int              `json:"new_with_coords"`
	StartsPreserved    int              `json:"starts_preserved"`
	StartsLost         []int            `json:"starts_lost,omitempty"`
	StartsGained       []int            `json:"starts_gained,omitempty"`
	LostStartGaps      GapCounts        `json:"lost_start_gaps"`
	MissingFromQuestie []int            `json:"missing_from_questie,omitempty"`
	Flags              []FlagComparison `json:"flags,omitempty"`
}

type FlagComparison struct {
	Name   string `json:"name"`
	Before int    `json:"before"`
	After  int    `json:"after"`
	Lost   []int  `json:"lost,omitempty"`
	Gained []int  `json:"gained,omitempty"`
}
