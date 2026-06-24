package main

import (
	"archive/zip"
	"bytes"
	_ "embed"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

//go:embed bundle.zip
var bundleZip []byte

//go:embed bundle_hash.txt
var bundleHash string

func main() {
	hash := strings.TrimSpace(bundleHash)
	cacheDir := resolveCache(hash)
	markerFile := filepath.Join(cacheDir, ".ok")

	if _, err := os.Stat(markerFile); os.IsNotExist(err) {
		fmt.Fprintln(os.Stderr, "[gitsync] Первый запуск: распаковываем компоненты...")
		if err := extractZip(bundleZip, cacheDir); err != nil {
			fmt.Fprintf(os.Stderr, "[gitsync] Ошибка распаковки: %v\n", err)
			os.Exit(1)
		}
		if err := os.WriteFile(markerFile, []byte("ok"), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "[gitsync] Ошибка записи маркера: %v\n", err)
			os.Exit(1)
		}
		fmt.Fprintln(os.Stderr, "[gitsync] Готово.")
	}

	oscriptDir := filepath.Join(cacheDir, "oscript")
	modulesDir := filepath.Join(cacheDir, "modules")
	gitsyncBat := filepath.Join(modulesDir, "bin", "gitsync.bat")

	if _, err := os.Stat(gitsyncBat); err != nil {
		fmt.Fprintf(os.Stderr, "[gitsync] gitsync.bat не найден: %s\n", gitsyncBat)
		os.Exit(1)
	}

	// Добавляем локальный oscript в начало PATH, чтобы gitsync.bat использовал его
	currentPath := os.Getenv("PATH")
	newPath := oscriptDir
	if currentPath != "" {
		newPath = oscriptDir + ";" + currentPath
	}

	// Строим окружение: переопределяем PATH и GITSYNC_PLUGINS_PATH
	env := make([]string, 0, len(os.Environ())+2)
	for _, e := range os.Environ() {
		key := strings.ToUpper(strings.SplitN(e, "=", 2)[0])
		if key == "PATH" || key == "GITSYNC_PLUGINS_PATH" {
			continue
		}
		env = append(env, e)
	}
	env = append(env, "PATH="+newPath)
	env = append(env, "GITSYNC_PLUGINS_PATH="+modulesDir)

	args := append([]string{"/C", gitsyncBat}, os.Args[1:]...)
	cmd := exec.Command("cmd.exe", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = env

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		os.Exit(1)
	}
}

func resolveCache(hash string) string {
	base := os.Getenv("LOCALAPPDATA")
	if base == "" {
		base = filepath.Join(os.Getenv("USERPROFILE"), "AppData", "Local")
	}
	if base == "" {
		base = os.TempDir()
	}
	return filepath.Join(base, "gitsync-bundle", hash)
}

func extractZip(data []byte, destDir string) error {
	r, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return fmt.Errorf("open zip: %w", err)
	}

	if err := os.RemoveAll(destDir); err != nil {
		return fmt.Errorf("clean dest dir: %w", err)
	}

	cleanDest := filepath.Clean(destDir) + string(os.PathSeparator)

	for _, f := range r.File {
		target := filepath.Join(destDir, filepath.FromSlash(f.Name))
		if !strings.HasPrefix(filepath.Clean(target)+string(os.PathSeparator), cleanDest) {
			return fmt.Errorf("небезопасный путь в архиве: %s", f.Name)
		}

		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(target, 0755); err != nil {
				return fmt.Errorf("mkdir %s: %w", target, err)
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
			return fmt.Errorf("mkdir parent %s: %w", target, err)
		}

		rc, err := f.Open()
		if err != nil {
			return fmt.Errorf("open %s: %w", f.Name, err)
		}
		out, err := os.Create(target)
		if err != nil {
			rc.Close()
			return fmt.Errorf("create %s: %w", target, err)
		}
		_, copyErr := io.Copy(out, rc)
		rc.Close()
		out.Close()
		if copyErr != nil {
			return fmt.Errorf("copy %s: %w", f.Name, copyErr)
		}
	}

	return nil
}
