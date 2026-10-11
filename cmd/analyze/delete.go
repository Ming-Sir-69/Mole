package main

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"sync/atomic"

	tea "github.com/charmbracelet/bubbletea"
)

// recycleItem moves one absolute path to the Recycle Bin. It is a variable so
// tests can observe deletions without touching the real Recycle Bin.
var recycleItem = moveToRecycleBinNative

func deletePathCmd(path string, counter *int64) tea.Cmd {
	return func() tea.Msg {
		count, err := recyclePathWithProgress(path, counter)
		return deleteProgressMsg{
			done:  true,
			err:   err,
			count: count,
			path:  path,
		}
	}
}

// deleteMultiplePathsCmd moves paths to the Recycle Bin and aggregates results.
func deleteMultiplePathsCmd(paths []string, counter *int64) tea.Cmd {
	return func() tea.Msg {
		var totalCount int64
		var errors []string
		var removedPaths []string

		// Process deeper paths first to avoid parent/child conflicts.
		pathsToDelete := append([]string(nil), paths...)
		sort.Slice(pathsToDelete, func(i, j int) bool {
			return strings.Count(pathsToDelete[i], string(filepath.Separator)) > strings.Count(pathsToDelete[j], string(filepath.Separator))
		})

		for _, path := range pathsToDelete {
			count, err := recyclePathWithProgress(path, counter)
			totalCount += count
			if err != nil {
				if os.IsNotExist(err) {
					removedPaths = append(removedPaths, path)
					continue
				}
				errors = append(errors, err.Error())
				continue
			}
			removedPaths = append(removedPaths, path)
		}

		var resultErr error
		if len(errors) > 0 {
			resultErr = &multiDeleteError{errors: errors}
		}

		return deleteProgressMsg{
			done:         true,
			err:          resultErr,
			count:        totalCount,
			path:         "",
			removedPaths: removedPaths,
		}
	}
}

// multiDeleteError holds multiple deletion errors.
type multiDeleteError struct {
	errors []string
}

func (e *multiDeleteError) Error() string {
	if len(e.errors) == 1 {
		return e.errors[0]
	}
	return strings.Join(e.errors[:min(3, len(e.errors))], "; ")
}

// recyclePathWithProgress moves one selected path to the Recycle Bin as a unit
// and reports completion.
func recyclePathWithProgress(root string, counter *int64) (int64, error) {
	if _, err := os.Lstat(root); err != nil {
		return 0, err
	}
	if err := moveToRecycleBin(root); err != nil {
		return 0, err
	}
	if counter != nil {
		atomic.AddInt64(counter, 1)
	}
	return 1, nil
}

// moveToRecycleBin validates path and moves it to the Recycle Bin. It never
// deletes permanently.
func moveToRecycleBin(path string) error {
	// Validate raw input before Abs resolves ".." components away.
	if err := validateDeleteTarget(path); err != nil {
		return err
	}
	absPath, err := filepath.Abs(path)
	if err != nil {
		return fmt.Errorf("failed to resolve path: %w", err)
	}
	if err := validateDeleteTarget(absPath); err != nil {
		return err
	}
	return recycleItem(absPath)
}

// validateDeleteTarget refuses protected paths, both as spelled and with the
// parent's links resolved, so a junction elsewhere cannot reach a protected
// tree. The leaf itself is not resolved: removing a link removes only the link.
func validateDeleteTarget(path string) error {
	if err := validatePath(path); err != nil {
		return err
	}
	if isProtectedPath(path) {
		return fmt.Errorf("protected path cannot be deleted: %s", path)
	}
	parent := filepath.Dir(filepath.Clean(path))
	if resolvedParent, err := resolveFinalPath(parent); err == nil {
		if isProtectedPath(filepath.Join(resolvedParent, filepath.Base(path))) {
			return fmt.Errorf("protected path cannot be deleted: %s", path)
		}
	}
	return nil
}

// validatePath checks path safety for external commands.
// Returns error if path is empty, relative, contains null bytes, or has traversal.
func validatePath(path string) error {
	if path == "" {
		return fmt.Errorf("path is empty")
	}
	if !filepath.IsAbs(path) {
		return fmt.Errorf("path must be absolute: %s", path)
	}
	if strings.Contains(path, "\x00") {
		return fmt.Errorf("path contains null bytes")
	}
	if slices.Contains(strings.FieldsFunc(path, func(r rune) bool { return r == '\\' || r == '/' }), "..") {
		return fmt.Errorf("path contains traversal components: %s", path)
	}
	return nil
}
