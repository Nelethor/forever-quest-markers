# Attribution

## Quest database

Quest coordinates, quest-giver and turn-in IDs, spawn points, restrictions, and related fields in `Database/` are derived from [QuestieDB](https://github.com/Questie/QuestieDB) Forever data. Holiday membership, event date windows, the AQ war effort quest list, and static instance-tag corrections come from [Questie](https://github.com/Questie/Questie).

- QuestieDB: https://github.com/Questie/QuestieDB
- Questie: https://github.com/Questie/Questie
- `Database/Metadata.lua` records the QuestieDB artifact build commit, artifact SHA-256, and Questie policy commit used for the conversion
- `Database/build_report.json` records generation counts, coverage gaps, and provenance
- This repository does not claim ownership of the upstream quest data or policy corrections

QuestieDB and Questie are licensed under **GPL-3.0**. The generated database files are derived from that data and are distributed under the same license. The addon code is **GPL-3.0-or-later**.

## World of Warcraft

World of Warcraft, its quests, and related names are trademarks and copyrights of Blizzard Entertainment, Inc.

## Addon code

Forever Quest Pins is original GPL-3.0-or-later code: a native-map overlay and a Go converter that turns QuestieDB Forever data into addon database files. Tracker UI and HereBeDragons usage from other addons were not copied.

Map pins use Blizzard’s `QuestNormal` atlas. The generated yellow, blue, and red-orange textures under `Media/` are original fallback art used only when the preferred atlas rendering fails.

## License

- Addon source: **GPL-3.0-or-later** ([LICENSE](LICENSE))
- Quest records: [QuestieDB](https://github.com/Questie/QuestieDB) (GPL-3.0)
- Holiday, event date, and instance-tag policy: [Questie](https://github.com/Questie/Questie) (GPL-3.0)
