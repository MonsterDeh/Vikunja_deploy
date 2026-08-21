#!/usr/bin/env bash
# جمع‌آوری اطلاعات سیستم سرور (مرحله ۱٫۲ صورت‌پروژه)
# خروجی در همین پوشه به نام server_connection.txt ذخیره می‌شود.
# اجرا:  SERVER=ubuntu@192.168.1.5 ./01_collect_server_info.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER="${SERVER:-ubuntu@192.168.1.5}"
OUT_FILE="${SCRIPT_DIR}/server_connection.txt"

collect() {
  echo "===== Kernel version (uname -a) ====="
  uname -a
  echo
  echo "===== OS version (lsb_release -a) ====="
  lsb_release -a 2>/dev/null || cat /etc/os-release
  echo
  echo "===== Disk usage (df -h) ====="
  df -h
  echo
  echo "===== Memory usage (free -h) ====="
  free -h
  echo
  echo "===== Network interfaces (ip addr) ====="
  ip -brief addr || ip addr
}

if [[ "${LOCAL:-no}" == "yes" ]]; then
  # اجرای محلی روی خود سرور
  collect | tee "$OUT_FILE"
else
  # اجرای از راه دور با SSH
  ssh "$SERVER" "$(declare -f collect); collect" | tee "$OUT_FILE"
fi

echo "saved to: $OUT_FILE"
