package foreverupdate

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunPrintsConfiguredURLAndParsedBuild(t *testing.T) {
	var output bytes.Buffer
	if err := Run([]string{"--print-url"}, &output); err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(output.String()) != VersionsURL {
		t.Fatalf("URL output %q", output.String())
	}
	feed := filepath.Join(t.TempDir(), "versions")
	if err := os.WriteFile(feed, []byte("Region|BuildId|VersionsName\nus|69913|1.60.1.69913\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	output.Reset()
	if err := Run([]string{"--versions-file", feed, "--print-game-build"}, &output); err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(output.String()) != "1.60.1.69913" {
		t.Fatalf("build output %q", output.String())
	}
}

func TestParseVersionsAndInterface(t *testing.T) {
	feed := "Region!US|BuildId!US|VersionsName!US\n## seqn!US\nus|69913|1.60.1.69913\neu|69914|1.60.1.69914\n"
	build, err := ParseVersions(feed, "us")
	if err != nil {
		t.Fatal(err)
	}
	if build.Interface != 16001 || build.BuildID != 69913 || build.Version != "1.60.1.69913" {
		t.Fatalf("unexpected build: %#v", build)
	}
	if _, err := InterfaceFromVersion("bad"); err == nil {
		t.Fatal("invalid version accepted")
	}
}

func TestParseVersionsRejectsMalformedRows(t *testing.T) {
	for _, feed := range []string{
		"",
		"Region|BuildId\nus|1",
		"Region|BuildId|VersionsName\nus|not-a-number|1.60.1.1",
		"Region|BuildId|VersionsName\nus|1|invalid",
		"Region|BuildId|VersionsName\neu|1|1.60.1.1",
	} {
		if _, err := ParseVersions(feed, "us"); err == nil {
			t.Errorf("ParseVersions(%q) unexpectedly succeeded", feed)
		}
	}
}

func TestPrepareUpdateWritesCompatibilityRelease(t *testing.T) {
	root := t.TempDir()
	write := func(name, contents string) {
		t.Helper()
		if err := os.WriteFile(filepath.Join(root, name), []byte(contents), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("ForeverQuestPins.toc", "## Interface: 16000\n## Version: @project-version@\n")
	write("VERSION", "1.2.3\n")
	write("CHANGELOG.md", "# Changelog\n\n## 1.2.3 - previous\n")
	write("RELEASE_NOTES.md", "old\n")
	result, err := Prepare(root, GameBuild{Version: "1.60.1.69913", BuildID: 69913, Interface: 16001}, "2026-05-06", false)
	if err != nil {
		t.Fatal(err)
	}
	if !result.Changed || result.AddonVersion != "1.2.4" {
		t.Fatalf("unexpected result: %#v", result)
	}
	toc, err := os.ReadFile(filepath.Join(root, "ForeverQuestPins.toc"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(toc), "## Interface: 16001") {
		t.Fatalf("TOC not updated: %s", toc)
	}
	notes, err := os.ReadFile(filepath.Join(root, "RELEASE_NOTES.md"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(notes), "## 1.2.4 - 2026-05-06") {
		t.Fatalf("release notes not updated: %s", notes)
	}
	news, err := os.ReadFile(filepath.Join(root, "WhatsNew.lua"))
	if err != nil || !strings.Contains(string(news), "1.60.1.69913") {
		t.Fatalf("in-game release notes not updated: %s, %v", news, err)
	}
}

func TestPrepareUpdateIgnoresSupportedInterfaceAndRejectsDowngrade(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "ForeverQuestPins.toc"), []byte("## Interface: 16001, 16002\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	unchanged, err := Prepare(root, GameBuild{Interface: 16002}, "", false)
	if err != nil || unchanged.Changed {
		t.Fatalf("supported interface result = %#v, %v", unchanged, err)
	}
	if _, err := Prepare(root, GameBuild{Interface: 16000}, "", false); err == nil {
		t.Fatal("downgrade accepted")
	}
}

func TestPrepareDryRunLeavesAllReleaseFilesUnchanged(t *testing.T) {
	root := t.TempDir()
	files := map[string]string{
		"ForeverQuestPins.toc": "## Interface: 16000\n## Version: @project-version@\n",
		"VERSION":              "1.2.3\n",
		"CHANGELOG.md":         "# Changelog\n\n## 1.2.3 - old\n",
		"RELEASE_NOTES.md":     "old notes\n",
		"WhatsNew.lua":         "old news\n",
	}
	for name, content := range files {
		if err := os.WriteFile(filepath.Join(root, name), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	result, err := Prepare(root, GameBuild{Version: "1.60.1.69913", Interface: 16001}, "2026-09-23", true)
	if err != nil || !result.Changed || result.AddonVersion != "1.2.4" {
		t.Fatalf("dry-run result = %#v, %v", result, err)
	}
	for name, want := range files {
		got, err := os.ReadFile(filepath.Join(root, name))
		if err != nil || string(got) != want {
			t.Errorf("dry run changed %s: %q, %v", name, got, err)
		}
	}
}
