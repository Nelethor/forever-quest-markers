# Changelog

Notable changes to Forever Quest Pins. Numbered releases use `v*` tags. Builds from `main` are available as commit-specific GitHub Actions artifacts for testing.

## 1.0.1 - 2026-11-11

- Update the QuestieDB Forever artifact to `f0442af288a63baeed64a8d117eb82a2364d0f7154312788dd60d27bf73e7b5b` (build `7f629bf2f41c3bfe40bb8d5cec3b5691bb1d4dca`).
- Ship 5768 quests with 9775 coordinate pins (678 static instance quests, 220 yearly quests).
- Show seasonal and holiday pins only while their Questie event window is live instead of for the whole year.
- Follow per-quest event windows, such as the narrower Winter Veil presents window.
- Classify AQ war effort pins from Questie's list and wait for a war effort quest to be offered or appear in the quest log.
- Add `/fqp wareffort always` to show AQ war effort pins without the phase confirmation.
- Report event windows, overrides, disabled events, and AQ phase details in `/fqp why`.
- Keep Darkmoon Faire hidden on Forever and document the limitation.

## 1.0.0 - 2026-11-11

- Add German, French, Brazilian Portuguese, Simplified and Traditional Chinese, Korean, Italian, and Russian localization based on the game client language.
- Include localization in locally compiled add-on packages.

## 0.4.7 - 2026-11-11

- Update the QuestieDB Forever artifact to `0dc5b2e793defd9145b5d75cda35fe101980f2eb5ff0c648fcf29a9a97b9b65a` (build `d57637f490c9dfcdbbc967dab47a8b0d8fe1b3cc`).
- Ship 5682 quests with 7674 coordinate pins (678 static instance quests, 220 yearly quests).

## 0.4.6 - 2026-11-10

- Add Spanish localization for Spain and Latin American Spanish clients, selected from the client locale.
- Use regional dungeon terminology and localized game quest and NPC names.

## 0.4.5 - 2026-11-10

- Update the QuestieDB Forever artifact to `de1b8277b0bbdea6f31f25467a84d1e9d77d029d3f61a8cb396d315f0d536996` (build `c0ce0c97ee449295ff1a8356f815a713ff9e463c`).
- Ship 5239 quests with 7307 coordinate pins (678 static instance quests, 215 yearly quests).

## 0.4.4 - 2026-11-09

- Add a high-level quest pin filter with a single slider that shows quests at every higher level by default.
- Preserve the all-levels default when upgrading from the previous checkbox setting.

## 0.4.3 - 2026-11-09

- Update the QuestieDB Forever artifact to `c5da415cd8ee8fb6b13b7b9b919e94a4cc7d42ae313aaa4da6e9c51f23f16991` (build `c1b50fefb19c064edc436429bef73435d9ff4254`).
- Ship 5233 quests with 7302 coordinate pins (678 static instance quests, 215 yearly quests).

## 0.4.2 - 2026-11-08

- Update the QuestieDB Forever artifact to `6445dc0a2b1abdcef8724ab7784447844cc9aaacac182b5d2a05aea19bb4152c` (build `aa1d7e7294596cf50a6fd0946dfae0d969cb9623`).
- Ship 5233 quests with 7304 coordinate pins (678 static instance quests, 215 yearly quests).

## 0.4.1 - 2026-11-07

- Keep quest pin tooltips available when click tracking is disabled.
- Add the click tracking option to the world map Show menu.

## 0.4.0 - 2026-11-07

- Add an option to let clicks pass through quest start pins.
- Limit tracking clicks to zone maps by default, with an option for world and continent maps.
- Reorganize the options panel to spread map controls across both columns.

## 0.3.10 - 2026-11-07

- Update the QuestieDB Forever artifact to `445e01d28b4f9087301561390aec4b7aecd580f1636e48db717c155b8a182056` (build `7c1cc5c72041c439ebff583f36c9357edd5a6787`).
- Ship 5233 quests with 7305 coordinate pins (678 static instance quests, 215 yearly quests).

## 0.3.9 - 2026-11-06

- Update the QuestieDB Forever artifact to `049f6fdb5baaf30938fb1773d721ed07d695898ed92691ae613f75b806d03bdd` (build `21be34023b72cf2ec3027cb9a61a8b72a1910857`).
- Ship 5233 quests with 6906 coordinate pins (678 static instance quests, 215 yearly quests).

## 0.3.8 - 2026-11-04

- Update the QuestieDB Forever artifact to `6ab2e647d69fb655e2cb8044653bcf2586db01c18c07efd5251ae258c41663dc` (build `4ab64311b6f0be1a96b38a5b95bfa27fa95416af`).
- Ship 5232 quests with 6721 coordinate pins (678 static instance quests, 215 yearly quests).

## 0.3.7 - 2026-11-03

- Update the QuestieDB Forever artifact to `ac3d011b007cb0d62e74865940e65f268b3cc32d1dc14629ab20e2e4de017bb8` (build `c5de61ab7c629132a772cccddf7f604ac48cecf9`).
- Ship 5232 quests with 6721 coordinate pins (678 static instance quests, 215 yearly quests).

## 0.3.6 - 2026-11-02

- Update the QuestieDB Forever artifact to `d6e088700694c0528e80e76036149b4b0d525ba130b61c53773d6624e25010d3` (build `a37877c1490027ee48e5722bf602adf34f95a6dc`).
- Ship 5232 quests with 6721 coordinate pins (678 static instance quests, 215 yearly quests).

## 0.3.5 - 2026-10-25

- Update the QuestieDB Forever artifact to `623db936a21e55919c2c3951a2557abba99ac93c60bc76b98771fdb55e6c54e1` (build `5c094f6e9a264f0dc54e2fde9731a37a97ed197c`).
- Ship 5232 quests with 6721 coordinate pins (678 static instance quests, 215 yearly quests).

## 0.3.4 - 2026-10-24

- Update the QuestieDB Forever artifact to `243a2ef21a9c3ce6280b2388d40d811fdd5e022c135c0e387652c2dc7c601638` (build `cb187dffa957157d3c93a4696000b62ea4539dd9`).
- Ship 5232 quests with 6721 coordinate pins (678 static instance quests, 215 yearly quests).

## 0.3.3 - 2026-10-23

- Resolve map-pin hover from normalized mouse and gamepad cursor positions while Gamepad UI is enabled.
- Show quest text using a named private tooltip, including when Blizzard suppresses the shared tooltip.

## 0.3.2 - 2026-10-22

- Prevent the native gamepad cursor from reading addon pin centers and tainting Blizzard's protected map interaction update.
- Preserve controller hover tooltips with a private tooltip.

## 0.3.1 - 2026-10-22

- Update the QuestieDB Forever artifact to `e38709c87c0f216dbf4fefea20927b812abe0481ecfb02fc05cf6cafb2539a22` (build `1f538335cfbb240c14a97c340f48c555fdc8a52b`).
- Ship 5232 quests with 6721 coordinate pins (678 static instance quests, 215 yearly quests).
- Use Questie's required level for pin eligibility so quests are not hidden until their recommended level.

## 0.3.0 - 2026-10-21

- Replace the All The Things Forever datasource with QuestieDB Forever and Questie policy corrections. No ATT fallback remains.
- Ship 5232 quests with 7260 coordinate pins, including item- and object-started quests, open-world dungeon entrances, and coordless records kept for tooltips and prerequisites.
- Group nearby spawn points into up to six pins per quest. Hovering shows the spawn count and every location on the map. The **Show spawn clusters** option switches to one pin per quest.
- Add NPC tooltips for ready turn-ins alongside available accepts, with `!` and `?` markers and duplicate suppression.
- Classify dungeon and raid quests from `C_QuestLog.GetQuestTagInfo`, generated Questie tag corrections, and the static database hint, in that order.
- Map Questie repeatable and monthly flags, split prerequisite AND/OR lists, and preserve holiday starts as yearly without inventing event IDs.
- Keep 4098 of 4152 previous ATT start pins. The 54 known gaps are 27 missing starters, 12 quests absent from QuestieDB, 8 item starts without a drop source, 1 item drop without a spawn, and 6 starters without a spawn or waypoint.
- Replace the ATT converter with `internal/questiedb`, `internal/questiepolicy`, and `internal/questdb`; add deterministic generation, provenance, parity reporting, CI drift checks, and the QuestieDB update workflow.
- Update attribution for QuestieDB and Questie (GPL-3.0) and the addon license to GPL-3.0-or-later.

## 0.2.25 - 2026-10-21

- Update the ATT Forever quest database to `1eb9f4552d6060944767711d75a6401c0edc8bf4`.
- Ship 4152 quests with 4366 coordinate pins (27 attunement quests).

## 0.2.24 - 2026-10-20

- Update the ATT Forever quest database to `15a9857ea3c53da111dd12ddeb73660d203a8bf5`.
- Ship 4061 quests with 4264 coordinate pins (27 attunement quests).

## 0.2.23 - 2026-10-19

- Update the ATT Forever quest database to `15549b9b236ae699733f9c108d1204555d66e05e`.
- Ship 4061 quests with 4264 coordinate pins (27 attunement quests).

## 0.2.22 - 2026-10-18

- Update the ATT Forever quest database to `8a1d2ce546c75abc48eaf3666e5f8419be23b895`.
- Ship 4060 quests with 4262 coordinate pins (27 attunement quests).

## 0.2.21 - 2026-10-17

- Update the ATT Forever quest database to `0a90b7fea6e277c7feb27aba02e15ca0c0b958b6`.
- Ship 4060 quests with 4262 coordinate pins (27 attunement quests).

## 0.2.20 - 2026-10-17

- Update the ATT Forever quest database to `70a0b420d8384743994a671f1b946230a5ef5011`.
- Ship 4053 quests with 4255 coordinate pins (27 attunement quests).

## 0.2.19 - 2026-10-16

- Update the ATT Forever quest database to `10164719738bdc1e7baa23dd854bef4c7184a6ac`.
- Ship 4052 quests with 4254 coordinate pins (27 attunement quests).

## 0.2.18 - 2026-10-16

- Update the ATT Forever quest database to `00a49a81c9a8b0f030dca9d0b5ada25dfba69980`.
- Ship 4052 quests with 4254 coordinate pins (27 attunement quests).

## 0.2.17 - 2026-10-15

- Defer controller-driven map pin tooltip and click callbacks until MapCanvas finishes its input update.

## 0.2.16 - 2026-10-14

- Update the ATT Forever quest database to `a9ceed3bf928764cb322fdc70f8e49976c4b01f5`.
- Ship 3982 quests with 4182 coordinate pins (27 attunement quests).

## 0.2.15 - 2026-10-13

- Add an option in settings and the world map Show dropdown to hide quest-start pins on world and continent maps while keeping them on zone, city, and dungeon maps. The option defaults on.

## 0.2.14 - 2026-10-13

- Update the ATT Forever quest database to `f62d0552463cbfdf27d9f8a8910bd87f081ec65d`.
- Ship 3973 quests with 4173 coordinate pins (27 attunement quests).

## 0.2.13 - 2026-10-12

- Update the ATT Forever quest database to `1b1ab4b5ea7c3f9744ef24ff0cc210de1bfb6a11`.
- Ship 3966 quests with 4154 coordinate pins (27 attunement quests).

## 0.2.12 - 2026-10-12

- Update the ATT Forever quest database to `552603fa49a4d541873fd396978743e7d2780299`.
- Ship 3918 quests with 4106 coordinate pins (27 attunement quests).

## 0.2.11 - 2026-10-11

- Update the ATT Forever quest database to `f5d90835055a8a21671d5406fc219ba17efba321`.
- Ship 3906 quests with 4094 coordinate pins (27 attunement quests).

## 0.2.10 - 2026-10-09

- Grey out quest category controls in the world map dropdown and options panel while quest start pins are off. Re-enabling quest start pins restores access to the controls and keeps your saved selections.

## 0.2.9 - 2026-10-09

- Add normal, class, profession, and dungeon / raid quest pin filters, enabled by default, to the options panel and world map Show dropdown.
- Add repeatable, seasonal / holiday, and AQ war effort controls to the map dropdown. Shorten map labels and move Navigation to the right options column.
- Add **Copy Wowhead URL** when right-clicking a quest title in Blizzard’s tracker. Copy the selected Forever quest link with Cmd+C or Ctrl+C.

## 0.2.8 - 2026-10-09

- Update the ATT Forever quest database to `0647c57dc4dc3db8f99b6b86c96f7da65e7e38e2`.
- Ship 3901 quests with 4089 coordinate pins (27 attunement quests).

## 0.2.7 - 2026-10-08

- Shift-click a quest pin to hide it. Stacked pins hide every quest on them. Hidden pins are saved per character in the account SavedVariables; restore them with **Reset hidden quest pins** in settings or `/fqp unhide <id|all>`, and list them with `/fqp hidden`.
- Choose how far below your level a quest must be before its pin is hidden: settings slider or `/fqp trivial <3-15>` (default 9).

## 0.2.6 - 2026-10-08

- Update the ATT Forever quest database to `c269971e856a1da16883cc94cba33d2ec5a90b02`.
- Ship 3885 quests with 4073 coordinate pins (27 attunement quests).

## 0.2.5 - 2026-10-07

- Update the ATT Forever quest database to `d8a426dfa781057fc8ff4608e963e24bdc6e6761`.
- Ship 3885 quests with 4073 coordinate pins (27 attunement quests).

## 0.2.4 - 2026-10-07

- Compile ATT inline quest names into `attTitle` at database build time and use them when `C_QuestLog` has no title yet.
- Regenerate the ATT Forever quest database (3868 quests with ATT title fallbacks).

## 0.2.3 - 2026-10-07

- Restore daily ATT database updates and `tools/build_quest_db.py`; remove the Go wow-database compiler and CI path.
- NPC tooltips show available accepts only (drop in-log turn-in `?` rows).
- Update the ATT Forever quest database to `bff19e245191182bc32279ca69f0648000c643ec`.
- Ship 3877 quests with 4066 coordinate pins (27 attunement quests).

## 0.2.2 - 2026-10-07

- Remove bag/scroll item/object start pin icons and the related settings toggle (`/fqp itemicons`).
- Honor split prerequisite lists (`sourceQuestGroup` plus `sourceQuestSingle`) from the wow-database export.
- Update the Forever quest database to wow-database `25b44519c551ca7c25200ae4f4fac697e2e12521`.
- Ship 2159 quests with 1728 coordinate pins across 38 maps.

## 0.2.1 - 2026-10-06

- Distinct map pins for item-started and object-started quests: cropped loot bag (`INV_Misc_Bag_10`) or scroll (`INV_Scroll_03`) base with a smaller `QuestNormal` bang.
- Dungeon item/object drops use bag/scroll plus an orange bang; plain dungeon starts stay red-orange `!`.
- Add **Special icons for item/object starts** (on by default) and `/fqp itemicons` to fall back to tinted `!`.
- Compiler emits `isItemStart` / `isObjectStart` from wow-database starters and keeps available-spawn coordinates.
- Pin style priority is class, profession, item, object, dungeon/raid, repeatable, then normal; mixed stacks stay yellow.
- Update the Forever quest database to wow-database `ddcf905d5f558b988448d10b47a44c4db3982856`.
- Ship 5010 quests with 2751 coordinate pins across 40 maps.

## 0.2.0 - 2026-10-06

- Tint class-restricted start pins with your class color and profession start pins copper.
- Rogue class pins keep class yellow and add a 1px dark bang shadow so they do not read as normal quest gold.
- Pin color priority is dungeon/raid, then class, profession, repeatable, then normal; mixed stacks stay yellow.
- Hide start pins immediately on accept and turn-in when Forever’s completed-ID list or quest log lags behind the quest events (#93).
- Stop rebuilding completion, profession, and NPC tooltip indexes on every map layout refresh so the larger wow-database quest set does not thrash memory.

## 0.1.62 - 2026-10-06

- Update the Forever quest database to wow-database `af14dffe4d656c8afa55b14c101be0e370460dde`.
- Ship 5010 quests with 4122 coordinate pins across 40 maps.

## 0.1.61 - 2026-10-04

- Quest data now comes from wow-database. This build has 782 quests with start coordinates.
- NPC tooltips list in-log turn-ins as well as quests you can accept.

## 0.1.60 - 2026-10-04

- Restore NPC mouseover tooltips that list available quest accepts with level-colored titles.
- Add **Show quests on NPC tooltips** (on by default) and `/fqp npctooltip`. Turn-in lines are not shown.

## 0.1.59 - 2026-10-04

- Update the ATT Forever quest database to `bff19e245191182bc32279ca69f0648000c643ec`.
- Ship 3877 quests with 4066 coordinate pins across 49 maps.

## 0.1.58 - 2026-10-03

- Update the ATT Forever quest database to `308bd0938fbaf206e13678f4b3f0f3b92dfb19d4`.
- Ship 3865 quests with 4054 coordinate pins across 49 maps.

## 0.1.57 - 2026-10-02

- Update the ATT Forever quest database to `788f116745f31e5b2da7171881919f3c44610140`.
- Ship 3864 quests with 4053 coordinate pins across 49 maps.

## 0.1.56 - 2026-10-01

- Skip secret unit GUIDs when capturing a quest offer so gossip no longer errors under addon taint.

## 0.1.55 - 2026-10-01

- Hide the quest tracker in combat using opacity instead of automatic collapse to avoid tracker layout taint affecting secret aura reads.
- Restore the tracker's original opacity after combat or when combat hiding is disabled, preserving manual collapse settings.

## 0.1.54 - 2026-10-01

- Update the ATT Forever quest database to `b03ef10e7e174a06654011099e9194c31e8d90b8`.
- Ship 3838 quests with 4026 coordinate pins across 49 maps.

## 0.1.53 - 2026-09-30

- Track quest starts with Blizzard Map Pins by default, with TomTom available as an optional waypoint provider.
- Follow Blizzard quest tracking for objectives and turn-ins after accepting a selected quest.
- Add a checkbox for Blizzard’s in-world destination marker and reorganize options into clearer groups.
- Preserve manually changed Blizzard destinations and add waypoint tracking and clearing commands.

## 0.1.52 - 2026-09-30

- Stop using `HookScript` on `WorldMapFrame` for quest pin show, resize, and live snap; watch the map from the addon frame instead to reduce Edit Mode layout taint risk.
- Refine that watcher with `hooksecurefunc` Show/Hide, resize checks on the map frame, scroll container, detail frame, and canvas, and `OnUpdate` only while the world map is open.

## 0.1.51 - 2026-09-30

- Update the ATT Forever quest database to `9308dc1d7d5f61c72fe440f744bb16dd6459899c`.
- Ship 3837 quests with 4021 coordinate pins across 49 maps.

## 0.1.50 - 2026-09-30

- Add **Hide Blizzard Quest Tracker in combat** (off by default). Collapses the default objective tracker while you are in combat and restores it afterward.

## 0.1.49 - 2026-09-28

- Update the ATT Forever quest database to `be1b98585edb9efb6fcfb5cf1e6394de3df9133d`.
- Ship 3995 quests with 4258 coordinate pins across 49 maps.

## 0.1.48 - 2026-09-27

- Hide trivial map pins using the client quest level shown in tooltips (`[5]`), not only ATT `minLevel`, and refresh pins when that level loads.

## 0.1.47 - 2026-09-27

- Hide trivial / low-level map pins when the quest is 9+ levels below your character while **Show trivial / low-level pins** is off.

## 0.1.46 - 2026-09-27

- Add an **Icon Scale** option for resizing world-map quest markers from 50% to 150%, defaulting to 100%.

## 0.1.45 - 2026-09-27

- Add **Show quest-start pins** to the world map's **Show** dropdown, synchronized with the existing addon setting and slash commands.

## 0.1.44 - 2026-09-27

- Preserve ATT's Skyborne Alliance and Horde race restrictions so faction-specific Zephras Isle quests are filtered correctly.

## 0.1.43 - 2026-09-27

- Update the ATT Forever quest database to `89ce67b27e31c2d1f85775c9382aff8861828fbe`.
- Ship 3984 quests with 4247 coordinate pins across 49 maps.
- Remove NPC quest rows from unit tooltips because the Forever client does not expose enough reliable quest relationship data to keep them accurate.

## 0.1.42 - 2026-09-26

- Ignore protected NPC names returned by Blizzard's tooltip API before comparing or caching them, preventing taint errors during map refreshes in instances.

## 0.1.41 - 2026-09-26

- Update the ATT Forever quest database to `e93755e1fa7a412fd54aeedfc229e4b06a96d8bf`.
- Ship 3983 quests with 4246 coordinate pins across 49 maps.

## 0.1.40 - 2026-09-26

- Update the ATT Forever quest database to `8ae93c0f53a1b423783e87fd17eaa50c8d380060`.
- Ship 3983 quests with 4246 coordinate pins across 49 maps.

## 0.1.39 - 2026-09-25

- Defer map-pin refreshes until combat ends to prevent blocked `SetPassThroughButtons` actions from Blizzard's map canvas.

## 0.1.38 - 2026-09-25

- Update the ATT Forever quest database to `37c4c06a6e9978c3698c4c93fce38090c58f9163`.
- Ship 3980 quests with 4243 coordinate pins across 49 maps.

## 0.1.37 - 2026-09-25

- Update the ATT Forever quest database to `19896d7fddbd815e034872fb14729684076348be`.
- Ship 3967 quests with 4230 coordinate pins across 49 maps.

## 0.1.36 - 2026-09-25

- Update the ATT Forever quest database to `8c98ec1d81128e317eb04f21bc25290d7d8b2049`.
- Ship 3818 quests with 4081 coordinate pins across 49 maps.

## 0.1.35 - 2026-09-24

- Learn missing NPC quest starters from offered quests during the current session, including when map coordinates are unavailable.
- Keep NPC tooltip quests visible with a placeholder when their titles are unavailable, and retry failed title loads on later lookups.

## 0.1.34 - 2026-09-24

- Update the ATT Forever quest database to `29473e9ec0f9081bbc4adf9bd1d77263ab0ed8f1`.
- Ship 3788 quests with 4048 coordinate pins across 49 maps.

## 0.1.33 - 2026-09-23

- Turn off **Show trivial / low-level pins** and **Show AQ war effort pins** by default so new installs see a quieter map; enable them under AddOns or with `/fqp trivial` and `/fqp wareffort`.

## 0.1.32 - 2026-09-23

- Treat this character's completed-quest list as the only completion source when it loads, so a follow-up such as The Stagnant Oasis stays hidden until The Forgotten Pools is turned in on this character.

## 0.1.31 - 2026-09-23

- Preserve ATT `requireSkill` restrictions in the generated quest database.
- Hide profession-specific quest pins and NPC tooltip rows unless the character knows the required profession or specialization.

## 0.1.30 - 2026-09-23

- Update the ATT Forever quest database to `1bf370c85bb1f2a8fd609677555fc61ef86b0984`.
- Ship 3786 quests with 4046 coordinate pins across 49 maps.

## 0.1.29 - 2026-09-22

- Update the ATT Forever quest database to `7dac12df8c523de5519dcb84480cea0010b7ff12`.
- Ship 3698 quests with 3958 coordinate pins across 49 maps.

## 0.1.28 - 2026-09-21

- Show available ATT-listed quests in NPC mouseover tooltips with their recommended quest levels, independently of map-pin visibility.
- Add an enabled-by-default NPC tooltip setting and refresh rows when quest state, title, or level data changes.
- Preserve Forever's native objective blocks and omit incomplete or completed finisher rows because the tested client does not expose a reliable quest-to-finisher relationship on hover.
- Refresh ATT source provenance to `3365ae17615c11bd7c091ddcf5b99ac7b9cee7b4`; the shipped quest records remain unchanged from 0.1.27.

## 0.1.27 - 2026-09-21

- Update the ATT Forever quest database to `5cf53e4932c7359506c8ec03701aa332c934756b`.
- Ship 3698 quests with 3958 coordinate pins across 49 maps.

## 0.1.26 - 2026-09-20

- Extend red-orange map pins to ATT dungeon and raid quests, including the Ragefire Chasm quests, alongside attunement chains.
- Add an optional auto-accept recommended-level ceiling, disabled by default, with a -5 to +5 slider defaulting to +1 relative to the player's level.

## 0.1.25 - 2026-09-20

- Register map pins with Blizzard's map pin pool so the map owns their layering, scaling, and redraw lifecycle.

- Remove the always-visible fallback icon layer and avoid resetting unchanged pin anchors every frame.
- Add an optional local account SavedVariables loading repair for affected Forever clients, with a TOC backup and dry-run mode.

- Synchronize revisioned account and character settings with legacy/CVar mirrors and a logout flush. Affected Forever clients still require the optional local settings-loader repair.
- Show complete ATT-derived dungeon and raid attunement chains with red-orange `!` pins; mixed stacks remain yellow.
- Extract faction-specific ATT quest wrappers and regenerate the database at `5b09b3adf6816fcf95acef09251169e5ae97e80e`.
- Ship 3665 quests with 3925 coordinate pins across 49 maps, including 27 attunement quests.

## 0.1.24 - 2026-09-20

- Show ATT-marked repeatable quest starts with blue `!` pins; mixed normal/repeatable stacks remain yellow.
- Add a default-on setting and `/fqp repeatable` command for repeatable quest pins.
- Update the ATT Forever quest database to `5b09b3adf6816fcf95acef09251169e5ae97e80e`.
- Ship 3505 quests with 3729 coordinate pins across 49 maps.

## 0.1.23 - 2026-09-20

- Update the ATT Forever quest database to `6274f2e694e7894f95adb2419a0f18155b2fe0e0`.
- Ship 3505 quests with 3729 coordinate pins across 49 maps.

## 0.1.22 - 2026-09-20

- Update the ATT Forever quest database to `54e1fefdbe3b555d38a5560a35ab0c56382870c6`.
- Ship 3503 quests with 3727 coordinate pins across 49 maps.

## 0.1.21 — 2026-09-19

- Simplify settings persistence to one authoritative account-wide table initialized once on `ADDON_LOADED`.
- Migrate missing values from the legacy per-character table without continuing to synchronize two competing stores.
- Mirror the seven boolean options into a custom CVar as a temporary fallback for Forever 1.60.1 builds that restore CVars but skip addon SavedVariables.

## 0.1.20 — 2026-09-19

- Fix options resetting after `/reload` again: do not create empty SavedVariables on `ADDON_LOADED` before Forever injects saved tables; prefer the per-character table when merging; always write both SavedVariables on change.

## 0.1.19 — 2026-09-19

- Optional **AQ war effort** pins (Orgrimmar / Ironforge commodity turn-ins). On by default; turn off under AddOns or with `/fqp wareffort` if the stacked markers are too noisy.

## 0.1.18 — 2026-09-19

- Options persist again after `/reload` for new installs
- If you already ran **0.1.10–0.1.16** and a toggle still snaps back: fully close the game and delete leftover `ForeverQuestPins.lua` (and `.bak`) under account and character `SavedVariables`. New users skip this.
- `/fqp wipe` only prints those paths; it does not delete files while the client is running
- Do not copy a default-filled placeholder over a SavedVariables table Forever injects later

## 0.1.17 — 2026-09-19

- Bind options the way working Forever addons do (Quest Master / AceDB, HideAnything): one SavedVariables table, created on `ADDON_LOADED` if missing, mutated in place, never replaced; write the same keys onto the per-character table; flush on logout. Drop `LoadSavedVariablesFirst` and the late-bind scratch buffer that left Forever serializing an empty table.

## 0.1.16 — 2026-09-19

- Store settings in a separate per-character SavedVariables table (`ForeverQuestPinsCharacterSettings`) because Forever is not persisting this addon’s account-wide table; request SavedVariables before addon files load

## 0.1.15 — 2026-09-19

- Remove native Settings registrations: initializing a proxy setting can invoke its default-value setter and overwrite a saved `autoAccept=true` / `autoTurnIn=true` with `false`; the Options canvas now exclusively reads and writes the addon SavedVariables table

## 0.1.14 — 2026-09-19

- Stop creating `ForeverQuestPinsDB_Settings` at file load (Forever can bind the real SavedVariables table later); buffer changes until that table exists, merge on login, and only create a new table on `PLAYER_ENTERING_WORLD` if still missing

## 0.1.13 — 2026-09-19

- Fix Options checkboxes that used Blizzard’s legacy Settings API fallback (values lived outside `ForeverQuestPinsDB_Settings` and vanished on `/reload`); use proxy settings that call `SetOption`, drop the broken fallback, and retry registration on `PLAYER_LOGIN`
- `/fqp settings` dumps raw SavedVariables vs effective values

## 0.1.12 — 2026-09-19

- Persist options the usual way: fill `ForeverQuestPinsDB_Settings` on `ADDON_LOADED`, write keys on that table, bind Forever Settings checkboxes to it, and toggle from the saved flag instead of `GetChecked`
- `/fqp stats` prints auto-accept and auto-turn-in

## 0.1.11 — 2026-09-19

- Persist auto-accept / auto-turn-in in the addon SavedVariables table Forever actually writes (not a separate `_G` copy), merge clicks if that table arrives late, and do not treat Options `SetChecked` as a click

## 0.1.10 — 2026-09-19

- Keep auto-accept and auto-turn-in checked after `/reload` (do not assign defaults before SavedVariables load; re-sync the Options checkboxes)

## 0.1.9 — 2026-09-19

- Pin tooltips show suggested quest level like the Forever tracker (`[9] Minshina's Skull`), via `C_QuestLog.GetQuestDifficultyLevel`

## 0.1.8 — 2026-09-19

- Use Blizzard’s retail `QuestNormal` bang at a fixed 24px size
- Drop the solid yellow square behind pins
- Keep `Media/QuestAvailable.tga` only if `SetAtlas` errors
- Do not bind gossip `AvailableQuestIcon` on the map

## 0.1.7

- Draw a solid yellow fill so a hoverable pin could not be an empty hitbox
- Overlay the bundled TGA instead of Forever’s empty gossip / atlas binds

## 0.1.6

- Prefer gossip `AvailableQuestIcon` when `QuestNormal` drew nothing
- Treat ATT breadcrumb sources as skippable (Gornek’s Cutting Teeth vs Kaltunk)
- Remember quests an NPC just offered, including Forever-only starts missing from ATT

## 0.1.5

- Show Morin Cloudstalker’s The Venture Co. and Supervisor Fizsprocket after the Ravaged Caravan crate
- Keep ATT coordinates (plus Morin’s crate-end patrol pin); do not replace them with a live or stale NPC point
- `/fqp why <id>` and `/fqp available`
- Merges to `main` publish a moving `latest` pre-release zip

## 0.1.4

- Windowed and maximized pins stay on the map art
- Stack overlapping starts onto one bang
- Project live NPC positions from continent coords onto the zone map
- Treat `GetQuestsCompleted` as a completion fallback

## 0.1.3

- Fixed on-screen bang size (do not inherit map zoom or native atlas size)
- Draw pins above map tiles
- Keep a pin when the first layout pass has no canvas size yet

## 0.1.2

- Auto-accept and auto-turn-in options (`/fqp accept`, `/fqp turnin`; hold Shift to skip)
- Debug tooltips; names instead of IDs unless debug is on
- Prefetch quest titles
- Parent pins to the map canvas so they do not drift on resize
- Snap wandering quest-giver pins while the NPC is visible

## 0.1.1

- Blizzard `QuestNormal` atlas on map pins, with gossip and TGA fallbacks
- Unmigrated ATT `zzOLD` zones as a fallback for classic (pre-Cata) quests
- Seasonal pins off unless `/fqp seasonal` is on or the event is active
- Project zone pins onto continent maps

## 0.1.0

- Initial release: native world-map start markers for unaccepted quests
- ATT Forever database converter and automated update workflow
