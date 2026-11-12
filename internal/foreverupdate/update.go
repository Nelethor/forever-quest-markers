package foreverupdate

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/TylerAkins/forever-quest-markers/internal/release"
)

const VersionsURL = "https://us.version.battle.net/v2/products/wow_classic_beta/versions"

var (
	gameVersionPattern = regexp.MustCompile(`^(\d+)\.(\d+)\.(\d+)\.(\d+)$`)
	interfacePattern   = regexp.MustCompile(`(?m)^## Interface:\s*(.+)$`)
)

type GameBuild struct {
	Version   string
	BuildID   int
	Interface int
}

type UpdateResult struct {
	Changed      bool
	GameBuild    GameBuild
	AddonVersion string
}

func InterfaceFromVersion(version string) (int, error) {
	parts := gameVersionPattern.FindStringSubmatch(version)
	if parts == nil {
		return 0, fmt.Errorf("invalid WoW Forever game version: %s", version)
	}
	major, _ := strconv.Atoi(parts[1])
	minor, _ := strconv.Atoi(parts[2])
	patch, _ := strconv.Atoi(parts[3])
	return major*10000 + minor*100 + patch, nil
}

func ParseVersions(text, region string) (GameBuild, error) {
	lines := strings.Split(text, "\n")
	var headers []string
	var headerIndexes map[string]int
	headerLine := -1
	for lineIndex, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		headerFields := strings.Split(line, "|")
		headers = make([]string, len(headerFields))
		headerIndexes = make(map[string]int, len(headerFields))
		for i, field := range headerFields {
			name := strings.SplitN(field, "!", 2)[0]
			headers[i] = name
			headerIndexes[name] = i
		}
		headerLine = lineIndex
		break
	}
	if len(headers) == 0 {
		return GameBuild{}, errors.New("Blizzard version feed is empty")
	}
	for _, required := range []string{"Region", "BuildId", "VersionsName"} {
		if _, ok := headerIndexes[required]; !ok {
			return GameBuild{}, errors.New("Blizzard version feed is missing required columns")
		}
	}
	for _, line := range lines[headerLine+1:] {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "##") {
			continue
		}
		values := strings.Split(line, "|")
		if len(values) != len(headers) {
			return GameBuild{}, errors.New("Blizzard version feed contains a malformed row")
		}
		if values[headerIndexes["Region"]] != region {
			continue
		}
		buildID, err := strconv.Atoi(values[headerIndexes["BuildId"]])
		if err != nil {
			return GameBuild{}, errors.New("Blizzard build ID is not numeric")
		}
		version := values[headerIndexes["VersionsName"]]
		interfaceID, err := InterfaceFromVersion(version)
		if err != nil {
			return GameBuild{}, err
		}
		return GameBuild{Version: version, BuildID: buildID, Interface: interfaceID}, nil
	}
	return GameBuild{}, fmt.Errorf("Blizzard version feed has no %q region", region)
}

func CurrentInterfaces(toc string) ([]int, error) {
	match := interfacePattern.FindStringSubmatch(toc)
	if match == nil {
		return nil, errors.New("TOC is missing an Interface line")
	}
	values := strings.Split(match[1], ",")
	interfaces := make([]int, 0, len(values))
	for _, value := range values {
		parsed, err := strconv.Atoi(strings.TrimSpace(value))
		if err != nil {
			return nil, errors.New("TOC Interface values must be numeric")
		}
		interfaces = append(interfaces, parsed)
	}
	if len(interfaces) == 0 {
		return nil, errors.New("TOC has no Interface values")
	}
	return interfaces, nil
}

func Prepare(root string, build GameBuild, releaseDate string, dryRun bool) (UpdateResult, error) {
	tocPath := filepath.Join(root, "ForeverQuestPins.toc")
	tocBytes, err := os.ReadFile(tocPath)
	if err != nil {
		return UpdateResult{}, err
	}
	interfaces, err := CurrentInterfaces(string(tocBytes))
	if err != nil {
		return UpdateResult{}, err
	}
	max := interfaces[0]
	for _, value := range interfaces[1:] {
		if value > max {
			max = value
		}
	}
	if contains(interfaces, build.Interface) {
		return UpdateResult{GameBuild: build}, nil
	}
	if build.Interface < max {
		return UpdateResult{}, fmt.Errorf("refusing to downgrade Interface %d to %d", max, build.Interface)
	}
	versionPath := filepath.Join(root, "VERSION")
	versionBytes, err := os.ReadFile(versionPath)
	if err != nil {
		return UpdateResult{}, err
	}
	current, err := release.ParseVersion(string(versionBytes))
	if err != nil {
		return UpdateResult{}, err
	}
	next := current.NextPatch()
	updatedTOC := interfacePattern.ReplaceAllString(string(tocBytes), fmt.Sprintf("## Interface: %d", build.Interface))
	if releaseDate == "" {
		releaseDate = time.Now().UTC().Format("2006-01-02")
	}
	entry := fmt.Sprintf("## %s - %s\n\n- Update WoW Forever compatibility for game build %s (Interface %d).\n", next, releaseDate, build.Version, build.Interface)
	changelogPath := filepath.Join(root, "CHANGELOG.md")
	changelogBytes, err := os.ReadFile(changelogPath)
	if err != nil {
		return UpdateResult{}, err
	}
	updatedChangelog, err := release.ReplaceOrInsertChangelogEntry(string(changelogBytes), next, entry)
	if err != nil {
		return UpdateResult{}, err
	}
	notes, err := release.ReleaseNotes(entry, next)
	if err != nil {
		return UpdateResult{}, err
	}
	if !dryRun {
		if err := os.WriteFile(tocPath, []byte(updatedTOC), 0o644); err != nil {
			return UpdateResult{}, err
		}
		if err := os.WriteFile(versionPath, []byte(next.String()+"\n"), 0o644); err != nil {
			return UpdateResult{}, err
		}
		if err := os.WriteFile(changelogPath, []byte(updatedChangelog), 0o644); err != nil {
			return UpdateResult{}, err
		}
		if err := release.GenerateNews(root); err != nil {
			return UpdateResult{}, err
		}
		if err := os.WriteFile(filepath.Join(root, "RELEASE_NOTES.md"), []byte(notes), 0o644); err != nil {
			return UpdateResult{}, err
		}
	}
	return UpdateResult{Changed: true, GameBuild: build, AddonVersion: next.String()}, nil
}

func contains(values []int, sought int) bool {
	for _, value := range values {
		if value == sought {
			return true
		}
	}
	return false
}

func fetchVersions() (string, error) {
	client := http.Client{Timeout: 30 * time.Second}
	response, err := client.Get(VersionsURL)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return "", fmt.Errorf("Blizzard version feed returned HTTP %s", response.Status)
	}
	body, err := io.ReadAll(response.Body)
	return string(body), err
}

func Run(args []string, stdout io.Writer) error {
	flags := flag.NewFlagSet("update-interface", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	versionsFile := flags.String("versions-file", "", "read a saved version feed")
	root := flags.String("root", ".", "repository root")
	date := flags.String("date", "", "release date")
	dryRun := flags.Bool("dry-run", false, "validate without writing files")
	printURL := flags.Bool("print-url", false, "print the configured Blizzard feed URL")
	printGameBuild := flags.Bool("print-game-build", false, "print the parsed game build instead of preparing a release")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *printURL {
		_, err := fmt.Fprintln(stdout, VersionsURL)
		return err
	}
	var feed string
	var err error
	if *versionsFile != "" {
		data, readErr := os.ReadFile(*versionsFile)
		err = readErr
		feed = string(data)
	} else {
		feed, err = fetchVersions()
	}
	if err != nil {
		return err
	}
	build, err := ParseVersions(feed, "us")
	if err != nil {
		return err
	}
	if *printGameBuild {
		_, err := fmt.Fprintln(stdout, build.Version)
		return err
	}
	result, err := Prepare(*root, build, *date, *dryRun)
	if err != nil {
		return err
	}
	if result.Changed {
		action := "Prepared"
		if *dryRun {
			action = "Would prepare"
		}
		_, err = fmt.Fprintf(stdout, "%s v%s for game build %s (Interface %d)\n", action, result.AddonVersion, build.Version, build.Interface)
		return err
	}
	_, err = fmt.Fprintf(stdout, "Interface %d is already supported; no update needed\n", build.Interface)
	return err
}
