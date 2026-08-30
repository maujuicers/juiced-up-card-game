#!/usr/bin/env bash
# restart.sh <1|2|3>  — restart one game instance; its rooms are lost.
set -euo pipefail
case "${1:-}" in
	1 | 2 | 3) ;;
	*) echo "usage: $0 <1|2|3>" >&2; exit 2 ;;
esac
cli=$(command -v podman || command -v docker)
"$cli" restart "meowmau-game$1"
