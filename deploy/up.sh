#!/usr/bin/env bash
# Start the stack. With Podman, also make an unhealthy game container restart
# itself: compose has no key for that, `up` recreates containers without it,
# and the `kill` action would count as a manual stop that no restart policy
# undoes. After loading a new image run `podman-compose down` first.
set -euo pipefail
cd "$(dirname "$0")"

CONTAINERS=(meowmau-game1 meowmau-game2 meowmau-game3 meowmau-caddy)

if command -v podman > /dev/null; then
	missing=0
	for c in "${CONTAINERS[@]}"; do
		podman container exists "$c" || missing=1
	done
	if [ "$missing" -eq 0 ]; then
		# podman-compose 1.3.0 reads --no-recreate as "skip the teardown", not
		# "skip the create", so on a stack that is already up it fails once per
		# container with "name already in use" and carries on. Nothing is wrong
		# in that case, so don't ask it: start is a no-op on a running container.
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
