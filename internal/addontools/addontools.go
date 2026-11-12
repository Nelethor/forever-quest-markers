package addontools

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

var rootFiles = []string{
	"ATTRIBUTION.md", "AutoQuests.lua", "CHANGELOG.md", "Config.lua", "Core.lua",
	"Eligibility.lua", "Events.lua", "HiddenQuests.lua", "NPCTooltips.lua", "QuestLinks.lua",
	"ForeverQuestPins.toc", "LICENSE", "Localization.lua", "MapPins.lua", "MapPins.xml", "README.md",
	"RELEASE_NOTES.md", "Setup.lua", "WarEffort.lua", "WhatsNew.lua", "Waypoints.lua",
}

var directories = []string{"Database", "Media"}
var ignoredNames = map[string]bool{"build_report.json": true, ".DS_Store": true, "Thumbs.db": true, "__pycache__": true}

func ProjectVersion(root string) string {
	command := exec.Command("git", "describe", "--tags", "--always", "--dirty")
	command.Dir = root
	output, err := command.Output()
	if err != nil || strings.TrimSpace(string(output)) == "" {
		return "local"
	}
	return strings.TrimSpace(string(output))
}

func IterFiles(root string) ([]string, error) {
	files := make([]string, 0, len(rootFiles))
	for _, name := range rootFiles {
		path := filepath.Join(root, name)
		if _, err := os.Stat(path); err != nil {
			return nil, err
		}
		files = append(files, path)
	}
	for _, directory := range directories {
		base := filepath.Join(root, directory)
		err := filepath.WalkDir(base, func(path string, entry os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if entry.IsDir() && ignoredNames[entry.Name()] {
				return filepath.SkipDir
			}
			if entry.IsDir() {
				return nil
			}
			if ignoredNames[entry.Name()] {
				return nil
			}
			files = append(files, path)
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	sort.Strings(files)
	return files, nil
}

func Compile(root, outputDir string, dryRun bool) ([]string, error) {
	files, err := IterFiles(root)
	if err != nil {
		return nil, err
	}
	outputs := make([]string, len(files))
	for index, source := range files {
		relative, err := filepath.Rel(root, source)
		if err != nil {
			return nil, err
		}
		outputs[index] = filepath.Join(outputDir, relative)
	}
	if dryRun {
		return outputs, nil
	}
	if err := os.RemoveAll(outputDir); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(outputDir, 0o755); err != nil {
		return nil, err
	}
	for index, source := range files {
		if err := copyFile(source, outputs[index]); err != nil {
			return nil, err
		}
	}
	tocPath := filepath.Join(outputDir, "ForeverQuestPins.toc")
	toc, err := os.ReadFile(tocPath)
	if err != nil {
		return nil, err
	}
	return outputs, os.WriteFile(tocPath, []byte(strings.ReplaceAll(string(toc), "@project-version@", ProjectVersion(root))), 0o644)
}

func copyFile(source, destination string) error {
	data, err := os.ReadFile(source)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
		return err
	}
	info, err := os.Stat(source)
	if err != nil {
		return err
	}
	return os.WriteFile(destination, data, info.Mode().Perm())
}

func Repair(addon, saved string, apply bool, output io.Writer) error {
	addon, err := filepath.Abs(addon)
	if err != nil {
		return err
	}
	addon, err = filepath.EvalSymlinks(addon)
	if err != nil {
		return err
	}
	saved, err = filepath.Abs(saved)
	if err != nil {
		return err
	}
	saved, err = filepath.EvalSymlinks(saved)
	if err != nil {
		return err
	}
	if filepath.Base(addon) != "ForeverQuestPins" || filepath.Base(saved) != "ForeverQuestPins.lua" {
		return errors.New("expected ForeverQuestPins addon and SavedVariables paths")
	}
	tocPath := filepath.Join(addon, "ForeverQuestPins.toc")
	tocBytes, err := os.ReadFile(tocPath)
	if err != nil {
		return err
	}
	link := filepath.Join(addon, "LocalSavedVariables")
	entry := `LocalSavedVariables\ForeverQuestPins.lua`
	if info, err := os.Lstat(link); err == nil {
		if info.Mode()&os.ModeSymlink == 0 {
			return errors.New("refusing to replace an existing LocalSavedVariables directory")
		}
		resolved, err := filepath.EvalSymlinks(link)
		if err != nil || resolved != filepath.Dir(saved) {
			return errors.New("existing settings link points to another account")
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	lines := strings.Split(strings.TrimSuffix(string(tocBytes), "\n"), "\n")
	found := false
	for _, line := range lines {
		if line == entry {
			found = true
			break
		}
	}
	if !found {
		index := -1
		for i, line := range lines {
			if strings.TrimSpace(line) != "" && !strings.HasPrefix(line, "#") {
				index = i
				break
			}
		}
		if index < 0 {
			return errors.New("TOC has no file entries")
		}
		lines = append(lines[:index], append([]string{entry}, lines[index:]...)...)
	}
	if _, err := fmt.Fprintf(output, "Link %s to %s; load live account settings before addon code\n", link, filepath.Dir(saved)); err != nil {
		return err
	}
	if !apply {
		return nil
	}
	backup := strings.TrimSuffix(tocPath, filepath.Ext(tocPath)) + ".toc.before-settings-repair"
	if _, err := os.Stat(backup); os.IsNotExist(err) {
		if err := copyFile(tocPath, backup); err != nil {
			return err
		}
	} else if err != nil {
		return err
	}
	if _, err := os.Lstat(link); os.IsNotExist(err) {
		if err := os.Symlink(filepath.Dir(saved), link); err != nil {
			return err
		}
	} else if err != nil {
		return err
	}
	return os.WriteFile(tocPath, []byte(strings.Join(lines, "\n")+"\n"), 0o644)
}

func RunCompile(args []string, stdout io.Writer) error {
	flags := flag.NewFlagSet("compile-addon", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	root := flags.String("root", ".", "repository root")
	dryRun := flags.Bool("dry-run", false, "list files without changing the output")
	if err := flags.Parse(args); err != nil {
		return err
	}
	output := filepath.Join(*root, ".compiled", "ForeverQuestPins")
	files, err := Compile(*root, output, *dryRun)
	if err != nil {
		return err
	}
	if *dryRun {
		for _, path := range files {
			relative, err := filepath.Rel(*root, path)
			if err != nil {
				return err
			}
			if _, err := fmt.Fprintln(stdout, relative); err != nil {
				return err
			}
		}
		return nil
	}
	_, err = fmt.Fprintf(stdout, "Built %d files in %s\n", len(files), output)
	return err
}

func RunRepair(args []string, stdout io.Writer) error {
	flags := flag.NewFlagSet("repair-settings", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	addon := flags.String("addon", "", "installed addon directory")
	saved := flags.String("saved", "", "account SavedVariables file")
	apply := flags.Bool("apply", false, "apply the change with WoW fully closed")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *addon == "" || *saved == "" {
		return errors.New("--addon and --saved are required")
	}
	return Repair(*addon, *saved, *apply, stdout)
}

const iconSize = 64
const iconSamples = 4

type pixel struct{ b, g, r, a byte }

func sdfCircle(px, py, cx, cy, radius float64) float64 { return math.Hypot(px-cx, py-cy) - radius }

func sdfCapsule(px, py, ax, ay, bx, by, radius float64) float64 {
	dx, dy := bx-ax, by-ay
	length2 := dx*dx + dy*dy
	if length2 <= 0 {
		return sdfCircle(px, py, ax, ay, radius)
	}
	t := ((px-ax)*dx + (py-ay)*dy) / length2
	t = math.Max(0, math.Min(1, t))
	return math.Hypot(px-(ax+dx*t), py-(ay+dy*t)) - radius
}

func shapeSDF(px, py float64) float64 {
	return math.Min(sdfCapsule(px, py, .5, .16, .5, .58, .105), sdfCircle(px, py, .5, .8, .105))
}

func spawnRingPixel(px, py float64) pixel {
	distance := math.Abs(math.Hypot(px-.5, py-.5)-.33) - .1
	if distance > .01 {
		return pixel{}
	}
	if distance > -.01 {
		alpha := byte(math.Max(0, math.Min(1, 1-(distance+.01)/.02)) * 255)
		return pixel{8, 16, 24, alpha}
	}
	if distance > -.035 {
		return pixel{8, 16, 24, 255}
	}
	return pixel{64, 210, 255, 255}
}

func samplePixel(px, py float64, variant string) pixel {
	if variant == "spawn" {
		return spawnRingPixel(px, py)
	}
	distance, outline := shapeSDF(px, py), .055
	if distance > outline {
		return pixel{}
	}
	if distance > 0 {
		alpha := byte(math.Max(0, math.Min(1, 1-distance/outline)) * 255)
		return pixel{8, 16, 24, alpha}
	}
	highlight := math.Max(0, math.Min(1, (.55-px)*.7+(.45-py)*.5))
	var r, g, b float64
	switch variant {
	case "repeatable":
		r, g, b = 35+45*highlight, 145+55*highlight, 235+20*highlight
	case "attunement":
		r, g, b = 245+10*highlight, 65+60*highlight, 18+30*highlight
	default:
		r, g, b = 255, 196+44*highlight, 16+40*highlight
	}
	inner := math.Max(0, math.Min(1, -distance/.04))
	outlineMix := 1 - inner
	r = r*inner + 24*outlineMix
	g = g*inner + 16*outlineMix
	b = b*inner + 8*outlineMix
	return pixel{byte(b), byte(g), byte(r), 255}
}

func WriteTGA(path, variant string) error {
	if variant != "normal" && variant != "repeatable" && variant != "attunement" && variant != "spawn" {
		return fmt.Errorf("unknown quest icon variant: %s", variant)
	}
	pixels := make([]pixel, iconSize*iconSize)
	for y := 0; y < iconSize; y++ {
		for x := 0; x < iconSize; x++ {
			var b, g, r, a int
			for sy := 0; sy < iconSamples; sy++ {
				for sx := 0; sx < iconSamples; sx++ {
					sample := samplePixel((float64(x)+(float64(sx)+.5)/iconSamples)/iconSize, (float64(y)+(float64(sy)+.5)/iconSamples)/iconSize, variant)
					b += int(sample.b)
					g += int(sample.g)
					r += int(sample.r)
					a += int(sample.a)
				}
			}
			count := iconSamples * iconSamples
			pixels[y*iconSize+x] = pixel{byte(b / count), byte(g / count), byte(r / count), byte(a / count)}
		}
	}
	header := make([]byte, 18)
	header[2] = 2
	header[12], header[14], header[16], header[17] = iconSize, iconSize, 32, 0x08
	body := make([]byte, 0, iconSize*iconSize*4)
	for y := iconSize - 1; y >= 0; y-- {
		for x := 0; x < iconSize; x++ {
			p := pixels[y*iconSize+x]
			body = append(body, p.b, p.g, p.r, p.a)
		}
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, append(header, body...), 0o644)
}

func RunGenerateIcons(args []string, stdout io.Writer) error {
	flags := flag.NewFlagSet("generate-icon", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	root := flags.String("root", ".", "repository root")
	if err := flags.Parse(args); err != nil {
		return err
	}
	paths := []struct{ name, variant string }{{"QuestAvailable.tga", "normal"}, {"QuestRepeatable.tga", "repeatable"}, {"QuestAttunement.tga", "attunement"}}
	for _, item := range paths {
		path := filepath.Join(*root, "Media", item.name)
		if err := WriteTGA(path, item.variant); err != nil {
			return err
		}
		if _, err := fmt.Fprintf(stdout, "Wrote %s\n", path); err != nil {
			return err
		}
	}
	return nil
}
