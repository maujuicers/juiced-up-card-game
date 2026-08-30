#!/usr/bin/env bash
# Start the stack. With Podman, also make an unhealthy game container restart
# itself: compose has no key for that, `up` recreates containers without it,
# and the `kill` action would count as a manual stop that no restart policy
# undoes. After loading a new image run `podman-compose down` first.
set -euo pipefail
cd "$(dirname "$0")"
if command -v podman > /dev/null; then
	podman-compose up -d --no-recreate
	for n in 1 2 3; do
		podman update --health-on-failure=restart "meowmau-game$n" > /dev/null
	done
else
	docker compose up -d
	echo "Docker does not act on unhealthy containers: keep ./watchdog.sh running."
fi
