#!/usr/bin/env bash
# Service catalog and docker-compose block emitters.
#
# To add a new service: add its key to ALL_SERVICES, give it a SVC_LABEL and a
# SVC_PORT (host web-UI port; leave "" for background services with no UI), then
# add a matching block to emit_service(). LinuxServer images are preferred; they
# read PUID/PGID/TZ from the generated .env via compose interpolation. Non-LSIO
# images that lack a PUID/PGID contract instead pin ownership with `user:`.
#
# Two emitters are selection-aware (they branch on the rest of the stack):
#   - gluetun     publishes qBittorrent's ports only when qBittorrent is selected
#   - qbittorrent routes itself through gluetun when USE_GLUETUN=1

ALL_SERVICES=(
  gluetun qbittorrent sabnzbd unpackerr
  prowlarr flaresolverr
  sonarr radarr lidarr readarr bazarr recyclarr
  jellyfin navidrome calibre-web audiobookshelf tdarr
  overseerr jellyseerr maintainerr
  homepage portainer dozzle
)

declare -A SVC_LABEL=(
  [gluetun]="Gluetun (VPN — routes qBittorrent)"
  [qbittorrent]="qBittorrent (torrent client)"
  [sabnzbd]="SABnzbd (usenet client)"
  [unpackerr]="Unpackerr (auto-extract completed downloads)"
  [prowlarr]="Prowlarr (indexer manager)"
  [flaresolverr]="FlareSolverr (Cloudflare solver for indexers)"
  [sonarr]="Sonarr (TV)"
  [radarr]="Radarr (movies)"
  [lidarr]="Lidarr (music)"
  [readarr]="Readarr (books)"
  [bazarr]="Bazarr (subtitles for Sonarr/Radarr)"
  [recyclarr]="Recyclarr (TRaSH quality profiles sync)"
  [jellyfin]="Jellyfin (media server)"
  [navidrome]="Navidrome (music streaming)"
  [calibre-web]="Calibre-Web (ebook reader/library)"
  [audiobookshelf]="Audiobookshelf (audiobooks & podcasts)"
  [tdarr]="Tdarr (library transcoding/health checks)"
  [overseerr]="Overseerr (requests, Plex-oriented)"
  [jellyseerr]="Jellyseerr (requests, Jellyfin-oriented)"
  [maintainerr]="Maintainerr (library cleanup rules)"
  [homepage]="Homepage (dashboard)"
  [portainer]="Portainer (container management)"
  [dozzle]="Dozzle (live container log viewer)"
)

# Host web-UI port per service ("" = background service, no UI).
declare -A SVC_PORT=(
  [gluetun]=8000
  [qbittorrent]=8080
  [sabnzbd]=8081
  [unpackerr]=""
  [prowlarr]=9696
  [flaresolverr]=8191
  [sonarr]=8989
  [radarr]=7878
  [lidarr]=8686
  [readarr]=8787
  [bazarr]=6767
  [recyclarr]=""
  [jellyfin]=8096
  [navidrome]=4533
  [calibre-web]=8083
  [audiobookshelf]=13378
  [tdarr]=8265
  [overseerr]=5055
  [jellyseerr]=5056
  [maintainerr]=6246
  [homepage]=3000
  [portainer]=9000
  [dozzle]=8888
)

# True if KEY is in the SELECTED array (set by install.sh).
in_selected() { local x; for x in "${SELECTED[@]:-}"; do [[ $x == "$1" ]] && return 0; done; return 1; }

# Common environment lines shared by LinuxServer images.
_lsio_env() {
  cat <<'EOF'
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
EOF
}

# emit_service KEY -> prints the YAML block for one service (2-space indented).
emit_service() {
  case $1 in
    gluetun)
      cat <<'EOF'
  gluetun:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    environment:
      - VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER}
      - VPN_TYPE=${VPN_TYPE}
      - WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY}
      - WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES}
      - OPENVPN_USER=${OPENVPN_USER}
      - OPENVPN_PASSWORD=${OPENVPN_PASSWORD}
      - SERVER_COUNTRIES=${SERVER_COUNTRIES}
      - TZ=${TZ}
    volumes:
      - ${CONFIG_ROOT}/gluetun:/gluetun
    ports:
      - 8000:8000
EOF
      # Publish the torrent client's ports here, since it shares this namespace.
      if in_selected qbittorrent; then
        cat <<'EOF'
      - 8080:8080
      - 6881:6881
      - 6881:6881/udp
EOF
      fi
      echo "    restart: unless-stopped"
      ;;
    qbittorrent)
      cat <<'EOF'
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - WEBUI_PORT=8080
    volumes:
      - ${CONFIG_ROOT}/qbittorrent:/config
      - ${DOWNLOADS_ROOT}:/downloads
EOF
      if [[ ${USE_GLUETUN:-0} == 1 ]]; then
        # Share gluetun's network namespace; ports are published on gluetun.
        cat <<'EOF'
    network_mode: "service:gluetun"
    depends_on:
      - gluetun
    restart: unless-stopped
EOF
      else
        cat <<'EOF'
    ports:
      - 8080:8080
      - 6881:6881
      - 6881:6881/udp
    restart: unless-stopped
EOF
      fi
      ;;
    sabnzbd)
      { echo "  sabnzbd:"; echo "    image: lscr.io/linuxserver/sabnzbd:latest"; \
        echo "    container_name: sabnzbd"; _lsio_env; cat <<'EOF'
    volumes:
      - ${CONFIG_ROOT}/sabnzbd:/config
      - ${DOWNLOADS_ROOT}:/downloads
    ports:
      - 8081:8080
    restart: unless-stopped
EOF
      } ;;
    unpackerr)
      cat <<'EOF'
  unpackerr:
    image: ghcr.io/hotio/unpackerr:latest
    container_name: unpackerr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ${CONFIG_ROOT}/unpackerr:/config
      - ${DOWNLOADS_ROOT}:/downloads
    restart: unless-stopped
EOF
      ;;
    prowlarr)
      { echo "  prowlarr:"; echo "    image: lscr.io/linuxserver/prowlarr:latest"; \
        echo "    container_name: prowlarr"; _lsio_env; cat <<'EOF'
    volumes:
      - ${CONFIG_ROOT}/prowlarr:/config
    ports:
      - 9696:9696
    restart: unless-stopped
EOF
      } ;;
    flaresolverr)
      # Not a LinuxServer image; stateless, no PUID/PGID, no volumes.
      cat <<'EOF'
  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      - LOG_LEVEL=info
      - TZ=${TZ}
    ports:
      - 8191:8191
    restart: unless-stopped
EOF
      ;;
    sonarr)
      { echo "  sonarr:"; echo "    image: lscr.io/linuxserver/sonarr:latest"; \
        echo "    container_name: sonarr"; _lsio_env; cat <<'EOF'
    volumes:
      - ${CONFIG_ROOT}/sonarr:/config
      - ${MEDIA_ROOT}/tv:/tv
      - ${DOWNLOADS_ROOT}:/downloads
    ports:
      - 8989:8989
    restart: unless-stopped
EOF
      } ;;
    radarr)
      { echo "  radarr:"; echo "    image: lscr.io/linuxserver/radarr:latest"; \
        echo "    container_name: radarr"; _lsio_env; cat <<'EOF'
    volumes:
      - ${CONFIG_ROOT}/radarr:/config
      - ${MEDIA_ROOT}/movies:/movies
      - ${DOWNLOADS_ROOT}:/downloads
    ports:
      - 7878:7878
    restart: unless-stopped
EOF
      } ;;
    lidarr)
      { echo "  lidarr:"; echo "    image: lscr.io/linuxserver/lidarr:latest"; \
        echo "    container_name: lidarr"; _lsio_env; cat <<'EOF'
    volumes:
      - ${CONFIG_ROOT}/lidarr:/config
      - ${MEDIA_ROOT}/music:/music
      - ${DOWNLOADS_ROOT}:/downloads
    ports:
      - 8686:8686
    restart: unless-stopped
EOF
      } ;;
    readarr)
      # Readarr is wound down upstream; LinuxServer's rolling :develop/:nightly
      # tags have lost their amd64 manifest, so pin to a version tag that is
      # still multi-arch (amd64 + arm64). update.sh will not bump this.
      { echo "  readarr:"; echo "    image: lscr.io/linuxserver/readarr:0.4.18-develop"; \
        echo "    container_name: readarr"; _lsio_env; cat <<'EOF'
    volumes:
      - ${CONFIG_ROOT}/readarr:/config
      - ${MEDIA_ROOT}/books:/books
      - ${DOWNLOADS_ROOT}:/downloads
    ports:
      - 8787:8787
    restart: unless-stopped
EOF
      } ;;
    bazarr)
      { echo "  bazarr:"; echo "    image: lscr.io/linuxserver/bazarr:latest"; \
        echo "    container_name: bazarr"; _lsio_env; cat <<'EOF'
    volumes:
      - ${CONFIG_ROOT}/bazarr:/config
      - ${MEDIA_ROOT}/movies:/movies
      - ${MEDIA_ROOT}/tv:/tv
    ports:
      - 6767:6767
    restart: unless-stopped
EOF
      } ;;
    recyclarr)
      # No web UI; runs on a schedule. user: pins config ownership (no PUID env).
      cat <<'EOF'
  recyclarr:
    image: ghcr.io/recyclarr/recyclarr:latest
    container_name: recyclarr
    user: "${PUID}:${PGID}"
    environment:
      - TZ=${TZ}
      - CRON_SCHEDULE=@daily
    volumes:
      - ${CONFIG_ROOT}/recyclarr:/config
    restart: unless-stopped
EOF
      ;;
    jellyfin)
      { echo "  jellyfin:"; echo "    image: lscr.io/linuxserver/jellyfin:latest"; \
        echo "    container_name: jellyfin"; _lsio_env; cat <<'EOF'
    volumes:
      - ${CONFIG_ROOT}/jellyfin:/config
      - ${MEDIA_ROOT}/tv:/data/tv
      - ${MEDIA_ROOT}/movies:/data/movies
      - ${MEDIA_ROOT}/music:/data/music
      - ${MEDIA_ROOT}/books:/data/books
    ports:
      - 8096:8096
    restart: unless-stopped
EOF
      } ;;
    navidrome)
      cat <<'EOF'
  navidrome:
    image: deluan/navidrome:latest
    container_name: navidrome
    user: "${PUID}:${PGID}"
    environment:
      - TZ=${TZ}
      - ND_SCANSCHEDULE=1h
      - ND_LOGLEVEL=info
    volumes:
      - ${CONFIG_ROOT}/navidrome:/data
      - ${MEDIA_ROOT}/music:/music:ro
    ports:
      - 4533:4533
    restart: unless-stopped
EOF
      ;;
    calibre-web)
      { echo "  calibre-web:"; echo "    image: lscr.io/linuxserver/calibre-web:latest"; \
        echo "    container_name: calibre-web"; _lsio_env; cat <<'EOF'
    volumes:
      - ${CONFIG_ROOT}/calibre-web:/config
      - ${MEDIA_ROOT}/books:/books
    ports:
      - 8083:8083
    restart: unless-stopped
EOF
      } ;;
    audiobookshelf)
      cat <<'EOF'
  audiobookshelf:
    image: ghcr.io/advplyr/audiobookshelf:latest
    container_name: audiobookshelf
    user: "${PUID}:${PGID}"
    environment:
      - TZ=${TZ}
    volumes:
      - ${CONFIG_ROOT}/audiobookshelf/config:/config
      - ${CONFIG_ROOT}/audiobookshelf/metadata:/metadata
      - ${MEDIA_ROOT}/audiobooks:/audiobooks
      - ${MEDIA_ROOT}/podcasts:/podcasts
    ports:
      - 13378:80
    restart: unless-stopped
EOF
      ;;
    tdarr)
      cat <<'EOF'
  tdarr:
    image: ghcr.io/haveagitgat/tdarr:latest
    container_name: tdarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - serverIP=0.0.0.0
      - serverPort=8266
      - webUIPort=8265
      - internalNode=true
      - inContainer=true
    volumes:
      - ${CONFIG_ROOT}/tdarr/server:/app/server
      - ${CONFIG_ROOT}/tdarr/configs:/app/configs
      - ${CONFIG_ROOT}/tdarr/logs:/app/logs
      - ${CONFIG_ROOT}/tdarr/transcode-cache:/temp
      - ${MEDIA_ROOT}:/media
    ports:
      - 8265:8265
      - 8266:8266
    restart: unless-stopped
EOF
      ;;
    overseerr)
      { echo "  overseerr:"; echo "    image: lscr.io/linuxserver/overseerr:latest"; \
        echo "    container_name: overseerr"; _lsio_env; cat <<'EOF'
    volumes:
      - ${CONFIG_ROOT}/overseerr:/config
    ports:
      - 5055:5055
    restart: unless-stopped
EOF
      } ;;
    jellyseerr)
      # fallenbagel image (not LinuxServer); honors PUID/PGID/TZ, config at
      # /app/config. Web UI defaults to 5055 internally — published on host
      # 5056 to avoid clashing with Overseerr.
      cat <<'EOF'
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ${CONFIG_ROOT}/jellyseerr:/app/config
    ports:
      - 5056:5055
    restart: unless-stopped
EOF
      ;;
    maintainerr)
      cat <<'EOF'
  maintainerr:
    image: ghcr.io/jorenn92/maintainerr:latest
    container_name: maintainerr
    user: "${PUID}:${PGID}"
    environment:
      - TZ=${TZ}
    volumes:
      - ${CONFIG_ROOT}/maintainerr:/opt/data
    ports:
      - 6246:6246
    restart: unless-stopped
EOF
      ;;
    homepage)
      # HOMEPAGE_ALLOWED_HOSTS is required by recent versions or it rejects
      # connections; it is set from .env. Socket is mounted read-only for the
      # Docker integration widgets.
      cat <<'EOF'
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - HOMEPAGE_ALLOWED_HOSTS=${HOMEPAGE_ALLOWED_HOSTS}
    volumes:
      - ${CONFIG_ROOT}/homepage:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - 3000:3000
    restart: unless-stopped
EOF
      ;;
    portainer)
      # Not a LinuxServer image; needs the Docker socket and runs as root.
      cat <<'EOF'
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${CONFIG_ROOT}/portainer:/data
    ports:
      - 9000:9000
    restart: unless-stopped
EOF
      ;;
    dozzle)
      # Read-only log viewer; only needs the Docker socket.
      cat <<'EOF'
  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - 8888:8080
    restart: unless-stopped
EOF
      ;;
    *) die "Unknown service: $1" ;;
  esac
}
