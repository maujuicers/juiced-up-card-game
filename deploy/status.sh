#!/usr/bin/env bash
# Health of the three instances and of the load balancer.
set -uo pipefail
cli=$(command -v podman || command -v docker)
for n in 1 2 3; do
	printf 'game%s: ' "$n"
	"$cli" inspect --format '{{.State.Status}} {{.State.Health.Status}} (restarts: {{.RestartCount}})' "meowmau-game$n" 2>&1
done
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${MEOWMAU_LB_PORT:-9080}/healthz")
echo "caddy: ${code/000/unreachable}"
