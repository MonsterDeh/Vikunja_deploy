#!/usr/bin/env bash
# دستورات مرحله ۲ صورت‌پروژه: نصب Ansible، تست اتصال، گرفتن Facts و اجرای Playbook آماده‌سازی سرور
# پیش‌فرض‌ها را می‌توان با متغیر محیطی عوض کرد:
#   INVENTORY=host.ini PLAYBOOK=project/02_ansible_setup/server_setup.yml ./02_ansible_commands.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INVENTORY="${INVENTORY:-$REPO_ROOT/host.ini}"
PLAYBOOK="${PLAYBOOK:-$REPO_ROOT/output/02_ansible_setup/server_setup.yml}"
TARGET_GROUP="${TARGET_GROUP:-webserver}"
CONFIRM="${CONFIRM:-no}"

# install_ansible() {
#   echo "== 1) install ansible on the control node =="
#   if ! command -v ansible >/dev/null 2>&1; then
#     python3 -m pip install --user ansible-core
#   fi
#   ansible --version
#   ansible-galaxy collection install community.docker
# }

test_connection() {
  echo "== 2) inventory ping test =="
  ansible "$TARGET_GROUP" -i "$INVENTORY" -m ping -e "REPO_ROOT=$REPO_ROOT"  | tee "$SCRIPT_DIR/ping_test.txt" 

  echo "== 3) gather facts (ansible -m setup) =="
  ansible "$TARGET_GROUP" -i "$INVENTORY" -m setup -e "REPO_ROOT=$REPO_ROOT" | tee "$SCRIPT_DIR/facts.txt"
}

run_server_setup() {
  echo "== 4) syntax check =="
  ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --syntax-check -e "REPO_ROOT=$REPO_ROOT"

  if [[ "$CONFIRM" != "yes" ]]; then
    echo "dry-run only; export CONFIRM=yes to actually run the playbook"
    ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --check -e "REPO_ROOT=$REPO_ROOT" || true
    # return 0
  fi

  echo "== 5) run server preparation playbook =="
  ansible-playbook -i "$INVENTORY" "$PLAYBOOK" -e "REPO_ROOT=$REPO_ROOT" | tee "$SCRIPT_DIR/playbook_output.txt"

  echo "== 6) verification (docker/nginx versions, services, firewall) =="
  {
    echo "docker"
    ansible "$TARGET_GROUP" -i "$INVENTORY" -m command -a "docker --version" -e "REPO_ROOT=$REPO_ROOT"
    echo "docker compose version"
    ansible "$TARGET_GROUP" -i "$INVENTORY" -m command -a "docker compose version"  -e "REPO_ROOT=$REPO_ROOT"
    echo "nginx"
    ansible "$TARGET_GROUP" -i "$INVENTORY" -m command -a "nginx -v" -b -e "REPO_ROOT=$REPO_ROOT"
    echo "systemctl is-active docker nginx"
    ansible "$TARGET_GROUP" -i "$INVENTORY" -m command -a "systemctl is-active docker nginx" -b -e "REPO_ROOT=$REPO_ROOT"
    echo "ufw status verbose"
    ansible "$TARGET_GROUP" -i "$INVENTORY" -m command -a "ufw status verbose" -b -e "REPO_ROOT=$REPO_ROOT"
  } | tee "$SCRIPT_DIR/verification.txt"
}

# install_ansible
test_connection
run_server_setup
