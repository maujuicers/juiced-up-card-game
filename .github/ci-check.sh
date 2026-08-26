#!/usr/bin/env bash
# CI checks: 
# - import assets
# - parse-check every script
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
fail=0
while IFS= read -r f; do
	if ! timeout 120 godot --path . --headless --check-only --script "$f"; then
		echo "PARSE FAIL: $f"
		fail=1
	fi
done < <(find scripts -name '*.gd' | sort)
if [ "$fail" -ne 0 ]; then
	exit 1
fi

echo "==> Smoke test: booting main_scene for 120 frames"
timeout 300 godot --path . --headless --quit-after 120 res://main_scene.tscn 2>&1 | tee "$log_dir/smoke.log"
smoke_exit=$?
# Exit code is unreliable -> grep for runtime script errors.
if [ "$smoke_exit" -ne 0 ] || grep -qE "SCRIPT ERROR|^ERROR" "$log_dir/smoke.log"; then
	echo "FAIL: smoke test reported errors (exit $smoke_exit)"
	exit 1
fi

echo "==> All checks passed"
