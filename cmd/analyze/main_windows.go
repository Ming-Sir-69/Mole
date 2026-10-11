//go:build windows

package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"

	tea "github.com/charmbracelet/bubbletea"
)

func main() {
	pathFlag, code, keepGoing := parseArgs(os.Args[1:], os.Stdout, os.Stderr)
	if !keepGoing {
		os.Exit(code)
	}

	envPath := os.Getenv("MO_ANALYZE_PATH")
	if envPath == "" {
		envPath = pathFlag
	}
	target, isOverview, err := resolveScanTarget(envPath, flag.Args())
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	p := tea.NewProgram(newModel(target, isOverview), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "analyzer error: %v\n", err)
		os.Exit(1)
	}
}

// parseArgs applies Mole's CLI conventions to the flag package: help goes to
// stdout and exits 0, and an unknown flag goes to stderr and exits 1. It
// returns the legacy -path value, the exit code and whether main should run.
func parseArgs(args []string, stdout, stderr io.Writer) (string, int, bool) {
	flag.CommandLine.Init("mo analyze", flag.ContinueOnError)
	flag.CommandLine.SetOutput(io.Discard)
	flag.CommandLine.Usage = func() {}
	pathFlag := flag.String("path", "", "Path to analyze")

	err := flag.CommandLine.Parse(args)
	switch {
	case errors.Is(err, flag.ErrHelp):
		_, _ = fmt.Fprint(stdout, usageText)
		return "", 0, false
	case err != nil:
		_, _ = fmt.Fprintln(stderr, err)
		_, _ = fmt.Fprintln(stderr, "Use 'mo analyze --help' for usage information")
		return "", 1, false
	}
	return *pathFlag, 0, true
}
