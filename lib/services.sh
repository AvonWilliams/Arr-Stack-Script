#!/usr/bin/env bash
# Service catalog and docker-compose block emitters.
#
# To add a new service: add its key to ALL_SERVICES, give it a SVC_LABEL and a
# SVC_PORT (the host web-UI port, used for conflict checks and URLs), then add a
# matching block to emit_service(). LinuxServer images are preferred; they read
# PUID/PGID/TZ from the generated .env via compose interpolation.

ALL_SERVICES=(qbittorrent sabnzbd sonarr radarr lidarr readarr jellyfin overseerr portainer)

declare -A SVC_LABEL=(
  [qbittorrent]="qBittorrent (torrent client)"
  [sabnzbd]="SABnzbd (usenet client)"
  [sonarr]="Sonarr (TV)"
  [radarr]="Radarr (movies)"
  [lidarr]="Lidarr (music)"
  [readarr]="Readarr (books)"
  [jellyfin]="Jellyfin (media server)"
  [overseerr]="Overseerr (media requests)"
  [portainer]="Portainer (container management)"
)

# Host port exposed for each service's web UI.
declare -A SVC_PORT=(
  [qbittorrent]=8080
  [sabnzbd]=8081
  [sonarr]=8989
  [radarr]=7878
  [lidarr]=8686
  [readarr]=8787
  [jellyfin]=8096
  [overseerr]=5055
  [portainer]=9000
)

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
    ports:
      - 8080:8080
      - 6881:6881
      - 6881:6881/udp
    restart: unless-stopped
EOF
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
      # Readarr only publishes a :develop tag on LinuxServer.
      { echo "  readarr:"; echo "    image: lscr.io/linuxserver/readarr:develop"; \
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
    *) die "Unknown service: $1" ;;
  esac
}
