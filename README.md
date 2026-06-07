# Arr-Stack-Script

Interactive installer for a Docker-based **ARR media stack**. One command detects
and installs Docker, lets you pick which apps to run, generates the config, and
launches everything.

## Apps

| Service | Role | Default URL |
|---|---|---|
| qBittorrent | Torrent download client | `:8080` |
| SABnzbd | Usenet download client | `:8081` |
| Sonarr | TV management | `:8989` |
| Radarr | Movie management | `:7878` |
| Lidarr | Music management | `:8686` |
| Readarr | Book management | `:8787` |
| Jellyfin | Media server | `:8096` |
| Overseerr | Media requests | `:5055` |
| Portainer | Container management UI | `:9000` |

## Install

```bash
git clone <this-repo> arr-stack && cd arr-stack
./install.sh
```

The installer will:

1. Check the distro (Ubuntu/Debian/CentOS/RHEL) and install `curl`/`wget`/`git` if missing.
2. Install Docker + Compose if not present, and verify your user can run Docker.
3. Ask which of the apps above to install.
4. Prompt for `PUID`, `PGID`, timezone, and your media/download paths → writes `.env`.
5. Generate `docker-compose.yml` for the selected apps.
6. Check for port conflicts, deploy the stack, and print the access URLs.

`.env` and `docker-compose.yml` are generated locally and are **not** committed —
edit `.env` and run `docker compose up -d` to change settings later.

## Day-2 operations

```bash
./update.sh            # pull latest images and recreate containers
./backup.sh [dest]     # archive docker-compose.yml, .env, and all app configs
```

`backup.sh` does **not** archive your media library (too large) — only the
configuration needed to rebuild the stack. Back up media separately.

## Notes

- LinuxServer.io images are used where available so all apps honor the same
  `PUID`/`PGID`/`TZ` settings.
- After first launch, set a strong password in each web UI. qBittorrent prints a
  temporary admin password to its log: `docker logs qbittorrent`.
- If you expose any service to the internet, put it behind a reverse proxy with
  HTTPS rather than publishing the raw ports.
