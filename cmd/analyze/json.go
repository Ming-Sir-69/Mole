package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"sync"
	"sync/atomic"
	"time"
)

// The JSON output follows the macOS CLI's `mo analyze --json` contract field
// for field, so one agent skill can read both.
type jsonOutput struct {
	ScanStatus scanState       `json:"scan_status"`
	Path       string          `json:"path"`
	Overview   bool            `json:"overview"`
	Entries    []jsonEntry     `json:"entries"`
	LargeFiles []jsonFileEntry `json:"large_files,omitempty"`
	TotalSize  int64           `json:"total_size"`
	TotalFiles int64           `json:"total_files,omitempty"`
}

type jsonEntry struct {
	ScanStatus scanState `json:"scan_status"`
	Name       string    `json:"name"`
	Path       string    `json:"path"`
	Size       int64     `json:"size"`
	IsDir      bool      `json:"is_dir"`
	Insight    bool      `json:"insight,omitempty"`
	Cleanable  bool      `json:"cleanable,omitempty"`
	LastAccess string    `json:"last_access,omitempty"`
}

type jsonFileEntry struct {
	Name string `json:"name"`
	Path string `json:"path"`
	Size int64  `json:"size"`
}

// MarshalText gives the JSON boundary the same typed coverage state the TUI
// uses, and refuses a value outside the three known states.
func (s scanState) MarshalText() ([]byte, error) {
	if s > scanUnavailable {
		return nil, fmt.Errorf("invalid scan state: %d", s)
	}
	return []byte(s.String()), nil
}

// runJSONMode scans once and writes one indented JSON object. It is read-only:
// it never opens the TUI, deletes, or writes the operations log.
func runJSONMode(w io.Writer, path string, isOverview bool) error {
	var result jsonOutput
	if isOverview {
		result = performOverviewScanForJSON()
	} else {
		var err error
		result, err = performDirectoryScanForJSON(path)
		if err != nil {
			return fmt.Errorf("failed to scan directory: %w", err)
		}
	}

	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(result); err != nil {
		return fmt.Errorf("failed to encode JSON: %w", err)
	}
	return nil
}

func performDirectoryScanForJSON(path string) (jsonOutput, error) {
	var filesScanned, dirsScanned, bytesScanned int64
	currentPath := &atomic.Value{}
	currentPath.Store("")

	result, err := scanPathConcurrentAllEntries(context.Background(), path, &filesScanned, &dirsScanned, &bytesScanned, currentPath)
	if err != nil {
		return jsonOutput{}, err
	}

	return jsonOutput{
		ScanStatus: result.State,
		Path:       path,
		Overview:   false,
		Entries:    jsonEntriesFromDirEntries(result.Entries, false, nil),
		LargeFiles: jsonFileEntriesFromFileEntries(result.LargeFiles),
		TotalSize:  result.TotalSize,
		TotalFiles: result.TotalFiles,
	}, nil
}

// performOverviewScanForJSON measures the rows the overview screen shows:
// Home, User AppData, Program Files, ProgramData, the insight folders and the
// fixed drives. Windows has no single root above them, so path is empty.
func performOverviewScanForJSON() jsonOutput {
	return performOverviewScanForJSONWithEntries(createInsightEntries(), createOverviewEntries(), measureInsightSize)
}

func performOverviewScanForJSONWithEntries(insightEntries, overviewEntries []dirEntry, measure func(context.Context, string) (int64, error)) jsonOutput {
	insightPaths := make(map[string]bool, len(insightEntries))
	for _, insight := range insightEntries {
		insightPaths[insight.Path] = true
	}

	var totalSize int64
	entries := make([]dirEntry, 0, len(overviewEntries))
	for _, entry := range measureOverviewEntriesForJSON(overviewEntries, measure) {
		// Match the TUI: omit rows that were measured completely and are empty.
		if entry.Size == 0 && entry.State == scanComplete {
			continue
		}
		totalSize += max(entry.Size, 0)
		entries = append(entries, entry)
	}

	sortDirEntriesBySize(entries)

	return jsonOutput{
		ScanStatus: entryScanState(entries),
		Path:       "",
		Overview:   true,
		Entries:    jsonEntriesFromDirEntries(entries, true, insightPaths),
		TotalSize:  totalSize,
	}
}

// measureOverviewEntriesForJSON measures every row with the TUI's own
// measurement and its timeouts, at most maxConcurrentOverview at a time. A
// failed or timed-out measurement keeps the bytes it reached and is marked
// partial, or unavailable when it reached none; it is never a complete zero.
func measureOverviewEntriesForJSON(overviewEntries []dirEntry, measure func(context.Context, string) (int64, error)) []dirEntry {
	measured := make([]dirEntry, len(overviewEntries))
	sem := make(chan struct{}, maxConcurrentOverview)

	var wg sync.WaitGroup
	for index, item := range overviewEntries {
		wg.Add(1)
		go func(index int, item dirEntry) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			size, err := measure(context.Background(), item.Path)
			item.Size = size
			item.State = measurementState(size, err)
			measured[index] = item
		}(index, item)
	}
	wg.Wait()
	return measured
}

func jsonEntriesFromDirEntries(entries []dirEntry, isOverview bool, insightPaths map[string]bool) []jsonEntry {
	output := make([]jsonEntry, 0, len(entries))
	for _, entry := range entries {
		item := jsonEntry{
			ScanStatus: entry.State,
			Name:       entry.Name,
			Path:       entry.Path,
			Size:       entry.Size,
			IsDir:      entry.IsDir,
			Cleanable:  entry.IsDir && isCleanableDir(entry.Path),
		}
		if isOverview {
			item.Insight = insightPaths[entry.Path]
		}
		if !entry.LastAccess.IsZero() {
			item.LastAccess = entry.LastAccess.UTC().Format(time.RFC3339)
		}
		output = append(output, item)
	}
	return output
}

func jsonFileEntriesFromFileEntries(files []fileEntry) []jsonFileEntry {
	output := make([]jsonFileEntry, 0, len(files))
	for _, f := range files {
		output = append(output, jsonFileEntry(f))
	}
	return output
}
