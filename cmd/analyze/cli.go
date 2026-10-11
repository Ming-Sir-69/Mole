package main

import (
	"fmt"
	"os"
	"path/filepath"
)

const usageText = `Usage: mo analyze [PATH]

Explore disk usage. Without PATH, shows an overview of your folders and drives.

Options:
  -h, --help      Show this help message

Examples:
  mo analyze                 Folders and drives overview
  mo analyze ~\Downloads     Scan one directory
  mo analyze D:\             Scan a whole drive
`

// resolveScanTarget decides which scan an invocation asks for: no target means
// the overview, anything else must be an existing path.
func resolveScanTarget(envPath string, args []string) (string, bool, error) {
	target := envPath
	if target == "" && len(args) > 0 {
		target = args[0]
	}
	if target == "" {
		return overviewPath, true, nil
	}

	abs, err := filepath.Abs(target)
	if err != nil {
		return "", false, fmt.Errorf("cannot resolve %q: %v", target, err)
	}
	if _, err := os.Stat(abs); err != nil {
		return "", false, fmt.Errorf("path does not exist: %s", abs)
	}
	return abs, false, nil
}
