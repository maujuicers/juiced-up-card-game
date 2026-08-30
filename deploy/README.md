# Deploying the dedicated server

## Build and ship

```sh
nix run .#server-image | podman load                      # locally, or
nix run .#server-image | ssh ozoromo@meowmau.game.ozoromo.com podman load
```

## Run

```sh
rsync -a deploy/ ozoromo@meowmau.game.ozoromo.com:meowmau/   # after edits
./up.sh          # brings the stack up (safe to re-run), then arms health-on-failure
./status.sh      # health of game1..3 and of the balancer
./restart.sh 2   # restart one instance by hand (its rooms are lost)
```

## How requests are routed

Clients open `wss://meowmau.game.ozoromo.com/ws/<ROOMCODE>`.
`caddy` container, which balances over `game1..3` with `lb_policy uri_hash`.

`/healthz` on the balancer answers 200 while at least one instance answers.

## Health and automatic restarts

`/healthz` is served from the game loop (`Net._process`), so a hung process
stops answering. 

- Podman: `up.sh` runs `podman update --health-on-failure=restart` on each
  game container.
- Docker: `watchdog.sh` polls the health status and restarts an unhealthy
  container (`nohup ./watchdog.sh &` or a systemd unit).

```sh
systemctl --user enable --now podman-restart.service   # needs `loginctl enable-linger`
```

`podman logs meowmau-game2` shows the instance's output live.
