package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCleanableHintRequiresCacheEvidence(t *testing.T) {
	for _, name := range []string{"build", "dist", "vendor", ".yarn", ".bundle", "node_modules"} {
		dir := filepath.Join(t.TempDir(), name)
		if err := os.Mkdir(dir, 0755); err != nil {
			t.Fatal(err)
		}
		if isCleanableDir(dir) {
			t.Errorf("unverified directory %s was marked cleanable", name)
		}
	}
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, cacheDirTagFileName), []byte(cacheDirTagSignature), 0644); err != nil {
		t.Fatal(err)
	}
	if !isCleanableDir(dir) {
		t.Fatal("valid cache tag should retain its hint")
	}
}
