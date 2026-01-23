#!/usr/bin/env bash
set -euo pipefail

REQUIRED_CMDS=(docker kubectl helm vagrant ansible-playbook VBoxManage)
DOCKER_GROUP=${DOCKER_GROUP:-docker}

OS="$(uname -s)"
PKG_MANAGER=""

if [[ "$OS" == "Darwin" ]]; then
  PKG_MANAGER="brew"
  if ! command -v brew >/dev/null 2>&1; then
    cat <<'EOF'
[setup] Homebrew is required on macOS.
        Install from https://brew.sh and re-run `make setup`.
EOF
    exit 1
  fi
elif command -v apt-get >/dev/null 2>&1; then
  PKG_MANAGER="apt"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MANAGER="dnf"
else
  cat <<'EOF'
[setup] Unsupported host OS/package manager.
        Please install docker, kubectl, helm, vagrant, ansible, and VirtualBox manually.
EOF
  exit 1
fi

if [[ "$PKG_MANAGER" != "brew" ]] && ! command -v sudo >/dev/null 2>&1; then
  echo "[setup] sudo is required for package installation." >&2
  exit 1
fi

print_header() {
  echo "==> $1"
}

declare -A PKG_MAP
case "$PKG_MANAGER" in
  apt)
    PKG_MAP=(
      [docker]="docker.io"
      [kubectl]="kubectl"
      [helm]="helm"
      [vagrant]="vagrant"
      [ansible-playbook]="ansible"
      [VBoxManage]="virtualbox"
    )
    ;;
  dnf)
    PKG_MAP=(
      [docker]="docker"
      [kubectl]="kubernetes-client"
      [helm]="helm"
      [vagrant]="vagrant"
      [ansible-playbook]="ansible"
      [VBoxManage]="VirtualBox"
    )
    ;;
  brew)
    PKG_MAP=(
      [docker]="cask:docker"
      [kubectl]="formula:kubectl"
      [helm]="formula:helm"
      [vagrant]="cask:vagrant"
      [ansible-playbook]="formula:ansible"
      [VBoxManage]="cask:virtualbox"
    )
    ;;
esac

APT_UPDATED=0
update_apt() {
  if [[ $APT_UPDATED -eq 0 ]]; then
    print_header "Updating apt package index"
    sudo apt-get update
    APT_UPDATED=1
  fi
}

DNF_UPDATED=0
update_dnf() {
  if [[ $DNF_UPDATED -eq 0 ]]; then
    print_header "Refreshing dnf metadata"
    sudo dnf makecache
    DNF_UPDATED=1
  fi
}

apt_install() {
  local pkg="$1"
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    return
  fi
  update_apt
  print_header "Installing package: ${pkg}"
  sudo apt-get install -y "$pkg"
}

dnf_install() {
  local pkg="$1"
  if rpm -q "$pkg" >/dev/null 2>&1; then
    return
  fi
  update_dnf
  print_header "Installing package: ${pkg}"
  sudo dnf install -y "$pkg"
}

brew_is_installed() {
  local type="${1%%:*}"
  local pkg="${1##*:}"
  if [[ "$type" == "cask" ]]; then
    brew list --cask "$pkg" >/dev/null 2>&1
  else
    brew list "$pkg" >/dev/null 2>&1
  fi
}

brew_install() {
  local type="${1%%:*}"
  local pkg="${1##*:}"
  if brew_is_installed "$type:$pkg"; then
    return
  fi
  print_header "Installing ${pkg} via brew (${type})"
  if [[ "$type" == "cask" ]]; then
    brew install --cask "$pkg"
  else
    brew install "$pkg"
  fi
}

install_tool() {
  local tool="$1"
  local spec="${PKG_MAP[$tool]:-}"

  if [[ -z "$spec" ]]; then
    echo "[setup] [WARN] No installer mapping for ${tool} on ${PKG_MANAGER}. Install manually."
    return
  fi

  case "$PKG_MANAGER" in
    apt) apt_install "$spec" ;;
    dnf) dnf_install "$spec" ;;
    brew) brew_install "$spec" ;;
  esac
}

for cmd in "${REQUIRED_CMDS[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[setup] [OK] ${cmd} already installed ($(command -v "$cmd"))"
    continue
  fi
  install_tool "$cmd"
done

if ! docker compose version >/dev/null 2>&1; then
  case "$PKG_MANAGER" in
    apt) apt_install docker-compose-plugin ;;
    dnf) dnf_install docker-compose-plugin ;;
    brew)
      cat <<'EOF'
[setup] [WARN] docker compose plugin not detected. If on macOS, launch Docker Desktop
        once so it can finish installing the CLI plugin (or install manually).
EOF
      ;;
  esac
else
  echo "[setup] [OK] docker compose plugin detected"
fi

if [[ "$PKG_MANAGER" == "dnf" ]]; then
  if ! systemctl is-active --quiet docker; then
    print_header "Enabling docker service"
    sudo systemctl enable --now docker || true
  fi
fi

if [[ "$PKG_MANAGER" != "brew" ]] && getent group "${DOCKER_GROUP}" >/dev/null 2>&1; then
  if id -nG "${USER}" | tr ' ' '\n' | grep -qx "${DOCKER_GROUP}"; then
    echo "[setup] [OK] user ${USER} is in the ${DOCKER_GROUP} group"
  else
    cat <<EOF
[setup] [WARN] ${USER} is not part of the '${DOCKER_GROUP}' group.
       Run: sudo usermod -aG ${DOCKER_GROUP} ${USER} && newgrp ${DOCKER_GROUP}
EOF
  fi
fi

if [[ "$PKG_MANAGER" == "brew" ]]; then
  cat <<'EOF'
[setup] Note: After installing Docker Desktop and VirtualBox via Homebrew,
        open each application once to finish macOS security approval.
EOF
fi

echo "[setup] Completed. Re-run 'make check' to verify versions."
