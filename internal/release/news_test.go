package release

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestNewsSkipsDatabaseOnlyReleases(t *testing.T) {
	changelog := "## 1.2.5 - today\n\n- Update the QuestieDB Forever artifact to abc.\n- Ship 123 quests with 456 coordinate pins.\n\n## 1.2.4 - yesterday\n\n- Update the QuestieDB Forever artifact to def.\n- Ship 124 quests with 457 coordinate pins.\n- Add a useful feature.\n"
	got, err := RenderNews(changelog)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, `version = "1.2.4"`) || !strings.Contains(got, "Add a useful feature.") || strings.Contains(got, "QuestieDB") || strings.Contains(got, "coordinate pins") {
		t.Fatalf("unexpected news: %s", got)
	}
}

func TestGeneratedNewsMatchesChangelog(t *testing.T) {
	root := filepath.Join("..", "..")
	changelog, err := os.ReadFile(filepath.Join(root, "CHANGELOG.md"))
	if err != nil {
		t.Fatal(err)
	}
	expected, err := RenderNews(string(changelog))
	if err != nil {
		t.Fatal(err)
	}
	actual, err := os.ReadFile(filepath.Join(root, "WhatsNew.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if string(actual) != expected {
		t.Fatal("WhatsNew.lua is stale; run go run ./cmd/fqp generate-news")
	}
}
