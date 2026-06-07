#!/usr/bin/env bash
# Steps 1 & 2: distribution detection, base utilities, Docker + Compose.
# Sets globals used by the rest of the installer:
#   PKG      package manager (apt|dnf|yum)
#   DOCKER   docker command (may be "sudo docker")
#   COMPOSE  compose command ("docker compose" or "docker-compose", maybe sudo-prefixed)

detect_distro() {
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release; unsupported system."
  # shellcheck disable=SC1091
  . /etc/os-release
  case " $ID ${ID_LIKE:-} " in
    *" debian "*|*" ubuntu "*) PKG=apt ;;
    *" rhel "*|*" centos "*|*" fedora "*) PKG=dnf ;;
    *) die "Unsupported distribution: ${PRETTY_NAME:-$ID}. Supported: Ubuntu/Debian/CentOS/RHEL." ;;
  esac
  [[ $PKG == dnf ]] && ! have dnf && have yum && PKG=yum
  ok "Detected ${PRETTY_NAME:-$ID} (package manager: $PKG)"
}

pkg_install() {
  case $PKG in
    apt) as_root apt-get update -qq && as_root apt-get install -y "$@" ;;
    dnf) as_root dnf install -y "$@" ;;
    yum) as_root yum install -y "$@" ;;
  esac
}

install_prereqs() {
  log "Ensuring base utilities (curl, wget, git)..."
  local c missing=()
  for c in curl wget git; do have "$c" || missing+=("$c"); done
  if ((${#missing[@]})); then
    pkg_install "${missing[@]}" || die "Failed to install: ${missing[*]}"
  fi
  ok "Base utilities present."
}

install_docker() {
  if have docker; then
    ok "Docker already installed ($(docker --version 2>/dev/null))."
  else
    log "Docker not found."
    confirm "Install Docker now via the official get.docker.com script?" Y \
      || die "Docker is required. Aborting."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh || die "Failed to download Docker installer."
    as_root sh /tmp/get-docker.sh || die "Docker installation failed."
    rm -f /tmp/get-docker.sh
    ok "Docker installed."
  fi

  # Ensure the daemon is enabled and running.
  if have systemctl; then
    as_root systemctl enable --now docker >/dev/null 2>&1 || warn "Could not enable/start the docker service."
  fi

  # Resolve a working compose command (v2 plugin preferred).
  if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
  elif have docker-compose; then
    COMPOSE="docker-compose"
  else
    warn "Docker Compose plugin missing; attempting to install it."
    pkg_install docker-compose-plugin || true
    if docker compose version >/dev/null 2>&1; then
      COMPOSE="docker compose"
    else
      die "Docker Compose is unavailable. Install the docker compose plugin and re-run."
    fi
  fi

  # Verify the current user can talk to the daemon; otherwise fall back to sudo
  # for this run and offer to fix group membership permanently.
  DOCKER="docker"
  if ! docker info >/dev/null 2>&1; then
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
      warn "User '$USER' cannot access the Docker daemon."
      if confirm "Add '$USER' to the 'docker' group (takes effect after re-login)?" Y; then
        as_root usermod -aG docker "$USER"
        warn "Log out/in (or run 'newgrp docker') later so you can use Docker without sudo."
      fi
      DOCKER="$SUDO docker"
      COMPOSE="$SUDO $COMPOSE"
    fi
  fi
  ok "Using compose command: $COMPOSE"
}
