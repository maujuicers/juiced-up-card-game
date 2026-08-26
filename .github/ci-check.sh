#!/usr/bin/env bash
# CI checks: 
# - import assets
# - load every script inside the project (catches compile errors, sees autoloads)
# - boot main_scene headless
# Run locally with: nix develop --command ./.github/ci-check.sh
set -uo pipefail

log_dir="$(mktemp -d)"

echo "==> Importing project"
timeout 600 godot --path . --headless --import 2>&1 | tee "$log_dir/import.log"
import_exit=$?
# --import can exit 0 despite script errors
if [ "$import_exit" -ne 0 ] || grep -qE "SCRIPT ERROR|^ERROR" "$log_dir/import.log"; then
	echo "FAIL: import reported errors (exit $import_exit)"
	exit 1
fi

echo "==> Parse-checking scripts"
# Loads every script inside the running project so autoload singletons
# (e.g. AudioManager) resolve; `--check-only --script` cannot see them.
timeout 300 godot --path . --headless --script .github/check_scripts.gd 2>&1 | tee "$log_dir/scripts.log"
scripts_exit=$?
if [ "$scripts_exit" -ne 0 ] || grep -qE "SCRIPT ERROR|PARSE FAIL" "$log_dir/scripts.log"; then
	echo "FAIL: script check reported errors (exit $scripts_exit)"
	exit 1
fi

echo "==> Smoke test: booting main_scene for 120 frames"
timeout 300 godot --path . --headless --quit-after 120 res://main_scene.tscn 2>&1 | tee "$log_dir/smoke.log"
smoke_exit=$?
# Exit code is unreliable -> grep for runtime script errors.
# Headless runs use the dummy audio driver, whose mixer never gets to free
# playbacks that are still active at quit; Godot then reports
# "N resources still in use at exit" (and leaked AudioStreamPlayback warnings).
# A windowed run with a real driver exits clean, so that one line is noise.
if [ "$smoke_exit" -ne 0 ] || grep -vE "resources still in use at exit" "$log_dir/smoke.log" | grep -qE "SCRIPT ERROR|^ERROR"; then
	echo "FAIL: smoke test reported errors (exit $smoke_exit)"
	exit 1
fi

echo "==> All checks passed"
