# Development

Forever Quest Pins is a small World of Warcraft Forever addon (Interface **16001**). Players should read [README.md](../README.md). This file is for maintaining the repo, database, and releases.

Repository tools use Go 1.27 or later. The Lua runtime tests also require LuaJIT on `PATH`.

## Layout

| Path | Role |
|------|------|
| `ForeverQuestPins.toc` | Load order, Interface 16001, packager metadata |
| `Config.lua` | Saved variables, slash commands, settings panel |
| `HiddenQuests.lua` | Per-character Shift-click hidden quest pins, stored in the account DB under `hiddenQuests["Name-Realm"]` |
| `Eligibility.lua` | Completion, log, source quests, NPC-offered quests |
| `Events.lua` | Holiday windows and AQ war effort phase state from generated policy |
| `MapPins.lua` | World-map start pins |
| `Waypoints.lua` | Optional Blizzard / TomTom navigation and selected quest lifecycle |
| `AutoQuests.lua` | Optional auto-accept / auto-turn-in |
| `Core.lua` | Events and refresh |
| `Database/ForeverQuests.lua` | Generated quest records (do not edit by hand) |
| `Database/Metadata.lua` | Pinned QuestieDB artifact, checksum, policy commit, and counts |
| `Database/QuestTagCorrections.lua` | Generated static instance-tag corrections |
| `Database/EventPolicy.lua` | Generated holiday windows, per-quest overrides, Lunar Festival years, and AQ war effort IDs |
| `Database/build_report.json` | Build stats (not shipped in the player zip) |
| `VERSION` | Current stable release used by automated version checks |
| `RELEASE_NOTES.md` | Curated notes for only the current release |
| `Media/QuestAvailable.tga` | Yellow fallback bang if `QuestNormal` fails |
| `Media/QuestRepeatable.tga` | Blue fallback if the tinted `QuestNormal` atlas cannot be used |
| `Media/QuestAttunement.tga` | Red-orange fallback for dungeon and raid quests |
| `cmd/fqp` | Go command-line entry point for repository tools |
| `internal/questiedb/` | QuestieDB TOC, CBOR, entity, zone, and dungeon readers |
| `internal/questiepolicy/` | Questie holiday and instance-tag policy parser |
| `internal/questdb/` | Merge, start resolution, schema mapping, emitter, and report |
| `internal/release/` | Prepares database releases and validates automated patch releases |
| `internal/foreverupdate/` | Blizzard build feed → TOC compatibility release |
| `internal/addontools/` | Addon compiler, settings repair, and fallback TGA generation |
| `.pkgmeta` | [BigWigs packager](https://github.com/BigWigsMods/packager) rules |

## Database

Quest coordinates, starters, turn-in targets, and restrictions come from the [QuestieDB](https://github.com/Questie/QuestieDB) Forever preview artifact. Holiday membership, event windows, the AQ war effort quest list, and instance-tag corrections come from [Questie](https://github.com/Questie/Questie).

```bash
go run ./cmd/fqp build-db \
  --questiedb /path/to/QuestieDB-Forever.zip \
  --questiedb-sha bdfc31538466a575c9a4aa8d7c2cf9678cf3ca4734f682c5381f0d697e567aa8 \
  --questiedb-ref preview \
  --questie /path/to/Questie \
  --questie-sha d0b0e89ac228e380e139f1c524408507e6d4fe1b \
  --out Database
```

`--questiedb` accepts the release zip or an extracted directory. A second run on the same artifact and policy commit produces the same bytes. `Database/Metadata.lua` records the artifact SHA-256, build commit, policy commit, contract version, and counts. `Database/QuestTagCorrections.lua` is loaded before `Eligibility.lua` and gives the runtime a static instance hint when `C_QuestLog.GetQuestTagInfo` is missing or slow.

`Database/EventPolicy.lua` is generated from Questie's Era event data. It carries year-less `{ month, day, hour, minute }` windows, per-quest overrides such as the Winter Veil presents, Questie's Lunar Festival year table, and the `AQWarEffortQuests` IDs. The build fails if a yearly quest has no event name or a referenced event has neither a window nor a disabled marker. Darkmoon Faire is emitted as disabled: Questie skips it on Forever, it has no importable faire window, and most of its records mix Mulgore and Elwynn coordinates. Lunar Festival windows end at Questie's pinned year; later years hide with `lunar-year-unknown` instead of failing the build.

The generated records separate prerequisites into AND (`sourceQuestGroup`) and OR (`sourceQuestSingle`, required count 1) lists. Coordless records stay in the database for tooltips and prerequisites but are excluded from `ns.ByMap`; gossip-learned starts fill their coordinates at runtime. Turn-in NPC and object ids are compiled into the database and shown on NPC tooltips when the quest is active and complete.

Optional parity review against an older database:

```bash
go run ./cmd/fqp build-db ... --out Database --baseline /path/to/old/ForeverQuests.lua
```

This adds recovered/lost starts, coordinate changes, flag changes, and conflicts to `Database/build_report.json`. The committed build report omits the baseline so it can be reproduced from the pinned inputs.

### Automated updates

Workflow **Update QuestieDB database** (`.github/workflows/update-questie-db.yml`):

- Daily at 06:00 UTC and on manual **Run workflow**
- Downloads the mutable QuestieDB `preview` artifact and records its SHA-256 in the PR
- Checks out Questie at the policy commit already pinned in `Database/Metadata.lua`
- Opens a versioned PR only when `Database/ForeverQuests.lua` or `Database/EventPolicy.lua` changed; artifact SHA-only updates with no data diff are ignored
- Closes its existing `questie-db-update` PR if regenerated quest records return to the version already on `main`
- Bumps the patch version and updates `CHANGELOG.md` and the current `RELEASE_NOTES.md`
- Publishes the prepared GitHub and CurseForge release after a human reviews and merges the PR
- Needs **Settings → Actions → General → Workflow permissions → Allow GitHub Actions to create and approve pull requests**

It never pushes generated data straight to `main` or merges its own PR.

## Forever interface updates

Workflow **Update Forever interface** (`.github/workflows/update-forever-interface.yml`):

- Runs Wednesday at 12:00 UTC, after the US Tuesday and EU Wednesday maintenance windows
- Reads Blizzard's explicit `wow_classic_beta` product feed and converts versions such as `1.60.1.69913` to Interface `16001`
- Ignores build-only changes when the calculated Interface is unchanged
- Opens or refreshes the reviewed `forever-interface-update` PR with the TOC, next patch version, changelog entry, and current release notes
- Closes that fixed PR if the current Interface is already supported on `main`
- Publishes the prepared GitHub and CurseForge release only after a human merges the PR

Run it manually from `main` when an out-of-cycle Forever patch lands. If Blizzard moves Forever off `wow_classic_beta` after launch, change the single `VersionsURL` constant in `internal/foreverupdate/update.go` rather than falling back to another WoW flavor.

## Tests

```bash
go test ./...
go vet ./...
```

The Go Lua-runtime tests require LuaJIT on `PATH`. On macOS with Homebrew, install it with `brew install luajit`; CI installs the Ubuntu `luajit` package.

CI (`validate`) runs the Go tests, checks release intent, and dry-runs the packager. Database regeneration runs in the automated update workflow, not CI.

## Local builds

After editing `CHANGELOG.md` for a player-facing release, run `go run ./cmd/fqp generate-news` and include `WhatsNew.lua` in the change. The generator selects the latest release with player-facing entries and omits QuestieDB artifact and quest-count entries. Database-only releases therefore do not produce a new chat announcement. The Go tests check that the generated file is current.

Build a clean, directly installable addon folder with:

```bash
go run ./cmd/fqp compile-addon
```

Each run deletes the previous `.compiled/ForeverQuestPins` directory and recreates it from the files shipped by `.pkgmeta`. The generated TOC uses the current Git description as its version. Copy `.compiled/ForeverQuestPins` directly into the client's `Interface/AddOns` directory.

Use `go run ./cmd/fqp compile-addon --dry-run` to list the files without changing `.compiled/`.

## Other repository tools

Run the Blizzard compatibility updater with `go run ./cmd/fqp update-interface`. It fetches the current `wow_classic_beta` version feed and prepares release files only when the interface changes. Use `--versions-file /path/to/feed` to test a saved response, or `--dry-run` to preview it.

Prepare or validate release metadata with `go run ./cmd/fqp release prepare --base-version VERSION`, `go run ./cmd/fqp release validate-notes --version VERSION`, `go run ./cmd/fqp release validate ...`, or `go run ./cmd/fqp release validate-tag ...`. The automated workflows use the validation commands when deciding whether a reviewed patch release is valid.

Regenerate fallback textures with `go run ./cmd/fqp generate-icon`. Repair local account settings with `go run ./cmd/fqp repair-settings --addon /path/to/ForeverQuestPins --saved /path/to/SavedVariables/ForeverQuestPins.lua`; add `--apply` only after closing WoW completely. The tool previews by default and never modifies the saved settings file.

## Releases

| Channel | Trigger | Result |
|---------|---------|--------|
| Stable | Push an annotated `v*` tag, or merge a prepared quest database/interface PR | Numbered GitHub Release and CurseForge package |
| Preview | Merge to `main` or manually run the Release workflow | Commit-specific GitHub Actions artifact |

Only stable tags are distributed to players. Preview builds are for testing and do not push or move a Git tag. Do not point players at GitHub's “Source code” archives; the packager zip is the installable addon.

`.pkgmeta` ships addon Lua, `Database/*.lua`, `Media/`, `LICENSE`, `README.md`, `ATTRIBUTION.md`, `CHANGELOG.md`, and `RELEASE_NOTES.md`. It does **not** ship `VERSION`, `tests/`, `cmd/`, `internal/`, `.github/`, or `build_report.json`.

The packager uploads `RELEASE_NOTES.md` as the release changelog instead of generating notes from Git commits. This prevents commit metadata from appearing on CurseForge and avoids publishing the full release history. Automated database and Forever Interface PRs replace this file with only their prepared release entry. CI requires that entry to match `VERSION` and rejects email addresses.

All stable releases must update `VERSION` to match the tag. Automated database and Forever Interface PRs do this, and merging either creates the tag. If both prepare the same patch concurrently, merge one and manually rerun the other updater so its fixed PR refreshes against the new `main`. For other releases, update `VERSION`, `CHANGELOG.md`, and `RELEASE_NOTES.md` in the release PR before creating the tag.

## CurseForge

CurseForge uses its [native automatic packager](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging). GitHub Actions does not upload to CurseForge.

Project configuration:

1. Set **Source Code** to the public GitHub repository.
2. Set **Automatic Packaging** to package new tagged commits, not all commits.
3. Generate a dedicated CurseForge API token for the repository webhook.
4. In GitHub repository settings, add a webhook for push events with this payload URL:

   ```text
   https://www.curseforge.com/api/projects/{projectID}/package?token={token}
   ```

5. Keep the webhook defaults and verify its initial delivery succeeds.

The payload URL contains the API token. Never commit it, add it as an Actions secret, paste it into an issue, or include it in logs. Revoke and replace the token if the URL is exposed.

The native packager reads `.pkgmeta` and replaces `@project-version@` with the pushed tag. A normal tag such as `v0.1.22` is a Release; tags containing `beta` or `alpha` receive the corresponding CurseForge status. Do not add `X-Curse-Project-ID` solely for native packaging.

License on CurseForge: **GPL-3.0-or-later**. Credit QuestieDB for the quest data and Questie for policy corrections. See [ATTRIBUTION.md](../ATTRIBUTION.md).

## Pin textures

Normal map pins call `SetAtlas("QuestNormal", false)` at a fixed 24px size. Special pins use the same atlas with desaturation and a vertex tint: red-orange for dungeon/raid, `RAID_CLASS_COLORS` / `C_ClassColor` for class-only stacks, copper `(1.00, 0.65, 0.20)` for profession-only stacks, and blue for repeatable-only stacks. Rogue class pins also draw a near-black tinted `QuestNormal` on the ARTWORK fill layer, offset 1px down-right, so class yellow does not look like a normal start. Priority is instance, class, profession, repeatable, then normal; mixed stacks stay yellow. Instance classification asks `C_QuestLog.GetQuestTagInfo`, falls back to the generated Questie tag corrections, then to the static `isInstanceQuest` flag. Bundled yellow, blue, and red-orange TGAs remain as fallbacks, followed by `QuestDaily` for repeatable pins. Do not bind `Interface\GossipFrame\AvailableQuestIcon` on the map: on Forever that path can succeed with no pixels and hide working art.

MapCanvas pins return no center to Forever's native gamepad cursor so closing the map does not taint its protected interaction-target update. The addon retains each pin's original center for its own hover lookup and uses a private tooltip while Gamepad UI is active. Verify in game by hovering an addon pin with the controller, then closing the map; confirm the tooltip works and no blocked-action popup or taint-log entry appears.

## Support split

- Pin / eligibility / auto-quest / NPC tooltip bugs → this repo’s issues
- Wrong coordinates or missing Forever quests in the converted DB → [QuestieDB](https://github.com/Questie/QuestieDB) Forever data, unless our converter dropped a spawn QuestieDB has
- Wrong holiday membership, event dates, AQ war effort membership, or instance tags → [Questie](https://github.com/Questie/Questie) corrections, unless our parser dropped an entry

## Waypoint providers

Blizzard Map Pins is the default. Start clicks use zone coordinates, normalized
from the database's 0–100 units, with `UiMapPoint.CreateFromCoordinates`,
`C_Map.SetUserWaypoint`, and optionally `C_SuperTrack.SetSuperTrackedUserWaypoint`.
On acceptance, `C_SuperTrack.SetSuperTrackedQuestID` hands objective and turn-in
navigation to Blizzard. TomTom receives the location returned by
`C_QuestLog.GetNextWaypoint` and updates on quest-log / POI refreshes.
Unavailable coordinates remove the old TomTom target until new data arrives.

References checked during implementation:

- [Blizzard map API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua)
- [Blizzard quest location API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
- [Blizzard super-tracking API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SuperTrackManagerDocumentation.lua)
- [Adventure Guide Forever](https://github.com/cjber/adventure-guide-forever), which documents native waypoint guidance as its optional-provider fallback

The published Classic and Classic Beta API snapshots omit the retail user
waypoint functions. Check actual Forever support with `/fqp apis`; runtime
capability checks report unsupported clients/maps. TomTom signatures and options
were also verified against the locally installed Forever-compatible TomTom.
The user verified that `/console showInGameNavigation 1` enables Forever's
native floating navigation marker. The Navigation checkbox reads and writes
that shared CVar directly, so it reflects changes from the console or other
addons and does not overwrite the player's choice on login. Verify presentation
in game.

In-game verification: choose Blizzard Map Pins with TomTom disabled, click a
start on both its zone map and a parent map, accept it, progress its objectives,
and turn it in. Repeat with TomTom selected. Check changing provider, manually
replacing a Blizzard pin, abandoning a selected quest, and reloading the saved
provider setting. Stacked start markers select their first quest.

## Quest tracker links

`QuestLinks.lua` appends **Copy Wowhead URL** to `MENU_QUEST_OBJECTIVE_TRACKER`.
Forever's menu does not supply quest context, so secure post-hooks on the tracker
header enter/leave methods identify the hovered block. The menu action captures
its quest ID before the block can be recycled. This supports mouse right-clicks
on Blizzard's quest titles; gamepad menus without a hovered header are unchanged.

The menu tag, hover methods, owner, and popup edit box contract were checked
against the [Forever Blizzard UI source at 9465cb2](https://github.com/Gethe/wow-ui-source/tree/9465cb273b5513495d8ecc12fbb19930dd6b8957),
including `Blizzard_QuestObjectiveTracker.lua`, `Blizzard_ObjectiveTrackerModule.lua`,
`Blizzard_StaticPopup/StaticPopup.lua`, and `Blizzard_StaticPopup_Game/GameDialog.lua`.
Runtime tests cover URL selection, invalid IDs, delayed initialization, menu scope,
and capturing the selected quest independently of later hover changes.

In game, right-click two different tracked quest titles and copy each URL. Confirm
the Forever quest IDs, existing tracking/details/share/abandon actions, Escape
closing the copy dialog, and behavior after `/reload`. Combat and taint behavior
require client verification.
