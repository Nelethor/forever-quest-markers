package main

import (
	"fmt"
	"os"

	"github.com/TylerAkins/forever-quest-markers/internal/addontools"
	"github.com/TylerAkins/forever-quest-markers/internal/foreverupdate"
	"github.com/TylerAkins/forever-quest-markers/internal/questdb"
	"github.com/TylerAkins/forever-quest-markers/internal/release"
)

func main() {
	if len(os.Args) < 2 {
		usage()
	}

	var err error
	switch os.Args[1] {
	case "generate-news":
		err = release.GenerateNews(".")
	case "build-db":
		err = questdb.RunBuild(os.Args[2:], os.Stdout, os.Stderr)
	case "release":
		err = release.Run(os.Args[2:], os.Stdout)
	case "update-interface":
		err = foreverupdate.Run(os.Args[2:], os.Stdout)
	case "compile-addon":
		err = addontools.RunCompile(os.Args[2:], os.Stdout)
	case "repair-settings":
		err = addontools.RunRepair(os.Args[2:], os.Stdout)
	case "generate-icon":
		err = addontools.RunGenerateIcons(os.Args[2:], os.Stdout)
	default:
		usage()
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: fqp <release|generate-news|build-db|update-interface|compile-addon|repair-settings|generate-icon> [options]")
	os.Exit(2)
}
