#!/usr/bin/env bash
set -euo pipefail

REQUIRED_CMDS=(docker kubectl helm vagrant ansible-playbook VBoxManage)
OPTIONAL_CMDS=(istioctl minikube kind)

KUBECONFIG_PATH=${KUBECONFIG:-"$PWD/kubeconfig/config"}

missing=0

print_status() {
  local status="$1"
  local message="$2"
  echo "[$(date +%H:%M:%S)] ${status} ${message}"
}

cmd_version() {
  local cmd="$1"
  case "$cmd" in
    docker) docker --version ;;
    kubectl) kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null ;;
    helm) helm version --short 2>/dev/null || helm version 2>/dev/null ;;
    vagrant) vagrant --version ;;
    ansible-playbook) ansible-playbook --version | head -n1 ;;
    VBoxManage) VBoxManage -v ;;
    istioctl) istioctl version --remote=false 2>/dev/null || istioctl version | head -n1 ;;
    minikube) minikube version ;;
    kind) kind version ;;
    *) "$cmd" --version 2>/dev/null || echo "version unavailable"
  esac
}

check_command() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    print_status "✔" "$cmd ($(cmd_version "$cmd"))"
  else
    print_status "✖" "$cmd is missing"
    missing=1
  fi
}

print_status "…" "Checking required toolchain"
for cmd in "${REQUIRED_CMDS[@]}"; do
  check_command "$cmd"
done

if docker compose version >/dev/null 2>&1; then
  print_status "✔" "docker compose plugin available ($(docker compose version 2>/dev/null | head -n1))"
else
  print_status "✖" "docker compose plugin missing (install docker-compose-plugin)"
  missing=1
fi

print_status "…" "Checking optional tools"
for cmd in "${OPTIONAL_CMDS[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    print_status "•" "$cmd ($(cmd_version "$cmd"))"
  fi
done

if [[ -f "${KUBECONFIG_PATH}" ]]; then
  print_status "✔" "KUBECONFIG found at ${KUBECONFIG_PATH}"
else
  print_status "⚠" "KUBECONFIG not found at ${KUBECONFIG_PATH} (run cluster-finalize to export it)"
fi

if [[ ${missing} -eq 0 ]]; then
  print_status "✔" "All required dependencies detected."
else
  print_status "✖" "Missing dependencies detected. Run 'make setup' or install manually."
  exit 1
fi

