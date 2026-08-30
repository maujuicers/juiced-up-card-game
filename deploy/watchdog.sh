#!/usr/bin/env bash
# Restart a game container whose healthcheck reports unhealthy. Podman does
# this natively (see up.sh); this loop is for Docker, whose restart policy
# ignores health. Run it in the background or from a systemd unit.
set -uo pipefail
cli=$(command -v podman || command -v docker)
while true; do
	for n in 1 2 3; do
		c="meowmau-game$n"
		if [ "$("$cli" inspect --format '{{.State.Health.Status}}' "$c" 2>/dev/null)" = unhealthy ]; then
			echo "$(date -Is) $c unhealthy, restarting"
			"$cli" restart "$c"
		fi
	done
	sleep "${INTERVAL:-10}"
done
