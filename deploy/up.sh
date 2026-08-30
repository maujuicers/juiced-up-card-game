#!/usr/bin/env bash
# Start the stack. With Podman, also make an unhealthy game container restart
# itself: compose has no key for that, `up` recreates containers without it,
# and the `kill` action would count as a manual stop that no restart policy
# undoes. A freshly loaded image is picked up: containers still on the
# previous image are recreated.
set -euo pipefail
cd "$(dirname "$0")"

CONTAINERS=(meowmau-game1 meowmau-game2 meowmau-game3 meowmau-caddy)

if command -v podman > /dev/null; then
	missing=0
	for c in "${CONTAINERS[@]}"; do
		podman container exists "$c" || missing=1
	done
	if [ "$missing" -eq 0 ]; then
		wanted=$(podman image inspect --format '{{.Id}}' localhost/meowmau-server:latest)
		for n in 1 2 3; do
			if [ "$(podman container inspect --format '{{.Image}}' "meowmau-game$n")" != "$wanted" ]; then
				echo "meowmau-game$n runs an older image; recreating the stack."
				podman-compose down
				missing=1
				break
			fi
		done
	fi
	if [ "$missing" -eq 0 ]; then
		podman start "${CONTAINERS[@]}" > /dev/null
		echo "Stack already present; started anything that was down."
	else
		podman-compose up -d --no-recreate
	fi
	for n in 1 2 3; do
		# `podman update`, not `podman create` — no --replace here, and the flag
		# does not exist on this subcommand.
		podman update --health-on-failure=restart "meowmau-game$n" > /dev/null
	done
else
	docker compose up -d
	echo "Docker does not act on unhealthy containers: keep ./watchdog.sh running."
fi
