# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An interactive Bash installer that stands up a Docker-based "ARR" media stack
(qBittorrent, SABnzbd, Sonarr, Radarr, Lidarr, Readarr, Jellyfin, Overseerr,
Portainer). The user runs `./install.sh`; it detects/installs Docker, asks which
apps to deploy, writes a `.env` and a `docker-compose.yml`, then launches the
stack. There is no application code being compiled — the "product" is the
generated compose file and the scripts that produce and operate it.

## Commands

- `./install.sh` — full interactive setup (distro/Docker checks → app selection → `.env` → `docker-compose.yml` → deploy → URLs). Re-running regenerates `.env`/`docker-compose.yml`.
- `./update.sh` — `compose pull` + `up -d` + image prune.
- `./backup.sh [dest]` — tars `docker-compose.yml`, `.env`, and `$CONFIG_ROOT` (media is deliberately excluded).
- `bash -n install.sh lib/*.sh` — syntax check (there is no test suite).
- Validate generated YAML without deploying:
  ```bash
  bash -c 'source lib/common.sh; source lib/services.sh;
    { echo services:; for k in "${ALL_SERVICES[@]}"; do emit_service "$k"; done; }' \
    | python3 -c 'import sys,yaml; yaml.safe_load(sys.stdin); print("ok")'
  ```
  If Docker is present, `docker compose -f <file> --env-file .env config` is the authoritative schema check.

## Architecture

`install.sh` is the orchestrator; it sources three libraries from `lib/` and runs
the spec's 8 steps in `main()`. Each step is one function — keep that 1:1 mapping
when editing.

- **`lib/common.sh`** — logging (`log/ok/warn/err/die`), prompt helpers (`ask`, `confirm "Q" [Y|N]`), and privilege handling. `SUDO` is set once at source time; `as_root` wraps any command needing root. Non-interactive callers don't exist — everything assumes a TTY.
- **`lib/system.sh`** — distro detection (`/etc/os-release` → `PKG` = apt/dnf/yum), prereq install, and Docker/Compose bring-up. Sets the globals **`DOCKER`** and **`COMPOSE`** which may be sudo-prefixed strings (e.g. `"sudo docker compose"`); they are used unquoted on purpose so word-splitting runs the right command. Compose v2 (`docker compose`) is preferred over the legacy `docker-compose` binary.
- **`lib/services.sh`** — the data model for ~23 services. Three parallel structures keyed by service name: `ALL_SERVICES` (order), `SVC_LABEL` (prompt text), `SVC_PORT` (host web-UI port — **`""` for background services** like `unpackerr`/`recyclarr` that have no UI; callers must skip empties), plus the `emit_service KEY` block. `in_selected KEY` tests membership in the `SELECTED` array. **A service is fully described by entries in `ALL_SERVICES` + `SVC_LABEL` + `SVC_PORT` + `emit_service`** — adding one means touching only `lib/services.sh`.
  - Two emitters are **selection-aware** (the only break from pure per-service independence): `gluetun` publishes qBittorrent's ports only when qBittorrent is selected, and `qbittorrent` switches to `network_mode: "service:gluetun"` when the global `USE_GLUETUN=1`. `USE_GLUETUN` is computed in `install.sh:main` from the selection before `write_compose`. Only the torrent client is VPN-routed — routing SABnzbd too would collide on the shared namespace's :8080.

Data flow: `select_apps` fills the `SELECTED` array → `write_env` collects PUID/PGID/TZ/paths into `.env` → `write_compose` concatenates `emit_service` output for each selected key → compose interpolates the `.env` values (`${PUID}`, `${CONFIG_ROOT}`, …) at deploy time. The scripts never bake config values into the YAML; everything flows through `.env`.

## Conventions that matter

- **Generated artifacts are not committed.** `.env`, `docker-compose.yml`, `config/`, and `backups/` are gitignored. Only the scripts are source-controlled.
- **Ports are assigned to avoid collisions.** qBittorrent (8080) and SABnzbd (web 8080 internally) would clash, so SABnzbd is published on host 8081. If you add a service, pick a free host port and put it in `SVC_PORT`; `check_ports` enforces this at deploy.
- **Image choices:** LinuxServer (`lscr.io/linuxserver/*`) images wherever they exist, because they share the PUID/PGID/TZ contract. Non-LSIO images that hold state but lack that contract (Navidrome, Audiobookshelf, Maintainerr, Recyclarr) pin ownership with `user: "${PUID}:${PGID}"` instead. Stateless/socket-only ones (FlareSolverr, Dozzle) take just `TZ`/nothing. Intentional pins/deviations: **Readarr** → `:0.4.18-develop` (rolling tags lost their amd64 manifest; `update.sh` won't bump it), **Portainer** → `portainer/portainer-ce` (root + Docker socket), **Jellyseerr** on host **5056** to coexist with Overseerr's 5055.
- **Gotchas baked in:** `HOMEPAGE_ALLOWED_HOSTS` is required by recent Homepage versions or it refuses connections — it's prompted and written to `.env` only when Homepage is selected. Gluetun and Homepage env blocks are appended to `.env` conditionally (so the file only references vars that the emitted compose actually uses). Services with nested config mounts (`tdarr`, `audiobookshelf`) are pre-created with correct ownership in `make_dirs` before deploy, otherwise Docker creates them as root and the `user:`-pinned containers can't write.
- **Idempotent paths:** `mkdir -p` + `chown` of config/media dirs is safe to re-run; deploy uses `up -d` so re-running reconciles rather than duplicating.
