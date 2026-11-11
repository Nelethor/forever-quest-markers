package addontools

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCompileCopiesOnlyPackageFilesAndDryRunPreservesOutput(t *testing.T) {
	root, err := filepath.Abs("../..")
	if err != nil {
		t.Fatal(err)
	}
	output := filepath.Join(t.TempDir(), "ForeverQuestPins")
	if err := os.MkdirAll(output, 0o755); err != nil {
		t.Fatal(err)
	}
	stale := filepath.Join(output, "stale.txt")
	if err := os.WriteFile(stale, []byte("keep"), 0o644); err != nil {
		t.Fatal(err)
	}
	listed, err := Compile(root, output, true)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(stale); err != nil {
		t.Fatalf("dry run removed existing file: %v", err)
	}
	if !containsPath(listed, filepath.Join(output, "ForeverQuestPins.toc")) {
		t.Fatal("dry run omitted TOC")
	}
	files, err := Compile(root, output, false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(stale); !os.IsNotExist(err) {
		t.Fatalf("stale file remains: %v", err)
	}
	for _, path := range []string{"MapPins.xml", "Waypoints.lua", "Database/ForeverQuests.lua", "Media/QuestAvailable.tga", "Media/QuestRepeatable.tga", "Media/QuestAttunement.tga", "RELEASE_NOTES.md"} {
		if _, err := os.Stat(filepath.Join(output, path)); err != nil {
			t.Errorf("missing shipped file %s: %v", path, err)
		}
	}
	for _, path := range []string{"VERSION", "Database/build_report.json"} {
		if _, err := os.Stat(filepath.Join(output, path)); !os.IsNotExist(err) {
			t.Errorf("unexpected packaged file %s", path)
		}
	}
	toc, err := os.ReadFile(filepath.Join(output, "ForeverQuestPins.toc"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(toc), "@project-version@") {
		t.Fatal("project version token was not replaced")
	}
	for _, line := range strings.Split(string(toc), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		path := filepath.Join(output, filepath.FromSlash(strings.ReplaceAll(line, `\`, "/")))
		if _, err := os.Stat(path); err != nil {
			t.Errorf("TOC file missing from package %s: %v", line, err)
		}
	}
	if len(files) != len(listed) {
		t.Fatalf("dry-run listed %d files, build copied %d", len(listed), len(files))
	}
}

func containsPath(paths []string, sought string) bool {
	for _, path := range paths {
		if path == sought {
			return true
		}
	}
	return false
}

func TestRepairPreviewsThenLinksWithoutChangingSavedFile(t *testing.T) {
	root := t.TempDir()
	addon := filepath.Join(root, "ForeverQuestPins")
	if err := os.Mkdir(addon, 0o755); err != nil {
		t.Fatal(err)
	}
	saved := filepath.Join(root, "ForeverQuestPins.lua")
	savedContents := "ForeverQuestPinsDB = { autoAccept = true }"
	if err := os.WriteFile(saved, []byte(savedContents), 0o644); err != nil {
		t.Fatal(err)
	}
	tocPath := filepath.Join(addon, "ForeverQuestPins.toc")
	original := "## Title: Forever Quest Pins\nConfig.lua\nCore.lua\n"
	if err := os.WriteFile(tocPath, []byte(original), 0o644); err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	if err := Repair(addon, saved, false, &output); err != nil {
		t.Fatal(err)
	}
	toc, err := os.ReadFile(tocPath)
	if err != nil || string(toc) != original {
		t.Fatalf("preview changed TOC: %q, %v", toc, err)
	}
	if err := Repair(addon, saved, true, &output); err != nil {
		t.Fatal(err)
	}
	patched, err := os.ReadFile(tocPath)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Index(string(patched), "LocalSavedVariables") > strings.Index(string(patched), "Config.lua") {
		t.Fatalf("settings link is after addon code: %s", patched)
	}
	backup, err := os.ReadFile(strings.TrimSuffix(tocPath, filepath.Ext(tocPath)) + ".toc.before-settings-repair")
	if err != nil || string(backup) != original {
		t.Fatalf("backup mismatch: %q, %v", backup, err)
	}
	if err := Repair(addon, saved, true, &output); err != nil {
		t.Fatal(err)
	}
	linkData, err := os.ReadFile(filepath.Join(addon, "LocalSavedVariables", "ForeverQuestPins.lua"))
	if err != nil || string(linkData) != savedContents {
		t.Fatalf("saved data changed or link missing: %q, %v", linkData, err)
	}
}

func TestRepairRejectsForeignLinkAndInvalidPaths(t *testing.T) {
	root := t.TempDir()
	addon := filepath.Join(root, "ForeverQuestPins")
	if err := os.Mkdir(addon, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(addon, "ForeverQuestPins.toc"), []byte("Config.lua\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	saved := filepath.Join(root, "ForeverQuestPins.lua")
	if err := os.WriteFile(saved, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	other := filepath.Join(root, "other")
	if err := os.Mkdir(other, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(other, filepath.Join(addon, "LocalSavedVariables")); err != nil {
		t.Fatal(err)
	}
	if err := Repair(addon, saved, true, &bytes.Buffer{}); err == nil {
		t.Fatal("foreign link was accepted")
	}
	if err := Repair(root, saved, false, &bytes.Buffer{}); err == nil {
		t.Fatal("invalid addon directory was accepted")
	}
}

func TestGeneratedIconsMatchCheckedInTextures(t *testing.T) {
	root, err := filepath.Abs("../..")
	if err != nil {
		t.Fatal(err)
	}
	for _, item := range []struct{ name, variant string }{{"QuestAvailable.tga", "normal"}, {"QuestRepeatable.tga", "repeatable"}, {"QuestAttunement.tga", "attunement"}} {
		generated := filepath.Join(t.TempDir(), item.name)
		if err := WriteTGA(generated, item.variant); err != nil {
			t.Fatal(err)
		}
		want, err := os.ReadFile(filepath.Join(root, "Media", item.name))
		if err != nil {
			t.Fatal(err)
		}
		got, err := os.ReadFile(generated)
		if err != nil {
			t.Fatal(err)
		}
		if len(got) != len(want) || !bytes.Equal(got[:18], want[:18]) {
			t.Errorf("generated %s has a different TGA header or size", item.name)
			continue
		}
		differences := 0
		for index := range got {
			if got[index] != want[index] {
				differences++
				if int(got[index])-int(want[index]) > 1 || int(want[index])-int(got[index]) > 1 {
					t.Errorf("generated %s differs by more than one intensity at byte %d", item.name, index)
					break
				}
			}
		}
		if differences > 200 {
			t.Errorf("generated %s differs at %d bytes, want at most 200", item.name, differences)
		}
	}
}

func TestSpawnRingMatchesCommittedTexture(t *testing.T) {
	path := filepath.Join(t.TempDir(), "SpawnRing.tga")
	if err := WriteTGA(path, "spawn"); err != nil {
		t.Fatal(err)
	}
	generated, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	committed, err := os.ReadFile(filepath.Join("..", "..", "Media", "SpawnRing.tga"))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(generated, committed) {
		t.Fatal("Media/SpawnRing.tga is out of date with WriteTGA(\"spawn\")")
	}
}
